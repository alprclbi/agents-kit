#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
f=AGENTS.md

expected='bootstrap discipline engineering safety meta'

# 1. Her beklenen blok tam olarak bir start ve bir end tasimali.
for b in $expected; do
  s=$(grep -c "^<!-- ak:block start=$b -->$" "$f" || true)
  e=$(grep -c "^<!-- ak:block end=$b -->$" "$f" || true)
  [ "$s" = 1 ] || { printf 'E_MARKER_START %s=%s\n' "$b" "$s" >&2; exit 2; }
  [ "$e" = 1 ] || { printf 'E_MARKER_END %s=%s\n' "$b" "$e" >&2; exit 2; }
done

# 2. Baska isaretci olmamali.
total=$(grep -c '^<!-- ak:block ' "$f" || true)
[ "$total" = 10 ] || { printf 'E_MARKER_TOTAL %s\n' "$total" >&2; exit 2; }

# 3. Ic ice gecmemeli: her start'i kendi end'i izlemeli.
awk '
  /^<!-- ak:block start=/ { if (open) { print "E_MARKER_NESTED"; exit 2 } open=1; next }
  /^<!-- ak:block end=/   { if (!open) { print "E_MARKER_UNOPENED"; exit 2 } open=0; next }
  END { if (open) { print "E_MARKER_UNCLOSED"; exit 2 } }
' "$f" || exit 2

# 4. Butce bozulmamali.
bytes=$(wc -c < "$f" | tr -d ' ')
lines=$(wc -l < "$f" | tr -d ' ')
maxb=$(jq -r '.instructionBudgets.agentsMaxBytes' .agents/config.json)
maxl=$(jq -r '.instructionBudgets.agentsMaxLines' .agents/config.json)
[ "$bytes" -le "$maxb" ] || { printf 'E_MARKER_BUDGET_BYTES %s>%s\n' "$bytes" "$maxb" >&2; exit 2; }
[ "$lines" -le "$maxl" ] || { printf 'E_MARKER_BUDGET_LINES %s>%s\n' "$lines" "$maxl" >&2; exit 2; }

printf 'PASS evals-markers %sb %sl\n' "$bytes" "$lines"
