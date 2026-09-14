#!/bin/sh
set -eu

root='' arm='' task='' repeat=1 dry=0 model='' keep=0
while [ $# -gt 0 ]; do
  case $1 in
    --root)         root=$2;   shift 2 ;;
    --arm)          arm=$2;    shift 2 ;;
    --task)         task=$2;   shift 2 ;;
    --repeat)       repeat=$2; shift 2 ;;
    --model)        model=$2;  shift 2 ;;
    --dry-run)      dry=1;     shift ;;
    --keep-sandbox) keep=1;    shift ;;
    *) printf 'E_RT_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$root" ] && [ -n "$arm" ] && [ -n "$task" ] || { printf 'E_RT_ARGS\n' >&2; exit 2; }

evals="$root/.agents/evals"
taskdir="$evals/tasks/$task"
[ -d "$taskdir" ] || { printf 'E_RT_NO_TASK %s\n' "$task" >&2; exit 2; }
fixture=$(awk -F '\t' -v t="$task" 'NR>1 && $1==t {print $2}' "$evals/tasks.tsv")
[ -n "$fixture" ] || { printf 'E_RT_NO_FIXTURE %s\n' "$task" >&2; exit 2; }

# Sandbox repo DISINDA acilir; kitin kendi dosyalarina asla dokunulmaz.
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/akeval.XXXXXX")
if [ "$keep" = 0 ]; then
  trap 'rm -rf "$sandbox"' EXIT HUP INT TERM
fi

mkdir -p "$sandbox/fixtures"
cp -R "$evals/fixtures/$fixture" "$sandbox/fixtures/$fixture"
sh "$evals/lib/build-variant.sh" --root "$root" --arm "$arm" --out "$sandbox"

# Kit iskeleti kopyalanir; surec kurallari ancak boyle tetiklenebilir.
mkdir -p "$sandbox/.agents/changes/active"
cp "$root/.agents/config.json" "$sandbox/.agents/config.json"
# CLAUDE.md bunu import ediyor; kopyalanmazsa import kirik kalir.
[ -f "$root/.agents/project.md" ] && cp "$root/.agents/project.md" "$sandbox/.agents/project.md"
cp -R "$root/skills" "$sandbox/.agents/skills"
cp -R "$root/.agents/templates" "$sandbox/.agents/templates"

# Gorev kendi baslangic durumunu kurabilir. Gerekce: tek fixture birden
# fazla goreve hizmet ediyor; her gorev ayni kirik durumdan baslamak
# zorunda degil. setup.sh olmayan gorev fixture'i oldugu gibi alir.
if [ -f "$taskdir/setup.sh" ]; then
  sh "$taskdir/setup.sh" "$sandbox" || { printf 'E_RT_SETUP_FAILED %s
' "$task" >&2; exit 2; }
fi

# Tur siniri gorev katalogundan gelir; sondalar kisa, gorevler uzundur.
max_turns=$(awk -F '\t' -v t="$task" 'NR>1 && $1==t {print $5}' "$evals/tasks.tsv")
case "$max_turns" in ''|*[!0-9]*) max_turns=30 ;; esac

# Izin yuzeyi sandbox DISINDA tutulur: ajan onu goremez, okuyamaz, degistiremez.
settings="$evals/sandbox-settings.json"

set -- --cwd "$sandbox" --prompt "$taskdir/prompt.md" --max-turns "$max_turns" --settings "$settings"
[ -n "$model" ] && set -- "$@" --model "$model"
[ "$dry" = 1 ] && set -- "$@" --dry-run

metrics=$(sh "$evals/clients/claude.sh" "$@")

run_ok=$(printf '%s' "$metrics" | jq -r '.ok // false')

if [ "$dry" = 1 ]; then
  oracle=skipped
elif [ "$run_ok" != true ]; then
  # Cagri yarida kesildiyse sandbox yarim durumdadir: ajan hatayi duzeltmis
  # ama oturum olmus olabilir. Boyle bir kosuyu pass/fail diye raporlamak
  # olcumu kirletir; ayri bir deger kullanilir.
  oracle=invalid
elif sh "$taskdir/oracle.sh" "$sandbox" >/dev/null 2>&1; then
  oracle=pass
else
  oracle=fail
fi

# Ikincil uyum sinyali (spec G9): ajan kitin is kaydi kuralini uyguladi mi?
# Oracle'i etkilemez -- yoksa AGENTS.md'siz kol haksiz yere kalirdi.
if [ -n "$(find "$sandbox/.agents/changes/active" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
  work_record=true
else
  work_record=false
fi

printf '%s' "$metrics" | jq -c \
  --arg arm "$arm" --arg task "$task" --argjson repeat "$repeat" \
  --arg oracle "$oracle" --argjson wr "$work_record" --arg sb "$sandbox" \
  '. + {arm: $arm, task: $task, repeat: $repeat, oracle: $oracle,
        work_record_created: $wr, sandbox: $sb}'
