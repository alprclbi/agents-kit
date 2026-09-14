#!/bin/sh
set -eu

root='' arm='' out=''
while [ $# -gt 0 ]; do
  case $1 in
    --root) root=$2; shift 2 ;;
    --arm)  arm=$2;  shift 2 ;;
    --out)  out=$2;  shift 2 ;;
    *) printf 'E_BV_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$root" ] && [ -n "$arm" ] && [ -n "$out" ] || { printf 'E_BV_ARGS\n' >&2; exit 2; }

# Kol -> (dusurulecek blok, kaynak dosya) eslemesi. Tek dogruluk kaynagi.
# E1 dil koludur: ayni kurallar, Ingilizce. Yalniz kaynak dosya degisir;
# blok soyma mantigi aynen calisir cunku isaretciler iki dosyada da
# ozdestir. Bunu evals-lang-parity.sh denetler.
src="$root/AGENTS.md"
case "$arm" in
  A0) drop='__REMOVE_FILE__' ;;
  A1) drop='' ;;
  A2) drop='bootstrap' ;;
  A3) drop='engineering' ;;
  A4) drop='safety' ;;
  A5) drop='discipline' ;;
  A6) drop='meta' ;;
  E1) drop=''; src="$root/.agents/evals/variants/AGENTS.en.md" ;;
  *)  printf 'E_BV_UNKNOWN_ARM %s\n' "$arm" >&2; exit 2 ;;
esac
[ -f "$src" ] || { printf 'E_BV_NO_SOURCE %s\n' "$src" >&2; exit 2; }

mkdir -p "$out"

# CLAUDE.md her kolda kopyalanir; A0'da import satiri cikarilir.
if [ -f "$root/CLAUDE.md" ]; then
  if [ "$drop" = '__REMOVE_FILE__' ]; then
    grep -v '^@AGENTS\.md[[:space:]]*$' "$root/CLAUDE.md" > "$out/CLAUDE.md"
  else
    cp "$root/CLAUDE.md" "$out/CLAUDE.md"
  fi
fi

[ "$drop" = '__REMOVE_FILE__' ] && exit 0

# Isaretci dengesi dogrulanir; bozuksa sessizce yanlis varyant uretmek yerine hata verilir.
awk '
  /^<!-- ak:block start=/ { if (open) exit 2; open=1; next }
  /^<!-- ak:block end=/   { if (!open) exit 2; open=0; next }
  END { if (open) exit 2 }
' "$src" || { printf 'E_BV_UNBALANCED\n' >&2; exit 2; }

# Adlandirilmis blogu dusur, tum isaretci satirlarini kaldir.
awk -v drop="$drop" '
  /^<!-- ak:block start=/ {
    name=$0; sub(/.*start=/,"",name); sub(/[[:space:]]*-->.*/,"",name)
    if (drop != "" && name == drop) skip=1
    next
  }
  /^<!-- ak:block end=/ {
    name=$0; sub(/.*end=/,"",name); sub(/[[:space:]]*-->.*/,"",name)
    if (drop != "" && name == drop) skip=0
    next
  }
  !skip { print }
' "$src" > "$out/AGENTS.md"

exit 0
