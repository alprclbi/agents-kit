#!/bin/sh
set -eu

# Gorev/sonda kosularindan uyum tablosu, karar kurali ve sinir beyani uretir.
#
# Kullanim: report-tasks.sh <runs.jsonl> [<runs.jsonl> ...]

[ $# -gt 0 ] || { printf 'E_RT_ARGS report-tasks.sh <runs.jsonl>...\n' >&2; exit 2; }
for f in "$@"; do
  [ -f "$f" ] || { printf 'E_RT_NO_FILE %s\n' "$f" >&2; exit 2; }
done

# spec D7: esik VERI GORULMEDEN sabitlendi. Bu satiri sonuclara bakarak
# degistirmek, istenen cevabi uretecek esigi secmek demektir.
THRESHOLD=3

tmp=$(mktemp -d "${TMPDIR:-/tmp}/akrep.XXXXXX")
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

jq -r '[ (.task // "-"), (.arm // "-"), (.oracle // "-"),
         (.num_turns // 0), (.total_cost_usd // 0),
         (.response_chars // 0), (.response_turkish_chars // 0) ] | @tsv' "$@" > "$tmp/rows"

[ -s "$tmp/rows" ] || { printf 'E_RT_EMPTY veri yok\n' >&2; exit 2; }

# ------------------------------------------------------------------ 1. tablo
printf 'UYUM: SONDA x KOL\n\n'
printf '%-18s %-4s %8s %10s %9s %10s\n' SONDA KOL GECTI GECERSIZ 'TUR ORT' 'USD ORT'
printf -- '-----------------------------------------------------------------\n'

# invalid/skipped orana GIRMEZ: yarim kalan kosuyu basarisizlik saymak
# olcumu kirletir. Ayri sutunda gorunur kalirlar.
awk -F '\t' '
  { key=$1 FS $2
    if ($3=="pass" || $3=="fail") { n[key]++; if ($3=="pass") p[key]++ ; t[key]+=$4; u[key]+=$5 }
    else { bad[key]++ }
    seen[key]=1 }
  END { for (k in seen) {
          split(k,a,FS); nn=n[k]+0
          printf "%-18s %-4s %8s %10d %9s %10s\n", a[1], a[2],
            sprintf("%d/%d", p[k]+0, nn), bad[k]+0,
            (nn ? sprintf("%.1f", t[k]/nn) : "-"),
            (nn ? sprintf("%.4f", u[k]/nn) : "-") }
      }' "$tmp/rows" | sort

# ------------------------------------------------------- 2. karar kurali
cmp_arms() {
  base=$1; test=$2; label=$3
  have=$(awk -F '\t' -v b="$base" -v t="$test" '$2==b||$2==t{n++} END{print n+0}' "$tmp/rows")
  [ "$have" -gt 0 ] || return 0

  printf '\nKARAR KURALI: %s (spec D7, esik >= %s, veri gorulmeden sabitlendi)\n\n' "$label" "$THRESHOLD"
  printf '%-18s %8s %8s %7s  %s\n' SONDA "$base" "$test" FARK SONUC
  printf -- '-----------------------------------------------------------------\n'
  awk -F '\t' -v b="$base" -v t="$test" -v th="$THRESHOLD" '
    ($3=="pass" || $3=="fail") && ($2==b || $2==t) {
      n[$1 FS $2]++; if ($3=="pass") p[$1 FS $2]++
      tasks[$1]=1 }
    END {
      for (k in tasks) {
        pb=p[k FS b]+0; nb=n[k FS b]+0
        pt=p[k FS t]+0; nt=n[k FS t]+0
        if (nb==0 || nt==0) { printf "%-18s %8s %8s %7s  eksik kol, karsilastirilmadi\n", k, sprintf("%d/%d",pb,nb), sprintf("%d/%d",pt,nt), "-"; continue }
        d=pt-pb; ad=(d<0?-d:d)
        if (ad >= th) verdict = (d>0 ? "AYIRT EDIYOR (" t " lehine)" : "AYIRT EDIYOR -- TERS YON, " b " daha iyi")
        else verdict = "ayirt etmiyor"
        printf "%-18s %8s %8s %+7d  %s\n", k, sprintf("%d/%d",pb,nb), sprintf("%d/%d",pt,nt), d, verdict
      }
    }' "$tmp/rows" | sort
}

cmp_arms A0 A1 'kurallar ise yariyor mu'
cmp_arms A1 E1 'dil farki (TR taban, EN test)'

# --------------------------------------------------------- 3. yanit dili
if awk -F '\t' '$6>0{f=1} END{exit !f}' "$tmp/rows"; then
  printf '\nYANIT DILI (turkce karakter orani; metin SAKLANMAZ, yalniz sayilir)\n\n'
  printf '%-4s %10s %12s %8s\n' KOL 'KARAKTER' 'TR KARAKTER' 'ORAN'
  printf -- '----------------------------------------\n'
  awk -F '\t' '
    $6>0 { c[$2]+=$6; k[$2]+=$7; n[$2]++ }
    END { for (a in c) printf "%-4s %10d %12d %7.3f%%\n", a, c[a]/n[a], k[a]/n[a], 100*k[a]/c[a] }
  ' "$tmp/rows" | sort
fi

# ---------------------------------------------------------- 4. sinir beyani
# Bu blok KOSULSUZDUR. Rapor her calistiginda basilir; guc beyani olmadan
# tablo yanlis okunur.
runs=$(awk 'END{print NR}' "$tmp/rows")
rep=$(awk -F '\t' '($3=="pass"||$3=="fail"){n[$1 FS $2]++} END{m=0; for(k in n) if(n[k]>m) m=n[k]; print m+0}' "$tmp/rows")

printf '\nSINIR BEYANI\n'
printf -- '- Kol basina en fazla %s tekrar, toplam %s kosu. Bu boyutta yalniz\n' "$rep" "$runs"
printf '  BUYUK etkiler ayirt edilir: 0/5 ile 5/5 sinyaldir, 2/5 ile 4/5\n'
printf '  GURULTUDUR ve bulgu olarak sunulmaz.\n'
printf -- '- Esik (fark >= %s) veriye bakilmadan spec D7-de sabitlendi.\n' "$THRESHOLD"
printf -- '- Ters yon gizlenmez: kuralsiz kol daha iyi cikarsa ayni esikle ve\n'
printf '  ayni gorunurlukte raporlanir.\n'
printf -- '- Tavan etkisi: gecme orani her kolda yuksekse sonda ayirt edici\n'
printf '  degildir ve tablo kurallar hakkinda bir sey soylemez.\n'
printf -- '- A0 temiz taban degildir: sandbox CLAUDE.md ve .agents/skills/\n'
printf '  tasimaya devam eder. Rakamlar AGENTS.md farkidir, kitin bedeli degil.\n'
printf -- '- Istemler kitin kurallarini tetiklemek icin yazildi; sonuclar gercek\n'
printf '  projelere dogrudan genellenmez.\n'
printf -- '- 12-fabrication oracle-i dile duyarlidir ve setin en kirilganidir;\n'
printf '  P1 ve P2 ile esit agirlikta yorumlanmaz.\n'
printf -- '- E1 yalniz dilde degil METINDE de farklidir; ceviri karistiricisi\n'
printf '  yapisal parite ile sinirlanir ama ortadan kaldirilamaz.\n'
