#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"
hooks="$root/.codex/hooks.json"

# CODEX HOOK KOK KESFI SOZLESMESI.
#
# Kok bulma mantigi (once Git koku, sonra AGENTS.md + .agents/config.json
# isaretci aramasi) hook komutlarinda degil dogrulayicida durur:
# --discover-root (sh) ve -DiscoverRoot (PowerShell). Hook komutu yalniz
# dogrulayici betigi yukari dogru arar. Onceden ayni dongu uc hook x iki
# kabukta alti kez satir ici yaziliydi ve hata alti yerde ayri ayri
# duzeltilmek zorundaydi.

# Gecici dizin kitin deposu DISINDA olmali: icinde olsaydi Git koku her
# vakada kitin kendisi cikardi.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/akroot.XXXXXX")
case "$tmp" in /*/*) ;; *) printf 'FAIL gecici dizin: %s\n' "$tmp" >&2; exit 1 ;; esac
cleanup() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup EXIT HUP INT TERM

kit() {
  mkdir -p "$1/.agents"
  printf '# test\n' > "$1/AGENTS.md"
  printf '{"profile":"solo","instructionBudgets":{"sessionContextMaxChars":8000}}\n' > "$1/.agents/config.json"
}

discover() {
  (cd "$1" && sh -c '. "$1"; ak_discover_root "$PWD"' sh "$root/.agents/validators/sh/lib.sh")
}

# --- 1. Git disi: alt dizinden yukari isaretci aramasi ----------------
kit "$tmp/duz"
mkdir -p "$tmp/duz/a/b"
got=$(discover "$tmp/duz/a/b") || got=''
want=$(cd "$tmp/duz" && pwd -P)
[ "$got" = "$want" ] || { printf 'FAIL isaretci aramasi: beklenen %s gelen %s\n' "$want" "$got" >&2; fail=1; }

# --- 2. Git koku ic ice iskeleye gore once gelir ----------------------
kit "$tmp/git"
kit "$tmp/git/ic"
git -C "$tmp/git" init -q
got=$(discover "$tmp/git/ic") || got=''
want=$(cd "$tmp/git" && pwd -P)
[ "$got" = "$want" ] || { printf 'FAIL git koku once gelmeli: beklenen %s gelen %s\n' "$want" "$got" >&2; fail=1; }

# --- 3. Git kokunde iskele yoksa isaretci aramasina duser ---------------
mkdir -p "$tmp/gitbos/alt"
kit "$tmp/gitbos/alt"
git -C "$tmp/gitbos" init -q
got=$(discover "$tmp/gitbos/alt") || got=''
want=$(cd "$tmp/gitbos/alt" && pwd -P)
[ "$got" = "$want" ] || { printf 'FAIL iskelesiz git koku: beklenen %s gelen %s\n' "$want" "$got" >&2; fail=1; }

# --- 4. Hicbir yerde iskele yok: AKE900 ve cikis 3 ---------------------
mkdir -p "$tmp/yok"
set +e
out=$(cd "$tmp/yok" && sh "$validator" doctor --discover-root --client codex --format json 2>&1)
code=$?
set -e
[ "$code" -eq 3 ] && printf '%s' "$out" | grep -Fq 'AKE900' \
  || { printf 'FAIL iskele yokken AKE900/3 beklendi: %s %s\n' "$code" "$out" >&2; fail=1; }

# --- 5. Hook komutlari: mantik betikte, satir icinde degil ---------------
for event in SessionStart PreToolUse Stop; do
  command=$(jq -r ".hooks.$event[0].hooks[0].command" "$hooks")
  windows=$(jq -r ".hooks.$event[0].hooks[0].commandWindows" "$hooks")
  case "$command" in *'--discover-root'*) ;; *) printf 'FAIL %s komutu --discover-root kullanmiyor\n' "$event" >&2; fail=1 ;; esac
  case "$windows" in *'-DiscoverRoot'*) ;; *) printf 'FAIL %s Windows komutu -DiscoverRoot kullanmiyor\n' "$event" >&2; fail=1 ;; esac
  case "$command$windows" in *'rev-parse'*|*'config.json'*) printf 'FAIL %s komutunda satir ici kok mantigi kaldi\n' "$event" >&2; fail=1 ;; esac
done
# Bulucu on eki uc hook'ta birebir ayni olmali; ayrisirsa duzeltme yine
# alti yere dagilir.
prefixes=$(jq -r '.hooks[][0].hooks[0].command | sub("agent-kit\\.sh\" .*$"; "")' "$hooks" | sort -u | awk 'END {print NR}')
[ "$prefixes" -eq 1 ] || { printf 'FAIL sh bulucu on eki hook basina farkli\n' >&2; fail=1; }
prefixes=$(jq -r '.hooks[][0].hooks[0].commandWindows | sub("agent-kit\\.ps1.\\) .*$"; "")' "$hooks" | sort -u | awk 'END {print NR}')
[ "$prefixes" -eq 1 ] || { printf 'FAIL Windows bulucu on eki hook basina farkli\n' >&2; fail=1; }

# --- 6. Komut alt dizinden calisir ----------------------------------------
session=$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$hooks")
out=$(cd "$root/.agents/tests/static" && printf '%s' '{"source":"startup"}' | /bin/sh -c "$session") \
  || { printf 'FAIL alt dizinden SessionStart calismadi\n' >&2; fail=1; out=''; }
printf '%s' "$out" | grep -Fq "Proje kökü: $root" \
  || { printf 'FAIL alt dizinden kok yanlis cozuldu: %s\n' "$(printf '%s' "$out" | sed -n 3p)" >&2; fail=1; }

# --- 7. PowerShell paritesi --------------------------------------------
ps_bin=$(command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null || true)
if [ -n "$ps_bin" ]; then
  module="$root/.agents/validators/ps/AgentKit.psm1"
  command -v cygpath >/dev/null 2>&1 && module=$(cygpath -w "$module")
  for pair in "duz/a/b:duz" "git/ic:git" "gitbos/alt:gitbos/alt"; do
    start="$tmp/${pair%%:*}"
    want=$(cd "$tmp/${pair##*:}" && pwd -P)
    if command -v cygpath >/dev/null 2>&1; then start=$(cygpath -w "$start"); want=$(cygpath -w "$want"); fi
    got=$("$ps_bin" -NoProfile -NonInteractive -Command \
      "Import-Module '$module' -Force; Resolve-AgentKitDiscoveredRoot -Start '$start'" 2>/dev/null | tr -d '\r') || got=''
    [ "$got" = "$want" ] || { printf 'FAIL ps paritesi [%s]: beklenen %s gelen %s\n' "$pair" "$want" "$got" >&2; fail=1; }
  done
else
  printf 'SKIP ps paritesi: PowerShell bulunamadi\n' >&2
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS codex-hook-root\n'
