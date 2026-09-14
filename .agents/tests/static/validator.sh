#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"
entry=.agents/validators/sh/agent-kit.sh
[ -f "$entry" ] || { printf 'E_VALIDATOR_ENTRYPOINT_MISSING\n' >&2; exit 2; }
[ -f .agents/validators/ps/AgentKit.psm1 ] || { printf 'E_POWERSHELL_MODULE_MISSING\n' >&2; exit 2; }
[ -f .agents/validators/ps/agent-kit.ps1 ] || { printf 'E_POWERSHELL_ENTRYPOINT_MISSING\n' >&2; exit 2; }
for function_name in Find-AgentKitRoot Read-AgentKitJson Resolve-AgentKitWork Test-AgentKitOwnership New-AgentKitDiagnostic Limit-AgentKitContext Get-AgentKitClaudeHookSource Get-AgentKitCodexHookSource; do
  grep -Fq "function $function_name" .agents/validators/ps/AgentKit.psm1 || { printf 'E_POWERSHELL_FUNCTION %s\n' "$function_name" >&2; exit 2; }
done
grep -Fq "ValidateSet('doctor', 'session-context', 'pre-tool-use', 'stop-check', 'manifest')" .agents/validators/ps/agent-kit.ps1 || { printf 'E_POWERSHELL_DISPATCHER\n' >&2; exit 2; }
! grep -Eq -- '-mindepth|-maxdepth' .agents/validators/sh/lib.sh || { printf 'E_NON_POSIX_FIND_DEPTH\n' >&2; exit 2; }

solo=.agents/tests/fixtures/validator/solo-one-active/repo
team=.agents/tests/fixtures/validator/team-multiple-active/repo
high=.agents/tests/fixtures/validator/team-missing-work/repo

# AKW401 iddiasi proje disindaki hook kaynaklarina da bakiyor; test tek
# basina kosarken de bos ve yalitilmis bir yapilandirma dizini gormeli.
isolated_home=$(mktemp -d "$root/.agents/runtime/validator-home.XXXXXX")
cleanup_isolated_home() { rm -rf -- "$isolated_home"; }
trap cleanup_isolated_home EXIT HUP INT TERM
CLAUDE_CONFIG_DIR=$isolated_home
CODEX_HOME=$isolated_home
export CLAUDE_CONFIG_DIR CODEX_HOME

doctor=$(sh "$entry" doctor --root "$solo" --client codex --format json)
printf '%s' "$doctor" | jq -e '
  .client == "codex" and
  .profile == "solo" and
  .resolvedWorkId == "123" and
  .blocking == false and
  .codexDocLimit == 32768 and
  .limitSource == "reference" and
  any(.diagnostics[]; .code == "AKW110") and
  any(.diagnostics[]; .code == "AKW401" and .path == ".codex/hooks.json")
' >/dev/null

claude_doctor=$(sh "$entry" doctor --root "$solo" --client claude --format json)
printf '%s' "$claude_doctor" | jq -e '
  .client == "claude" and
  .profile == "solo" and
  .resolvedWorkId == "123" and
  .blocking == false and
  .codexDocLimit == null and
  .limitSource == "not-applicable" and
  (all(.diagnostics[]; .code != "AKW110")) and
  (all(.diagnostics[]; .path != ".codex/hooks.json")) and
  any(.diagnostics[]; .code == "AKW401" and .path == ".claude/settings.json")
' >/dev/null

context=$(printf '%s' '{"source":"resume","cwd":"fixture"}' | sh "$entry" session-context --root "$solo" --cwd "$solo" --client codex --source hook --format json)
printf '%s' "$context" | jq -e '.resolvedWorkId == "123" and .source == "resume" and (.context | length <= 8000)' >/dev/null
! printf '%s' "$context" | grep -Fq 'SYNTHETIC_NON_SECRET_SENTINEL'
printf '%s' "$context" | iconv -f UTF-8 -t UTF-8 >/dev/null

team_result=$(sh "$entry" pre-tool-use --root .agents/tests/fixtures/validator/team-missing-work/repo --client codex --format json < .agents/tests/fixtures/validator/team-missing-work/pre-tool-input.json)
printf '%s' "$team_result" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE203"))' >/dev/null

readonly_result=$(sh "$entry" pre-tool-use --root "$team" --client codex --format json < .agents/tests/fixtures/validator/team-multiple-active/read-only-input.json)
printf '%s' "$readonly_result" | jq -e '(has("permissionDecision") | not) and .hookSpecificOutput.hookEventName == "PreToolUse" and (.hookSpecificOutput | has("permissionDecision") | not)' >/dev/null

ownership_result=$(sh "$entry" pre-tool-use --root "$team" --client codex --work-id 123 --format json < .agents/tests/fixtures/validator/team-multiple-active/pre-tool-input.json)
printf '%s' "$ownership_result" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE202"))' >/dev/null

high_result=$(sh "$entry" pre-tool-use --root "$high" --client claude --format json < .agents/tests/fixtures/validator/team-missing-work/pre-tool-input.json)
printf '%s' "$high_result" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE203"))' >/dev/null

stop_result=$(printf '%s' '{"hook_event_name":"Stop"}' | sh "$entry" stop-check --root "$solo" --client codex --format json)
printf '%s' "$stop_result" | jq -e '.continue == true and (has("blocking") | not)' >/dev/null

if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoProfile -File .agents/validators/ps/agent-kit.ps1 doctor -Root "$solo" -Format json | jq -e '.profile == "solo" and .resolvedWorkId == "123"' >/dev/null
elif command -v powershell >/dev/null 2>&1; then
  powershell -NoProfile -File .agents/validators/ps/agent-kit.ps1 doctor -Root "$solo" -Format json | jq -e '.profile == "solo" and .resolvedWorkId == "123"' >/dev/null
else
  printf 'SKIP AKS501 PowerShell bulunamadı\n'
fi

printf 'PASS validator\n'
