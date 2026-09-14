#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
# cost: OLCULMUS kosu basi maliyet. 2026-09-07 revizyonu: onceki 0.35
# degeri yalniz 01-bugfix'ten (uzun gorev) geliyordu; 18 kosuluk
# runs-07/runs-08 araligi 0.089-0.281, ortanca ~0.12. Ayrinti icin
# plan-matrix.sh yorumuna bak.
execute=0 budget='' repeats=3 cost='0.15' model='' delay=5 probe=0
probe_cost='0.07'
# Kademeli kosu bayraklari; plan-matrix.sh'ye aynen gecirilir.
arms_filter='' tasks_filter=''
# Spike/tanilama icin sandbox korunur; normal kosuda kapalidir.
keep=0

while [ $# -gt 0 ]; do
  case $1 in
    --root)       root=$2;    shift 2 ;;
    --execute)    execute=1;  shift ;;
    --budget-usd) budget=$2;  shift 2 ;;
    --repeats)    repeats=$2; shift 2 ;;
    --model)      model=$2;   shift 2 ;;
    --delay-secs) delay=$2;   shift 2 ;;
    --probe)      probe=1;    shift ;;
    --arms)       arms_filter=$2;  shift 2 ;;
    --tasks)      tasks_filter=$2; shift 2 ;;
    --keep-sandbox) keep=1; shift ;;
    *) printf 'E_RS_ARG %s\n' "$1" >&2; exit 3 ;;
  esac
done

evals="$root/.agents/evals"
arms_file="$evals/arms.tsv"

# ---------------------------------------------------------------- sonda modu
# Yalniz TALIMAT YUKUNU olcer: kol basina tek turluk trivial istem.
# Gorev kosusundan ~5 kat ucuz ve dusuk varyansli (bkz. spec G5-DUZELTME).
if [ "$probe" = 1 ]; then
  n=$(awk -F '\t' 'NR>1 && $2==1 {c++} END{print c+0}' "$arms_file")

  if [ "$execute" = 0 ]; then
    awk -F '\t' 'NR>1 && $2==1 {print $1 "  sonda  1 tur"}' "$arms_file"
    printf 'TOTAL\t%s\t%s\n' "$n" "$(awk -v c="$n" -v p="$probe_cost" 'BEGIN{printf "%.2f", c*p}')"
    printf '\nDRY-RUN (sonda): hicbir ajan cagrisi yapilmadi, hicbir ucret dogmadi.\n'
    printf 'Gercek sonda icin: run.sh --probe --execute --budget-usd <N>\n'
    exit 0
  fi

  [ -n "$budget" ] || {
    printf 'E_RS_BUDGET_REQUIRED --execute icin --budget-usd zorunlu\n' >&2
    exit 3
  }

  mkdir -p "$evals/results"
  pout="$evals/results/probe.jsonl"
  plist=$(mktemp)
  trap 'rm -f "$plist"' EXIT HUP INT TERM
  awk -F '\t' 'NR>1 && $2==1 {print $1}' "$arms_file" > "$plist"

  : > "$pout"
  spent=0
  while read -r arm; do
    [ -n "$arm" ] || continue
    set -- --root "$root" --arm "$arm"
    [ -n "$model" ] && set -- "$@" --model "$model"
    line=$(sh "$evals/lib/probe-arm.sh" "$@")
    printf '%s\n' "$line" >> "$pout"
    spent=$(printf '%s' "$line" | jq -r --argjson s "$spent" '$s + (.total_cost_usd // 0)')
    printf 'sonda %s -> cache_creation=%s tur=%s  (%s USD)\n' "$arm" \
      "$(printf '%s' "$line" | jq -r '.cache_creation_tokens')" \
      "$(printf '%s' "$line" | jq -r '.num_turns')" "$spent" >&2
    [ "$delay" -gt 0 ] && sleep "$delay"
    if [ "$(awk -v a="$spent" -v b="$budget" 'BEGIN{print (a>b)?1:0}')" = 1 ]; then
      printf '\nBUTCE ASILDI: %s > %s USD. Kalan kollar atlandi.\n' "$spent" "$budget" >&2
      break
    fi
  done < "$plist"

  printf '\nSonuc: %s\n' "$pout"
  printf 'Harcanan: %s USD\n' "$spent"
  exit 0
fi

# ------------------------------------------------------------ tam gorev modu
set -- --root "$root" --repeats "$repeats" --cost-per-run "$cost"
[ -n "$arms_filter" ]  && set -- "$@" --arms "$arms_filter"
[ -n "$tasks_filter" ] && set -- "$@" --tasks "$tasks_filter"
matrix=$(sh "$evals/lib/plan-matrix.sh" "$@")

if [ "$execute" = 0 ]; then
  printf '%s\n' "$matrix"
  printf '\nDRY-RUN: hicbir ajan cagrisi yapilmadi, hicbir ucret dogmadi.\n'
  printf 'Gercek kosu icin: run.sh --execute --budget-usd <N>\n'
  exit 0
fi

# Ucretli bir aracin varsayilani para harcamamalidir; butce zorunludur.
[ -n "$budget" ] || {
  printf 'E_RS_BUDGET_REQUIRED --execute icin --budget-usd zorunlu\n' >&2
  exit 3
}

mkdir -p "$evals/results"
out="$evals/results/runs.jsonl"

# --- KILIT: iki kosu ayni anda calisamaz -------------------------------
# 2026-09-08: iki run.sh ayni anda ayakta kaldi, ayni dosyaya yazdilar ve
# veriyi birbirine karistirdilar. Kilit bunu yapisal olarak engeller.
lock="$evals/results/.lock"
if [ -d "$lock" ]; then
  old_pid=$(cat "$lock/pid" 2>/dev/null || echo '?')
  printf 'E_RS_LOCKED baska bir kosu zaten calisiyor (pid %s)\n' "$old_pid" >&2
  printf 'Durdurmak icin: sh .agents/evals/stop.sh\n' >&2
  exit 3
fi
if [ -f "$evals/results/STOP" ]; then
  printf 'E_RS_STOP_FLAG durdurma bayragi duruyor; silmeden kosu baslamaz.\n' >&2
  printf 'Sil: rm .agents/evals/results/STOP\n' >&2
  exit 3
fi
mkdir "$lock" || { printf 'E_RS_LOCK_FAILED\n' >&2; exit 3; }
echo $$ > "$lock/pid"
cleanup_lock() { rm -rf "$lock"; rm -f "${work:-}"; }
# TEK trap: shell-de sonraki trap oncekini EZER. Iki ayri trap yazmak
# kilidin hic temizlenmemesine yol acti (2026-09-08).
trap 'cleanup_lock' EXIT HUP INT TERM
# Onceki partiyi SESSIZCE silme (2026-09-08 bulgusu: kademeli kosuda
# kademe 1, kademe 0-in ham kayitlarini yok ediyordu). Var olan sonuc
# zaman damgasiyla kenara alinir; results/ zaten git disidir.
if [ -s "$out" ]; then
  keep_prev="$evals/results/runs-$(date +%Y%m%d-%H%M%S).jsonl"
  mv -- "$out" "$keep_prev"
  printf 'onceki parti korundu: %s\n' "$keep_prev" >&2
fi
work=$(mktemp)
# TOTAL satirini disla; kol adina gore filtrelemek E1 gibi A ile
# baslamayan kollari sessizce dusururdu (2026-09-08 bulgusu).
printf '%s\n' "$matrix" | grep -v '^TOTAL' | grep . > "$work"

: > "$out"
spent=0
done_n=0
total=$(awk 'END{print NR}' "$work")

# Boru hatti yerine dosyadan okuma: alt kabuk olusmaz, butce birikimi
# ve sayaclar dongu disinda da gecerli kalir.
while read -r arm task repeat; do
  [ -n "$arm" ] || continue

  # Durdurma bayragi: her kosudan ONCE bakilir. TaskStop gibi disaridan
  # gelen sinyaller bu zinciri guvenilir sekilde oldurmuyordu.
  if [ -f "$evals/results/STOP" ]; then
    printf '\nDURDURULDU: STOP bayragi bulundu. %s/%s kosu yapildi.\n' "$done_n" "$total" >&2
    break
  fi

  set -- --root "$root" --arm "$arm" --task "$task" --repeat "$repeat"
  [ -n "$model" ] && set -- "$@" --model "$model"
  [ "$keep" = 1 ] && set -- "$@" --keep-sandbox
  line=$(sh "$evals/lib/run-task.sh" "$@")
  printf '%s\n' "$line" | jq -c 'del(.sandbox)' >> "$out"

  # Ardisik oturumlar limit patlamasina yol acabiliyor (2026-09-06: 10 kosunun
  # 8'i pes pese basarisiz oldu). Kosular arasi kisa bekleme ucuz sigortadir.
  [ "$delay" -gt 0 ] && sleep "$delay"

  done_n=$((done_n + 1))
  spent=$(printf '%s' "$line" | jq -r --argjson s "$spent" '$s + (.total_cost_usd // 0)')
  printf '[%s/%s] %s %s r%s -> %s  (%s USD)\n' \
    "$done_n" "$total" "$arm" "$task" "$repeat" \
    "$(printf '%s' "$line" | jq -r '.oracle')" "$spent" >&2

  if [ "$(awk -v a="$spent" -v b="$budget" 'BEGIN{print (a>b)?1:0}')" = 1 ]; then
    printf '\nBUTCE ASILDI: %s > %s USD. Kalan kosular atlandi.\n' "$spent" "$budget" >&2
    break
  fi
done < "$work"

printf '\nSonuc: %s\n' "$out"
printf 'Kosu: %s/%s   Harcanan: %s USD\n' "$done_n" "$total" "$spent"
