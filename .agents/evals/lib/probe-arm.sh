#!/bin/sh
set -eu

# Bir kolun TALIMAT YUKUNU olcer. Gorev yok, oracle yok.
#
# Gerekce: kural dosyasinin sabit bedeli ilk turda cache_creation olarak
# yuklenir. Tam gorev kosusu bu sayiyi vermek icin gereksiz -- ustelik
# context_tokens tur sayisiyla olceklendigi icin sinyali gomuyor (bkz.
# spec G5-DUZELTME). Tek turluk sonda ayni sayiyi ~5 kat ucuza ve
# tekrar gerektirmeyecek kadar dusuk varyansla verir.

root='' arm='' dry=0 model=''
while [ $# -gt 0 ]; do
  case $1 in
    --root)    root=$2;  shift 2 ;;
    --arm)     arm=$2;   shift 2 ;;
    --model)   model=$2; shift 2 ;;
    --dry-run) dry=1;    shift ;;
    *) printf 'E_PB_ARG %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$root" ] && [ -n "$arm" ] || { printf 'E_PB_ARGS\n' >&2; exit 2; }

evals="$root/.agents/evals"
prompt="$evals/probe-prompt.md"
[ -f "$prompt" ] || { printf 'E_PB_NO_PROMPT\n' >&2; exit 2; }

sandbox=$(mktemp -d "${TMPDIR:-/tmp}/akprobe.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT HUP INT TERM

sh "$evals/lib/build-variant.sh" --root "$root" --arm "$arm" --out "$sandbox"

# Iskelet her kolda AYNI olmali; tek degisken AGENTS.md varyantidir.
mkdir -p "$sandbox/.agents/changes/active"
cp "$root/.agents/config.json" "$sandbox/.agents/config.json"
[ -f "$root/.agents/project.md" ] && cp "$root/.agents/project.md" "$sandbox/.agents/project.md"
cp -R "$root/skills" "$sandbox/.agents/skills"
cp -R "$root/.agents/templates" "$sandbox/.agents/templates"

# Yuklenen talimat baytini da kaydet: olculen token ile karsilastirmak,
# "4 bayt = 1 token" varsayimini dogrulamayi saglar.
agents_bytes=0
[ -f "$sandbox/AGENTS.md" ] && agents_bytes=$(wc -c < "$sandbox/AGENTS.md" | tr -d ' ')

set -- --cwd "$sandbox" --prompt "$prompt" --max-turns 1 --settings "$evals/sandbox-settings.json"
[ -n "$model" ] && set -- "$@" --model "$model"
[ "$dry" = 1 ] && set -- "$@" --dry-run

metrics=$(sh "$evals/clients/claude.sh" "$@")

printf '%s' "$metrics" | jq -c \
  --arg arm "$arm" --argjson ab "$agents_bytes" \
  '. + {arm: $arm, agents_md_bytes: $ab, kind: "probe"}'
