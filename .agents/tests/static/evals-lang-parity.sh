#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
en=.agents/evals/variants/AGENTS.en.md
[ -f "$en" ] || { printf 'E_LP_MISSING %s\n' "$en" >&2; exit 2; }

# DRIFT KORUMASI.
#
# `E1` kolu, harness'in "ikinci kopya tutma, canli dosyadan uret" ilkesini
# BILEREK deler (spec D4). Bedeli bu testtir: TR'ye kural eklenip EN'e
# eklenmezse test kirilir ve dil kolu sessizce gecersiz olmaz.
#
# Ayni desen reinjection.sh'de kullanildi ve 5. maddede gercek bir sessiz
# tutarsizligi yakaladi.

# 1. Kural sayisi paritesi.
count_rules() { awk '/^- /{n++} /^[0-9]+\. /{n++} END{print n+0}' "$1"; }
tr_n=$(count_rules AGENTS.md)
en_n=$(count_rules "$en")
[ "$tr_n" = "$en_n" ] \
  || { printf 'E_LP_RULECOUNT tr=%s en=%s\n' "$tr_n" "$en_n" >&2; exit 2; }

# 2. Blok isaretcileri ayni ad ve ayni SIRADA olmali; build-variant.sh
#    kollari bunlara gore uretiyor, ayrisirsa yanlis varyant cikar.
mkdir -p .agents/runtime
t=$(mktemp -d .agents/runtime/lp.XXXXXX)
trap 'rm -rf "$t"' EXIT HUP INT TERM
grep -o 'ak:block [a-z]*=[a-z-]*' AGENTS.md > "$t/tr" || true
grep -o 'ak:block [a-z]*=[a-z-]*' "$en"  > "$t/en" || true
if ! diff "$t/tr" "$t/en" >/dev/null 2>&1; then
  printf 'E_LP_MARKERS isaretciler ayristi\n' >&2
  diff "$t/tr" "$t/en" >&2 || true
  exit 2
fi

# 3. EN dosyasi saf ASCII olmali. Turkce karakter kaldiysa ceviri eksiktir.
iconv -f ASCII -t ASCII "$en" >/dev/null 2>&1 \
  || { printf 'E_LP_NOT_ASCII ceviri eksik, ASCII disi karakter var\n' >&2; exit 2; }

# 4. HICBIR talimat zincirinden import edilmemeli: runtime maliyeti sifir
#    olmali, yalniz harness okumali.
for f in CLAUDE.md AGENTS.md .agents/project.md; do
  [ -f "$f" ] || continue
  ! grep -Fq 'AGENTS.en.md' "$f" \
    || { printf 'E_LP_IMPORTED %s\n' "$f" >&2; exit 2; }
done

# 5. Bolum basligi sayisi da esit olmali; kural sayisi tutup bolum kaybolmus
#    olabilir.
tr_h=$(grep -c '^## ' AGENTS.md || true)
en_h=$(grep -c '^## ' "$en" || true)
[ "$tr_h" = "$en_h" ] \
  || { printf 'E_LP_HEADINGS tr=%s en=%s\n' "$tr_h" "$en_h" >&2; exit 2; }

printf 'PASS evals-lang-parity kural=%s bolum=%s\n' "$tr_n" "$tr_h"
