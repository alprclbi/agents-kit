#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# DOGRULAYICILARDA ERKEN KAPANAN BORU OLMAYACAK.
#
# 2026-09-11: ubuntu CI log'unda her kosuda su satir vardi:
#   agent-kit.sh: 90: printf: printf: I/O error
#
# Sebep: lib.sh icinde
#   printf '%s\n' "$right_values" | grep -Fqx "$left"
# grep -q ILK ESLESMEDE cikar ve boruyu kapatir. Sol taraftaki printf
# hala yaziyorsa EPIPE alir. bash sessiz gecer, Ubuntu'nun /bin/sh'i
# olan dash "I/O error" basar. Yani hata yalniz bazi platformlarda
# GORUNUR, her yerde VARDIR.
#
# Ayni kalipta alti yer daha bulundu; hicbiri patlamiyordu cunku yazan
# taraf tuketici cikmadan bitiriyordu. Girdi buyudugunde konusurlar.
# Bu bir yaris durumudur, tesadufe birakilmaz.
#
# Cozum: tuketici girdiyi SONUNA KADAR okusun.
#   grep -q X   -> grep X >/dev/null
#   awk '... exit' -> awk '... && !seen { ...; seen=1 }'
#
# Kapsam yalniz .agents/validators: kullanicinin her oturumunda calisan
# kod orasi. Testlerde ayni kalip var ama bedeli tek bir log satiri ve
# cikti test kosucusu tarafindan yutuluyor.

scan=.agents/validators
[ -d "$scan" ] || { printf 'E_PS_NO_VALIDATORS\n' >&2; exit 2; }

hits=$(grep -rnE "\| *(grep -[A-Za-z]*q|awk [^|]*exit *\}|head( |$))" "$scan" 2>/dev/null \
       | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)

if [ -n "$hits" ]; then
  printf 'E_PIPE_EARLY_CLOSE erken kapanan tuketiciye yazan boru:\n%s\n' "$hits" >&2
  printf 'Duzelt: grep -q yerine grep >/dev/null; awk exit yerine bayrak.\n' >&2
  exit 2
fi

printf 'PASS pipe-safety %s altinda erken kapanan boru yok\n' "$scan"
