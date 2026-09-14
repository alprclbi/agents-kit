#!/bin/sh
set -eu

# Sonda sonuclarindan talimat yuku tablosu uretir.
#
# Birincil olcu cache_creation_tokens: talimatlarin bir kerelik yukleme
# bedeli. A0 (AGENTS.md yok) taban alinir; her kolun A1'e gore farki o
# blogun oturum basi maliyetidir.

root=${1:-"$(pwd)"}
f="$root/.agents/evals/results/probe.jsonl"
[ -f "$f" ] || { printf 'E_RP_NO_DATA %s\n' "$f" >&2; exit 2; }

tok_of() { jq -r --arg a "$1" 'select(.arm==$a) | .cache_creation_tokens' "$f" | head -1; }
byt_of() { jq -r --arg a "$1" 'select(.arm==$a) | .agents_md_bytes' "$f" | head -1; }

base=$(tok_of A0)
full=$(tok_of A1)
fullb=$(byt_of A1)
[ -n "$base" ] && [ -n "$full" ] || { printf 'E_RP_NEED_A0_A1\n' >&2; exit 2; }

printf 'TALIMAT YUKU (olculen, cache_creation_tokens)\n\n'
printf '%-4s %-24s %8s %10s %8s %9s\n' KOL ICERIK TOKEN 'A0 FARKI' BAYT 'BAYT/TOK'
printf -- '-----------------------------------------------------------------------\n'

for arm in A0 A1 A2 A3 A4 A5 A6; do
  tok=$(tok_of "$arm")
  [ -n "$tok" ] || continue
  bytes=$(byt_of "$arm")
  case $arm in
    A0) desc='AGENTS.md yok (taban)' ;;
    A1) desc='tam' ;;
    A2) desc='bootstrap yok (1)' ;;
    A3) desc='engineering yok (4-5)' ;;
    A4) desc='safety yok (6-7)' ;;
    A5) desc='discipline yok (2-3)' ;;
    A6) desc='meta yok (8-10)' ;;
    *)  desc='-' ;;
  esac
  ratio='-'
  [ "$tok" -gt "$base" ] && ratio=$(awk -v b="$bytes" -v t="$tok" -v z="$base" 'BEGIN{printf "%.2f", b/(t-z)}')
  printf '%-4s %-24s %8s %10s %8s %9s\n' "$arm" "$desc" "$tok" "$((tok - base))" "$bytes" "$ratio"
done

printf '\nBLOK BASINA OTURUM MALIYETI (A1 eksi ilgili kol)\n\n'
printf '%-22s %8s %8s\n' BLOK TOKEN BAYT
printf -- '----------------------------------------\n'

sum=0
sumb=0
for pair in 'bootstrap (1):A2' 'discipline (2-3):A5' 'engineering (4-5):A3' 'safety (6-7):A4' 'meta (8-10):A6'; do
  name=${pair%%:*}
  arm=${pair#*:}
  tok=$(tok_of "$arm")
  [ -n "$tok" ] || continue
  byt=$(byt_of "$arm")
  dt=$((full - tok))
  db=$((fullb - byt))
  sum=$((sum + dt))
  sumb=$((sumb + db))
  printf '%-22s %8s %8s\n' "$name" "$dt" "$db"
done

printf -- '----------------------------------------\n'
printf '%-22s %8s %8s\n' 'BLOK TOPLAMI' "$sum" "$sumb"
printf '%-22s %8s %8s\n' 'TAM DOSYA (A1-A0)' "$((full - base))" "$fullb"
printf '%-22s %8s %8s\n' 'artik (baslik/bosluk)' "$((full - base - sum))" "$((fullb - sumb))"

printf '\nSINIR BEYANI\n'
printf -- '- Kol basina 1 olcum. cache_creation ayni girdi icin kararli oldugundan\n'
printf '  bu metrik tek olcumle guvenilir; iki bagimsiz parti binde bir altinda\n'
printf '  sapmayla ayni sonucu verdi.\n'
printf -- '- Bu tablo yalniz MALIYET tarafidir. Kurallarin FAYDA tarafi\n'
printf '  olculmemistir; bunun icin tam gorev kosulari ve cok tekrar gerekir.\n'
printf -- '- A0 tam bir "kuralsiz" taban degildir: sandbox CLAUDE.md ve\n'
printf '  .agents/skills/ tasimaya devam eder. Rakamlar AGENTS.md farkidir,\n'
printf '  kitin toplam bedeli degil.\n'
