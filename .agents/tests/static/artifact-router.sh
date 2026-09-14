#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

skill=skills/artifact-router/SKILL.md
entry=.agents/validators/sh/route-artifact.sh
[ -f "$skill" ] || { printf 'E_ROUTER_SKILL_MISSING\n' >&2; exit 2; }
[ -f "$entry" ] || { printf 'E_ROUTER_ENTRYPOINT_MISSING\n' >&2; exit 2; }

tab=$(printf '\t')
while IFS="$tab" read -r backend role expected; do
  output=$(sh "$entry" --backend "$backend" --work-id 123-auth --role "$role" --source work)
  actual=$(printf '%s' "$output" | jq -r '.path')
  [ "$actual" = "$expected" ] || { printf 'E_ROUTER_PATH %s %s %s\n' "$backend" "$role" "$actual" >&2; exit 2; }
  printf '%s' "$output" | jq -e --arg backend "$backend" --arg role "$role" '.workId == "123-auth" and .backend == $backend and .role == $role and .source == "work" and (.authorityRequired == [])' >/dev/null
done < .agents/tests/fixtures/router/cases.tsv

set +e
escape_output=$(sh "$entry" --backend native --work-id ../escape --role spec --source user 2>&1)
escape_code=$?
set -e
[ "$escape_code" -eq 2 ]
printf '%s' "$escape_output" | grep -Fq 'AKE301'

for adapter in superpowers spec-kit openspec external-backend; do
  [ -f ".agents/adapters/$adapter.md" ] || { printf 'E_BACKEND_ADAPTER_MISSING %s\n' "$adapter" >&2; exit 2; }
done

printf 'PASS artifact-router\n'
