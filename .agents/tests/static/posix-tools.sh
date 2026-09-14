#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# TEST BETIKLERI YALNIZ POSIX ARACLARINA DAYANMALI.
#
# 2026-09-08: dort statik test `rg` (ripgrep) kullaniyordu. `rg` kurulu
# olmayan makinede komut 127 ile dusuyor, `if rg ...; then hata; fi`
# kalibinda kosul YANLIS oluyor ve kontrol TEMIZ GORUNUYORDU.
#
# Hepsi olumsuz kontroldu ("bu kotu kalip varsa hata ver"), yani arac
# eksikken her zaman "sorun yok" diyorlardi -- en tehlikeli yanlis.
# Sessiz gecen bir test, olmayan bir testten daha kotudur: guven veriyor.

# POSIX disi, dagitimlarda garanti olmayan araclar.
banned='rg fd ag ack jq5 bat exa'

fail=0
for tool in $banned; do
  hits=$(grep -rEn "(^|[^[:alnum:]_.-])$tool[[:space:]]" \
           .agents/tests/static .agents/tests/lib .agents/tests/run.sh 2>/dev/null \
         | grep -v 'posix-tools.sh' \
         | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
  if [ -n "$hits" ]; then
    printf 'E_POSIX_TOOL %s kullaniliyor:\n%s\n' "$tool" "$hits" >&2
    fail=1
  fi
done
[ "$fail" = 0 ] || exit 2

# Kosullu calistirilan her arac, eksikken SESSIZ GECMEMELI. `command -v`
# ile korunmayan `if <arac> ...` kalibi bu hatayi geri getirir.
# jq ve python kitin her yerinde zorunlu; onlar muaf.

# BASH SOZDIZIMI POSIX DEGILDIR.
#
# 2026-09-14: manifest-scope.sh process substitution `<(...)` kullaniyordu.
# Git Bash altinda `sh` aslinda bash oldugu icin yerelde GECTI; Ubuntu CI
# `sh` = dash ve orada "Syntax error" ile dustu. Yerelde yesil, CI kirmizi
# en pahali geri bildirim dongusudur.
sozdizimi=$(grep -rn -e '<(' -e '>(' .agents/tests/static .agents/tests/lib .agents/tests/run.sh .agents/validators/sh 2>/dev/null | grep -v 'posix-tools.sh' | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
if [ -n "$sozdizimi" ]; then
  printf 'E_POSIX_SYNTAX process substitution POSIX degil:\n%s\n' "$sozdizimi" >&2
  exit 2
fi

printf 'PASS posix-tools yasakli arac yok\n'
