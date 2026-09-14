#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
r=.agents/evals/results

# DURDURULABILIRLIK.
#
# 2026-09-08: istemcinin arka plan gorevini durdurma komutu sarmalayici
# kabugu olduruyor ama run.sh zincirini oldurmuyordu. Iki kosu fark
# edilmeden devam etti, butceyi 2,63 USD asti ve iki partinin verisini
# ayni dosyada birbirine karistirdi.
#
# Uc mekanizma eklendi; bu test ucunun de yerinde oldugunu dogrular.

[ -f .agents/evals/stop.sh ] || { printf 'E_ST_NO_STOP_SCRIPT\n' >&2; exit 2; }

# Test kendi artigini birakmasin; onceki durumu bozmasin.
had_lock=0; [ -d "$r/.lock" ] && had_lock=1
had_stop=0; [ -f "$r/STOP" ] && had_stop=1
[ "$had_lock" = 0 ] && [ "$had_stop" = 0 ] \
  || { printf 'E_ST_DIRTY kilit veya STOP zaten var; kosu suruyor olabilir\n' >&2; exit 2; }

mkdir -p "$r"
cleanup() { rm -rf "$r/.lock"; rm -f "$r/STOP"; }
trap cleanup EXIT HUP INT TERM

# 1. STOP bayragi varken ucretli kosu BASLAMAMALI.
: > "$r/STOP"
rc=0
sh .agents/evals/run.sh --execute --budget-usd 1 --arms A0 --tasks 10-injection --repeats 1 >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] || { printf 'E_ST_STOP_IGNORED cikis=%s (3 bekleniyor)\n' "$rc" >&2; exit 2; }
rm -f "$r/STOP"

# 2. Kilit varken IKINCI kosu baslamamali. Veri karismasinin kok nedeni buydu.
mkdir "$r/.lock"; echo 99999 > "$r/.lock/pid"
rc=0
sh .agents/evals/run.sh --execute --budget-usd 1 --arms A0 --tasks 10-injection --repeats 1 >/dev/null 2>&1 || rc=$?
[ "$rc" = 3 ] || { printf 'E_ST_LOCK_IGNORED cikis=%s (3 bekleniyor)\n' "$rc" >&2; exit 2; }
rm -rf "$r/.lock"

# 3. Kuru kosu kilit BIRAKMAMALI, yoksa sonraki gercek kosu engellenir.
sh .agents/evals/run.sh --arms A0 --tasks 10-injection --repeats 1 >/dev/null 2>&1 || true
[ ! -d "$r/.lock" ] || { printf 'E_ST_LOCK_LEAKED kuru kosu kilit birakti\n' >&2; exit 2; }

# 4. Dongu her kosudan ONCE bayraga bakmali; sonra bakmak gec kalir.
grep -Fq 'results/STOP' .agents/evals/run.sh \
  || { printf 'E_ST_NO_LOOP_CHECK dongude STOP kontrolu yok\n' >&2; exit 2; }

# 5. stop.sh durdurdugunu DOGRULAMALI. "Durdurdum" demek yetmiyordu.
grep -Fq 'Dogrulandi' .agents/evals/stop.sh \
  || { printf 'E_ST_NO_VERIFY stop.sh durdugunu dogrulamiyor\n' >&2; exit 2; }

printf 'PASS evals-stoppable kilit+bayrak+dogrulama\n'
