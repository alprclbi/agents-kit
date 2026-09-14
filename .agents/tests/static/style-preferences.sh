#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
v=.agents/validators/sh/agent-kit.sh

# ILETISIM TERCIHI ENJEKSIYONU.
#
# Uslup kurali her yanita uygulanir, o yuzden sert sinirlardan farkli
# olarak YALNIZ compact'ta degil HER oturum baslangicinda bildirilir.
#
# Metin validator'a gomulmez, kullanicinin .agents/local/preferences.md
# dosyasindan okunur. Gomulu olsa update kullanicinin tercihini
# ezerdi. Bu test o sozlesmeyi kilitler.
#
# 2026-09-10: test kullanicinin GERCEK tercih dosyasina bagimliydi.
# O dosya git disinda oldugu icin temiz klonda ve CI'da test dusuyordu.
# Ayrica dosyayi gecici olarak EZIP geri yaziyordu; kosu yarida kesilse
# kullanicinin tercihleri kaybolurdu. Artik her sey sandbox'ta.

mkdir -p .agents/runtime
sandbox_yes=$(mktemp -d .agents/runtime/sp-yes.XXXXXX)
sandbox_no=$(mktemp -d .agents/runtime/sp-no.XXXXXX)
cleanup_sp() { rm -rf "$sandbox_yes" "$sandbox_no"; }
trap cleanup_sp EXIT HUP INT TERM

make_root() {
  mkdir -p "$1/.agents/changes/active"
  cp .agents/config.json "$1/.agents/config.json"
}
make_root "$sandbox_yes"
make_root "$sandbox_no"

mkdir -p "$sandbox_yes/.agents/local"
printf '# gecici\n<!-- ak:style start -->\n- AKSTYLEPROBE\n<!-- ak:style end -->\n' \
  > "$sandbox_yes/.agents/local/preferences.md"

# 1. Dosya varken blok HER kaynakta basilmali ve icerik DOSYADAN gelmeli.
#    Varlik testi tek basina yetmez: probe metni ciktida gorulmeli.
for src in startup resume clear compact; do
  out=$(sh "$v" session-context --root "$sandbox_yes" --client claude --source "$src" --format text)
  printf '%s' "$out" | grep -Fq 'Iletisim tercihi' \
    || { printf 'E_SP_MISSING kaynak=%s\n' "$src" >&2; exit 2; }
  printf '%s' "$out" | grep -Fq 'AKSTYLEPROBE' \
    || { printf 'E_SP_NOT_READ kaynak=%s blok dosyadan okunmuyor\n' "$src" >&2; exit 2; }
done

# 2. Metin GOMULU OLMAMALI: validator kullanicinin cumlelerini icermemeli.
grep -Fq '150 kelimeden' "$v" \
  && { printf 'E_SP_HARDCODED uslup metni validator icine gomulmus\n' >&2; exit 2; }

# 3. Dosya yokken sessiz kalmali; kit tercih dosyasi olmadan da calisir.
out=$(sh "$v" session-context --root "$sandbox_no" --client claude --source startup --format text)
printf '%s' "$out" | grep -Fq 'Iletisim tercihi' \
  && { printf 'E_SP_PHANTOM tercih dosyasi yokken blok basildi\n' >&2; exit 2; }

# 4. Tercih dosyasi git ve ZIP disinda kalmali; kisisel icerik dagitilmaz.
grep -Fq '.agents/local' .gitignore 2>/dev/null \
  || grep -q 'local' .agents/.gitignore 2>/dev/null \
  || { printf 'E_SP_NOT_IGNORED .agents/local git disinda degil\n' >&2; exit 2; }

cleanup_sp
trap - EXIT HUP INT TERM
printf 'PASS style-preferences 4 kaynak, dosyadan okunuyor, sandbox\n'
