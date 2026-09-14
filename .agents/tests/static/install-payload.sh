#!/bin/sh
set -eu
root=$1
cd "$root"
fail=0

# KURULUM YUKU SOZLESMESI.
#
# Kullanicinin projesine yalnizca ona ait olan seyler girer. Kitin kendi
# gelistirme altyapisi (testler, eval kosulari) orada is gormez; yer
# kaplar, karisiklik uretir ve kullanicinin kendi test dizinleriyle
# karisabilir.
#
# Bu test manifest uzerinden DEGIL, GERCEK KURULUM yaparak dogrular.

[ -f install.sh ] || { printf 'FAIL install.sh yok\n' >&2; exit 1; }

tmp=$(mktemp -d)
case "$tmp" in /*) ;; *) printf 'FAIL gecici dizin alinamadi\n' >&2; exit 1 ;; esac
cleanup() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup EXIT HUP INT TERM

kit=$(pwd -P)
mkdir -p "$tmp/proje"
( cd "$tmp/proje" && sh "$kit/install.sh" --yes >/dev/null 2>&1 ) \
  || { printf 'FAIL kurulum basarisiz\n' >&2; exit 1; }

# --- Kurulmamasi gerekenler ------------------------------------------
for forbidden in .agents/tests .agents/evals .claude-plugin .codex-plugin skills hooks; do
  [ ! -e "$tmp/proje/$forbidden" ] \
    || { printf 'FAIL kurulum yuku %s icermemeli\n' "$forbidden" >&2; fail=1; }
done

# --- Kurulmasi gerekenler --------------------------------------------
for required in AGENTS.md CLAUDE.md .agents/config.json .agents/playbooks \
                .agents/contracts .agents/templates .agents/schemas \
                .agents/validators .agents/skills .claude/settings.json; do
  [ -e "$tmp/proje/$required" ] \
    || { printf 'FAIL kurulum yuku %s icermeli\n' "$required" >&2; fail=1; }
done

# --- Kurulan projede manifest kendi icerigini anlatmali ---------------
( cd "$tmp/proje" && sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check >/dev/null 2>&1 ) \
  || { printf 'FAIL kurulan projede manifest dogrulanmadi\n' >&2; fail=1; }

# --- Manifestte kurulmayan yol kalmamali ------------------------------
if command -v jq >/dev/null 2>&1; then
  stale=$(jq -r '.files[].path' "$tmp/proje/.agents/manifest.json" \
          | grep -E '^(\.agents/(tests|evals)/|skills/|hooks/|\.claude-plugin/|\.codex-plugin/)' || true)
  [ -z "$stale" ] || { printf 'FAIL hedef manifest kurulmayan yol tasiyor:\n%s\n' "$stale" >&2; fail=1; }
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS install-payload\n'
