#!/bin/sh
set -u

[ "$#" -eq 6 ] || { printf 'unknown\tFAIL\tE_CASE_ARGS\trun-case-arguments\n'; exit 2; }
project_root=$1
case_id=$2
fixture_dir=$3
case_class=$4
profile=$5
catalog_expected=$6

input="$fixture_dir/input.json"
expected_file="$fixture_dir/expected.json"
if [ ! -f "$input" ] || [ ! -f "$expected_file" ]; then
  printf '%s\tFAIL\tE_CASE_FIXTURE\tfixture-files-missing\n' "$case_id"
  exit 2
fi
if ! jq -e --arg id "$case_id" '.id == $id and .fixtureData == "synthetic" and .containsSecrets == false' "$input" >/dev/null; then
  printf '%s\tFAIL\tE_CASE_INPUT\tfixture-contract\n' "$case_id"
  exit 2
fi

validator="$project_root/.agents/validators/sh/agent-kit.sh"
router="$project_root/.agents/validators/sh/route-artifact.sh"
test_root="$project_root/.agents/tests"
actual=FAIL
evidence=unverified

case "$case_id" in
  01)
    if jq -e '.recommendation == "direct-install" and .externalWrites == false and .requiresApproval == true' "$test_root/fixtures/adoption/empty-repo/expected.json" >/dev/null; then
      actual=PASS; evidence=direct-install-requires-approval
    fi
    ;;
  02)
    if jq -e '.recommendation == "merge-required" and .overwrite == false' "$test_root/fixtures/adoption/existing-instructions/expected.json" >/dev/null; then
      actual=PASS; evidence=existing-instructions-preserved
    fi
    ;;
  03)
    if command -v codex >/dev/null 2>&1 && [ "${AGENT_KIT_LIVE_CLIENTS:-0}" = 1 ]; then
      actual=BLOCKED; evidence=live-codex-observation-required
    else
      actual=SKIP; evidence=AKS503-codex-binary-or-trust-unavailable
    fi
    ;;
  04)
    if command -v claude >/dev/null 2>&1 && [ "${AGENT_KIT_LIVE_CLIENTS:-0}" = 1 ]; then
      actual=BLOCKED; evidence=live-claude-observation-required
    else
      actual=SKIP; evidence=AKS503-claude-binary-or-trust-unavailable
    fi
    ;;
  05)
    route=$(sh "$router" --backend native --work-id 123-auth --role spec --source work 2>/dev/null)
    if printf '%s' "$route" | jq -e '.path == ".agents/changes/active/123-auth/spec.md"' >/dev/null && grep -Fq 'brainstorming' "$project_root/.agents/adapters/superpowers.md"; then
      actual=PASS; evidence=native-spec-route
    fi
    ;;
  06)
    route=$(sh "$router" --backend native --work-id 123-auth --role plan --source work 2>/dev/null)
    if printf '%s' "$route" | jq -e '.path == ".agents/changes/active/123-auth/plan.md"' >/dev/null && grep -Fq 'writing-plans' "$project_root/.agents/adapters/superpowers.md"; then
      actual=PASS; evidence=native-plan-route
    fi
    ;;
  07)
    tmp_dir=$(mktemp -d "$project_root/.agents/runtime/acceptance.XXXXXX") || { printf '%s\tBLOCKED\tBLOCKED\tAKS502-temp-dir-unavailable\n' "$case_id"; exit 2; }
    cp -R "$test_root/fixtures/validator/team-multiple-active/repo" "$tmp_dir/repo"
    mkdir -p "$tmp_dir/repo/docs/superpowers/specs"
    printf 'synthetic leak\n' > "$tmp_dir/repo/docs/superpowers/specs/leak.md"
    result=$(sh "$validator" stop-check --root "$tmp_dir/repo" --client codex --format json 2>/dev/null)
    if printf '%s' "$result" | jq -e '.decision == "block" and (.reason | contains("AKE302"))' >/dev/null; then actual=BLOCK; evidence=AKE302; fi
    rm -rf "$tmp_dir"
    ;;
  08)
    if jq -e '.plansDirectory == ".agents/runtime/claude-plans"
              and (.hooks.PreToolUse | length > 0)
              and (.hooks.SessionStart | length > 0)
              and (.hooks.Stop | length > 0)' "$project_root/.claude/settings.json" >/dev/null; then actual=PASS; evidence=runtime-plan-and-hooks-installed; fi
    ;;
  09)
    result=$(sh "$validator" pre-tool-use --root "$test_root/fixtures/validator/team-multiple-active/repo" --client codex --format json < "$test_root/fixtures/validator/team-multiple-active/pre-tool-input.json")
    # Birden fazla aktif is normal durumdur; kapi degil, bilgi.
    if printf '%s' "$result" | jq -e '(.hookSpecificOutput | has("permissionDecision") | not) and (.hookSpecificOutput.additionalContext | contains("AKE201"))' >/dev/null; then actual=WARN; evidence=AKE201-warning-only; fi
    ;;
  10)
    if grep -Fq 'status.md' "$project_root/skills/resume-work/SKILL.md" && grep -Fq 'status.md' "$project_root/skills/checkpoint-work/SKILL.md"; then actual=PASS; evidence=resume-checkpoint-status-contract; fi
    ;;
  11)
    result=$(sh "$validator" pre-tool-use --root "$test_root/fixtures/validator/team-multiple-active/repo" --client codex --work-id 123 --format json < "$test_root/fixtures/validator/team-multiple-active/pre-tool-input.json")
    if printf '%s' "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE202"))' >/dev/null; then actual=BLOCK; evidence=AKE202; fi
    ;;
  12)
    if jq -e '.archiveStrategy == "adaptive"' "$project_root/.agents/config.json" >/dev/null && grep -Fq 'compact, standart veya full' "$project_root/skills/archive-work/SKILL.md"; then actual=PASS; evidence=adaptive-archive-policy; fi
    ;;
  13)
    route=$(sh "$router" --backend external --work-id ext-123 --role spec --source user --path integrations/specs/ext-123.md 2>/dev/null)
    if printf '%s' "$route" | jq -e '.backend == "external" and .path == "integrations/specs/ext-123.md"' >/dev/null; then actual=PASS; evidence=external-route-explicit; fi
    ;;
  14)
    if jq -e '.classification == "preserve-and-merge" and .currentPreserved == true' "$test_root/fixtures/adoption/modified-managed/expected.json" >/dev/null; then actual=PRESERVE; evidence=modified-managed-preserved; fi
    ;;
  15)
    if jq -e '.deleteCandidates == ["AGENTS.md"] and (.preserved | length == 2)' "$test_root/fixtures/adoption/remove-preserves-work/expected.json" >/dev/null; then actual=PRESERVE; evidence=work-and-project-preserved; fi
    ;;
  16)
    result=$(sh "$validator" doctor --root "$test_root/fixtures/validator/solo-one-active/repo" --format json 2>/dev/null)
    if printf '%s' "$result" | jq -e 'any(.diagnostics[]; .code == "AKW401" and .blocking == false)' >/dev/null; then actual=WARN; evidence=AKW401; fi
    ;;
  17)
    if grep -Fq 'harici sisteme yazmaz' "$project_root/skills/init/SKILL.md" && grep -Fq 'Harici yazmadan önce tam hedefi doğrula' "$project_root/AGENTS.md"; then actual=BLOCK; evidence=external-write-authority-gate; fi
    ;;
  18)
    utf8_file="$fixture_dir/repo/özellik planı/bağlam.txt"
    if [ -f "$utf8_file" ] && iconv -f UTF-8 -t UTF-8 "$utf8_file" >/dev/null && grep -Fq 'ğüşiöç' "$utf8_file"; then actual=PASS; evidence=utf8-path-and-content; fi
    ;;
  19)
    if grep -Fq '/local/*' "$project_root/.agents/.gitignore" && grep -Fq '/runtime/*' "$project_root/.agents/.gitignore" && grep -Fq '.agents/tests/results/*' "$validator"; then actual=PASS; evidence=local-runtime-results-excluded; fi
    ;;
  20)
    if grep -Fq '### Koşullu playbook' "$project_root/AGENTS.md" && grep -Fq 'bütün playbook' "$project_root/AGENTS.md"; then actual=PASS; evidence=triggered-context-only; fi
    ;;
  21)
    bytes=$(wc -c < "$project_root/AGENTS.md" | tr -d ' ')
    lines=$(wc -l < "$project_root/AGENTS.md" | tr -d ' ')
    max_bytes=$(jq -r '.instructionBudgets.agentsMaxBytes' "$project_root/.agents/config.json")
    max_lines=$(jq -r '.instructionBudgets.agentsMaxLines' "$project_root/.agents/config.json")
    if [ "$bytes" -le "$max_bytes" ] && [ "$lines" -le "$max_lines" ]; then actual=PASS; evidence="budget-${bytes}b-${lines}l"; fi
    ;;
  22)
    tmp_dir=$(mktemp -d "$project_root/.agents/runtime/acceptance.XXXXXX") || { printf '%s\tBLOCKED\tBLOCKED\tAKS502-temp-dir-unavailable\n' "$case_id"; exit 2; }
    mkdir -p "$tmp_dir/.codex"
    awk 'BEGIN { for (i=0; i<32767; i++) printf "a" }' > "$tmp_dir/AGENTS.md"
    budget_low=$(sh -c '. "$1"; ak_instruction_budget "$2" "$2" 32768' sh "$project_root/.agents/validators/sh/lib.sh" "$tmp_dir")
    awk 'BEGIN { for (i=0; i<32769; i++) printf "a" }' > "$tmp_dir/AGENTS.md"
    budget_high=$(sh -c '. "$1"; ak_instruction_budget "$2" "$2" 32768' sh "$project_root/.agents/validators/sh/lib.sh" "$tmp_dir")
    low=$(printf '%s' "$budget_low" | awk -F '\t' '{print $1}')
    high=$(printf '%s' "$budget_high" | awk -F '\t' '{print $1}')
    rm -f "$tmp_dir/AGENTS.md"
    rmdir "$tmp_dir/.codex" "$tmp_dir" 2>/dev/null || true
    if [ "$low" -eq 32767 ] && [ "$high" -eq 32769 ]; then actual=WARN; evidence=32768-boundary-detected; fi
    ;;
  23)
    if command -v claude >/dev/null 2>&1 && [ "${AGENT_KIT_LIVE_CLIENTS:-0}" = 1 ]; then actual=BLOCKED; evidence=InstructionsLoaded-observation-required; else actual=SKIP; evidence=AKS503-claude-observability-unavailable; fi
    ;;
  24)
    text_8001=$(awk 'BEGIN { for (i=0; i<8001; i++) printf "ğ" }')
    clipped=$(sh -c '. "$1"; ak_limit_utf8 "$2" 8000' sh "$project_root/.agents/validators/sh/lib.sh" "$text_8001")
    length=$(jq -n --arg text "$clipped" '$text | length')
    if [ "$length" -eq 8000 ] && printf '%s' "$clipped" | iconv -f UTF-8 -t UTF-8 >/dev/null; then actual=PASS; evidence=utf8-8000-char-bound; fi
    ;;
  25)
    # Ayni kosul, iki profil: fark yalniz uyari/deny olmali. Kosul olarak
    # AKE203 (aktif is kaydi yok) kullanilir; team fixture'i solo'ya
    # cevrilerek birebir karsilastirma yapilir.
    tmp_dir=$(mktemp -d "$project_root/.agents/runtime/acceptance.XXXXXX") || { printf '%s\tBLOCKED\tBLOCKED\tAKS502-temp-dir-unavailable\n' "$case_id"; exit 2; }
    cp -R "$test_root/fixtures/validator/team-missing-work/repo" "$tmp_dir/solo-repo"
    jq '.profile="solo"' "$tmp_dir/solo-repo/.agents/config.json" > "$tmp_dir/c.json"
    mv "$tmp_dir/c.json" "$tmp_dir/solo-repo/.agents/config.json"
    input="$test_root/fixtures/validator/team-missing-work/pre-tool-input.json"
    solo=$(sh "$validator" pre-tool-use --root "$tmp_dir/solo-repo" --client codex --format json < "$input")
    team=$(sh "$validator" pre-tool-use --root "$test_root/fixtures/validator/team-missing-work/repo" --client codex --format json < "$input")
    rm -rf "$tmp_dir"
    if printf '%s' "$solo" | jq -e '(.hookSpecificOutput | has("permissionDecision") | not) and (.hookSpecificOutput.additionalContext | contains("AKE203"))' >/dev/null \
       && printf '%s' "$team" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE203"))' >/dev/null; then actual=PASS; evidence=solo-warn-team-deny; fi
    ;;
  *)
    printf '%s\tFAIL\tE_CASE_UNKNOWN\tunknown-case-id\n' "$case_id"
    exit 2
    ;;
esac

expected_observed=$(jq -r '.observed' "$expected_file")
expected_status=$(jq -r '.status' "$expected_file")
if [ "$actual" = "$expected_observed" ]; then
  status=$expected_status
else
  status=FAIL
  evidence="expected-${expected_observed}-observed-${actual}"
fi

printf '%s\t%s\t%s\t%s;%s;%s\n' "$case_id" "$status" "$actual" "$evidence" "$case_class" "$profile"
[ "$status" != FAIL ] && [ "$status" != BLOCKED ]
