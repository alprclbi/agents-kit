#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
pm=.agents/evals/lib/plan-matrix.sh
[ -f "$pm" ] || { printf 'E_PM_MISSING\n' >&2; exit 2; }

out=$(sh "$pm" --root "$root" --repeats 3 --cost-per-run 0.05)

# 7 kol x 7 gorev x 3 tekrar = 147 kosu.
# Bu sayilar katalog degistikce ELLE guncellenir. Sabit olmalari kazara
# gorev veya kol eklenmesini yakalar; turetilmis olsalar bunu kaciririrdi.
# 2026-09-07: 84 -> 147 (3 uyum sondasi eklendi; 09-capability enabled=0).
# 2026-09-08: 147 -> 168 (13-late-temptation eklendi).
rows=$(printf '%s\n' "$out" | grep -c '^A[0-9]' || true)
[ "$rows" = 168 ] || { printf 'E_PM_ROWS %s\n' "$rows" >&2; exit 2; }

total=$(printf '%s\n' "$out" | awk -F '\t' '$1=="TOTAL"{print $2}')
[ "$total" = 168 ] || { printf 'E_PM_TOTAL %s\n' "$total" >&2; exit 2; }

usd=$(printf '%s\n' "$out" | awk -F '\t' '$1=="TOTAL"{print $3}')
[ "$usd" = "8.40" ] || { printf 'E_PM_USD %s\n' "$usd" >&2; exit 2; }

# Her kol her tekrarda tam olarak bir kez gorunmeli (dondurme siralamayi
# degistirir, kapsami degil).
per_arm=$(printf '%s\n' "$out" | awk -F '\t' '$1 ~ /^A[0-9]$/ {n[$1]++} END{for (k in n) print n[k]}' | sort -u)
[ "$per_arm" = 24 ] || { printf 'E_PM_ARM_COVERAGE %s\n' "$per_arm" >&2; exit 2; }

# enabled=0 satirlari atlanmali.
mkdir -p "$root/.agents/runtime"
tmp=$(mktemp -d "$root/.agents/runtime/pm.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.agents/evals"
awk -F '\t' 'BEGIN{OFS="\t"} NR>1 && $1=="A4"{$2=0} {print}' .agents/evals/arms.tsv > "$tmp/.agents/evals/arms.tsv"
cp .agents/evals/tasks.tsv "$tmp/.agents/evals/tasks.tsv"
rows2=$(sh "$pm" --root "$tmp" --repeats 3 --cost-per-run 0.05 | grep -c '^A[0-9]' || true)
[ "$rows2" = 144 ] || { printf 'E_PM_DISABLED %s\n' "$rows2" >&2; exit 2; }

cl=.agents/evals/clients/claude.sh
[ -f "$cl" ] || { printf 'E_CL_MISSING\n' >&2; exit 2; }

norm=$(sh "$cl" --normalize .agents/evals/fixtures/samples/claude-result.json)
printf '%s' "$norm" | jq -e '
  .client == "claude"
  and .ok == true
  and .num_turns == 4
  and .context_tokens == 45468
  and .output_tokens == 1847
  and .thinking_tokens == 512
  and .permission_denials == 0
  and .model == "claude-sonnet-5"
' >/dev/null || { printf 'E_CL_NORMALIZE\n' >&2; exit 2; }

# Yanit dili metrigi: iki tam sayi cikmali, ham metin cikmamali.
printf '%s' "$norm" | jq -e '.response_chars == 46 and .response_turkish_chars == 9' >/dev/null \
  || { printf 'E_CL_LANG_METRIC %s\n' "$(printf '%s' "$norm" | jq -c '{response_chars,response_turkish_chars}')" >&2; exit 2; }

# Gizlilik: normalize cikti istem, transcript veya oturum kimligi tasimamali.
printf '%s' "$norm" | jq -e '
  (has("result") or has("prompt") or has("transcript")
   or has("session_id") or has("uuid")) | not
' >/dev/null || { printf 'E_CL_LEAK\n' >&2; exit 2; }

# Binary yoksa bile dry-run sema-uyumlu satir uretmeli.
sh "$cl" --dry-run --cwd . --prompt /dev/null --max-turns 1 --settings /dev/null |
  jq -e '.client == "claude" and .dry_run == true' >/dev/null \
  || { printf 'E_CL_DRYRUN\n' >&2; exit 2; }

rt=.agents/evals/lib/run-task.sh
[ -f "$rt" ] || { printf 'E_RT_MISSING\n' >&2; exit 2; }

before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'akeval.*' 2>/dev/null | wc -l)
line=$(sh "$rt" --root "$root" --arm A1 --task 01-bugfix --repeat 1 --dry-run)
after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'akeval.*' 2>/dev/null | wc -l)
[ "$before" = "$after" ] || { printf 'E_RT_SANDBOX_LEAK\n' >&2; exit 2; }

printf '%s' "$line" | jq -e '
  .arm == "A1" and .task == "01-bugfix" and .repeat == 1
  and has("oracle") and has("work_record_created") and has("context_tokens")
' >/dev/null || { printf 'E_RT_SHAPE\n' >&2; exit 2; }

# Sandbox kurulumu dogru mu: A0 AGENTS.md tasimamali, A1 tasimali.
sh "$rt" --root "$root" --arm A0 --task 01-bugfix --repeat 1 --dry-run --keep-sandbox > "$tmp/a0line"
sb=$(jq -r '.sandbox' "$tmp/a0line")
[ -d "$sb" ] || { printf 'E_RT_KEEP\n' >&2; exit 2; }
[ ! -f "$sb/AGENTS.md" ] || { printf 'E_RT_A0_HAS_AGENTS\n' >&2; rm -rf "$sb"; exit 2; }
[ -f "$sb/fixtures/slug/test.sh" ] || { printf 'E_RT_NO_FIXTURE_COPY\n' >&2; rm -rf "$sb"; exit 2; }
rm -rf "$sb"

sh "$rt" --root "$root" --arm A1 --task 01-bugfix --repeat 1 --dry-run --keep-sandbox > "$tmp/a1line"
sb=$(jq -r '.sandbox' "$tmp/a1line")
[ -f "$sb/AGENTS.md" ] || { printf 'E_RT_A1_NO_AGENTS\n' >&2; rm -rf "$sb"; exit 2; }
[ -d "$sb/.agents/skills" ] || { printf 'E_RT_NO_SKILLS\n' >&2; rm -rf "$sb"; exit 2; }
rm -rf "$sb"

rs=.agents/evals/run.sh
[ -f "$rs" ] || { printf 'E_RS_MISSING\n' >&2; exit 2; }

# Sonuc dosyasinin varligi dry-run'dan ETKILENMEMELI. Varlik yerine degisimi
# olcuyoruz; boylece gercek bir kosudan sonra da bu test dogru kalir.
results=.agents/evals/results/runs.jsonl
before_state=absent; [ -f "$results" ] && before_state=present

out=$(sh "$rs" --root "$root")
printf '%s\n' "$out" | grep -q '^TOTAL' || { printf 'E_RS_NO_TOTAL\n' >&2; exit 2; }
printf '%s\n' "$out" | grep -q 'DRY-RUN' || { printf 'E_RS_NOT_DRY\n' >&2; exit 2; }

after_state=absent; [ -f "$results" ] && after_state=present
[ "$before_state" = "$after_state" ] || { printf 'E_RS_DRY_WROTE\n' >&2; exit 2; }

# --execute butcesiz reddedilmeli.
if sh "$rs" --root "$root" --execute >/dev/null 2>&1; then
  printf 'E_RS_NO_BUDGET_GATE\n' >&2; exit 2
fi

# Butce reddi de sonuc dosyasina dokunmamali.
final_state=absent; [ -f "$results" ] && final_state=present
[ "$before_state" = "$final_state" ] || { printf 'E_RS_GATE_WROTE\n' >&2; exit 2; }

# Filtre, katalogun enabled sutununu EZEBILMELI; kademeli kosu buna dayanir.
f=$(sh "$pm" --root "$root" --repeats 1 --cost-per-run 0.05 --arms A0,A1 --tasks 10-injection)
[ "$(printf '%s\n' "$f" | grep -c '^A')" = 2 ] \
  || { printf 'E_PM_FILTER %s\n' "$f" >&2; exit 2; }

# Bilinmeyen kol bos matris uretmeli, sessizce tam katalogu kosmamali.
if sh "$pm" --root "$root" --repeats 1 --cost-per-run 0.05 --arms YOK-BOYLE-KOL >/dev/null 2>&1; then
  printf 'E_PM_FILTER_SILENT bilinmeyen kol hata vermedi\n' >&2; exit 2
fi

printf 'PASS evals-contract\n'
