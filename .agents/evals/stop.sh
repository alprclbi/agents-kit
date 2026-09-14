#!/bin/sh
set -eu

# Calisan eval kosusunu GUVENILIR sekilde durdurur ve durdugunu DOGRULAR.
#
# Gerekce (2026-09-08): istemcinin arka plan gorevini durdurma komutu
# sarmalayici kabugu olduruyor ama run.sh zincirini oldurmuyordu. Iki
# kosu farkinda olmadan saatlerce devam etti, butceyi asti ve veriyi
# birbirine karistirdi. "Durdurdum" demek yetmez; durdugu gorulmeli.

root=${1:-"$(pwd)"}
res="$root/.agents/evals/results"

# 1. Bayragi birak: run.sh her kosudan once bakiyor, temiz durur.
mkdir -p "$res"
: > "$res/STOP"
printf 'STOP bayragi birakildi.\n'

# 2. Devam eden ajan cagrisi varsa bitmesini bekle (en fazla 90 sn).
i=0
while [ "$i" -lt 90 ]; do
  if [ ! -d "$res/.lock" ]; then
    printf 'Kosu temiz sekilde durdu.\n'
    rm -f "$res/STOP"
    exit 0
  fi
  sleep 3
  i=$((i + 3))
done

# 3. Temiz durmadiysa zinciri sert kes.
printf 'Temiz durmadi, surecler oldurulyor...\n' >&2
pids=$(ps -ef 2>/dev/null | grep -E 'evals/(run|lib/run-task|clients/claude)\.sh|claude .*--max-turns' | grep -v grep | awk '{print $2}' || true)
for p in $pids; do kill -9 "$p" 2>/dev/null || true; done
rm -rf "$res/.lock"
rm -f "$res/STOP"

# 4. DOGRULA. Bu adim olmadan "durdurdum" demek anlamsizdir.
left=$(ps -ef 2>/dev/null | grep -E 'evals/(run|lib/run-task|clients/claude)\.sh|claude .*--max-turns' | grep -v grep | wc -l | tr -d ' ')
if [ "$left" = 0 ]; then
  printf 'Dogrulandi: calisan eval sureci yok.\n'
else
  printf 'UYARI: %s surec hala ayakta. Elle kontrol et.\n' "$left" >&2
  exit 1
fi
