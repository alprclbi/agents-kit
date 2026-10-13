#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# DOGRULAYICININ URETTIGI HER POLITIKA KODU KATALOGDA OLMALI.
#
# 2026-10-13: AKW102 ve AKW103 iki dogrulayicida da uretiliyordu ama
# policy-codes.json'da yoktu. Kullanici koda bakip anlamini bulamazdi.
# Katalog elle tutulur; bu kontrol uretilen kod kumesini kaynaktan
# cikarip katalogla karsilastirir.
catalog=.agents/validators/policy-codes.json
[ -f "$catalog" ] || { printf 'FAIL katalog yok: %s\n' "$catalog" >&2; exit 1; }
jq -e 'type == "object"' "$catalog" >/dev/null || { printf 'FAIL katalog JSON nesnesi degil\n' >&2; exit 1; }

emitted=$(grep -hoE 'AK[EWS][0-9]{3}' \
  .agents/validators/sh/*.sh .agents/validators/ps/*.ps1 .agents/validators/ps/*.psm1 \
  | LC_ALL=C sort -u)
[ -n "$emitted" ] || { printf 'FAIL dogrulayicida hic kod bulunamadi\n' >&2; exit 1; }

fail=0
for code in $emitted; do
  jq -e --arg c "$code" 'has($c) and (.[$c] | type == "string" and length > 0)' "$catalog" >/dev/null \
    || { printf 'FAIL %s dogrulayicida uretiliyor ama %s icinde yok\n' "$code" "$catalog" >&2; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1
printf 'PASS policy-codes katalogu\n'
