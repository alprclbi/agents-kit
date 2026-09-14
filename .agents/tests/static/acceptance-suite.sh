#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

[ -f .agents/tests/lib/run-case.sh ] || { printf 'E_ACCEPTANCE_UNIX_CASE_RUNNER\n' >&2; exit 2; }
[ -f .agents/tests/lib/RunCase.psm1 ] || { printf 'E_ACCEPTANCE_WINDOWS_CASE_RUNNER\n' >&2; exit 2; }
[ -f .agents/tests/run.sh ] || { printf 'E_ACCEPTANCE_UNIX_RUNNER\n' >&2; exit 2; }
[ -f .agents/tests/run.ps1 ] || { printf 'E_ACCEPTANCE_WINDOWS_RUNNER\n' >&2; exit 2; }

case_count=$(awk -F '\t' 'NR > 1 && NF {n++} END {print n+0}' .agents/tests/scenarios/cases.tsv)
[ "$case_count" -eq 25 ] || { printf 'E_ACCEPTANCE_CASE_COUNT %s\n' "$case_count" >&2; exit 2; }

while IFS="$(printf '\t')" read -r id name fixture class profile expected; do
  [ "$id" = id ] && continue
  [ -n "$id" ] || continue
  for file in input.json expected.json; do
    [ -f ".agents/tests/fixtures/acceptance/$fixture/$file" ] || { printf 'E_ACCEPTANCE_FIXTURE %s/%s\n' "$fixture" "$file" >&2; exit 2; }
    jq -e . ".agents/tests/fixtures/acceptance/$fixture/$file" >/dev/null
  done
  grep -Eq "^[[:space:]]*$id\\)" .agents/tests/lib/run-case.sh || { printf 'E_ACCEPTANCE_UNIX_BRANCH %s\n' "$id" >&2; exit 2; }
  grep -Eq "^[[:space:]]*'$id'[[:space:]]*\\{" .agents/tests/lib/RunCase.psm1 || { printf 'E_ACCEPTANCE_WINDOWS_BRANCH %s\n' "$id" >&2; exit 2; }
done < .agents/tests/scenarios/cases.tsv

grep -Fq 'function Invoke-AgentKitCase' .agents/tests/lib/RunCase.psm1
grep -Fq "\$actual = 'SKIP'" .agents/tests/lib/RunCase.psm1
grep -Fq "'FAIL', 'BLOCKED'" .agents/tests/run.ps1
grep -Fq 'Encoding utf8' .agents/tests/run.ps1
grep -Fq 'static-%03d.tsv' .agents/tests/run.sh
grep -Fq 'case-%s.tsv' .agents/tests/run.sh
grep -Fq 'case result completeness' .agents/tests/run.sh

if grep -rEn 'BEGIN (RSA |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,}' .agents/tests/fixtures/acceptance >/dev/null 2>&1; then
  printf 'E_ACCEPTANCE_SECRET_PATTERN\n' >&2
  exit 2
fi

printf 'PASS acceptance-suite\n'
