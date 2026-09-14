#!/bin/sh
set -eu
root=$1
contract="$root/.agents/contracts/tool-gate.md"
[ -f "$contract" ] || { printf 'FAIL tool-gate sozlesmesi yok\n' >&2; exit 1; }

tools=$(sed -n '/^## Kapsanan/,/^## Salt/p' "$contract" \
  | sed -n 's/^| \([A-Za-z_][A-Za-z0-9_*.]*\) |.*/\1/p')
[ -n "$tools" ] || { printf 'FAIL sozlesmede arac yok\n' >&2; exit 1; }

fail=0
for file in \
  "$root/.agents/adapters/claude/hooks.bash.json" \
  "$root/.agents/adapters/claude/hooks.powershell.json" \
  "$root/.claude/settings.json" \
  "$root/hooks/hooks.json"
do
  [ -f "$file" ] || { printf 'FAIL matcher dosyasi yok: %s\n' "$file" >&2; fail=1; continue; }
  matcher=$(jq -r '.hooks.PreToolUse[0].matcher // ""' "$file")
  for tool in $tools; do
    case "$matcher" in
      *"$tool"*) ;;
      *) printf 'FAIL %s matcher %s aracini kapsamiyor\n' "$file" "$tool" >&2; fail=1 ;;
    esac
  done
done
[ "$fail" -eq 0 ] || exit 1
printf 'PASS tool-gate matcher kapsami\n'
