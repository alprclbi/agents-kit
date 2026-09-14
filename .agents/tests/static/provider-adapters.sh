#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

[ -f .codex/hooks.json ] || { printf 'E_CODEX_HOOKS_MISSING\n' >&2; exit 2; }
[ -f .agents/adapters/codex.md ] || { printf 'E_CODEX_ADAPTER_MISSING\n' >&2; exit 2; }
[ -f .agents/adapters/claude.md ] || { printf 'E_CLAUDE_ADAPTER_MISSING\n' >&2; exit 2; }
[ -f .agents/adapters/claude/hooks.bash.json ] || { printf 'E_CLAUDE_BASH_HOOKS_MISSING\n' >&2; exit 2; }
[ -f .agents/adapters/claude/hooks.powershell.json ] || { printf 'E_CLAUDE_POWERSHELL_HOOKS_MISSING\n' >&2; exit 2; }

jq -e '
  (.hooks.SessionStart | length > 0) and
  (.hooks.PreToolUse | length > 0) and
  (.hooks.Stop | length > 0) and
  ([.hooks[][]?.hooks[]? | select(.type == "command")]
    | length > 0 and all(.[]; (.command | type == "string" and length > 0) and (.commandWindows | type == "string" and length > 0)))
' .codex/hooks.json >/dev/null || { printf 'E_CODEX_HOOK_CONTRACT\n' >&2; exit 2; }

# Kit kendi deposunda hook'lari KURULU tutar. Gerekce: is kaydi kapilari
# (AKE201-AKE203) ve oturum baglami yalniz hook ile mekanik olarak
# zorlanabilir; metinde kalan kural baglam doldukca curur.
jq -e '
  (.hooks.SessionStart | length > 0) and
  (.hooks.PreToolUse | length > 0) and
  (.hooks.Stop | length > 0) and
  ([.hooks[][]?.hooks[]? | select(.type == "command") | .shell]
    | length > 0 and (all(.[]; . == "bash") or all(.[]; . == "powershell")))
' .claude/settings.json >/dev/null || { printf 'E_CLAUDE_HOOKS_NOT_INSTALLED\n' >&2; exit 2; }
jq -e '.hooks.SessionStart and .hooks.PreToolUse and .hooks.Stop and ([.. | objects | select(has("shell")) | .shell] | all(. == "bash"))' .agents/adapters/claude/hooks.bash.json >/dev/null || { printf 'E_CLAUDE_BASH_HOOK_CONTRACT\n' >&2; exit 2; }
jq -e '.hooks.SessionStart and .hooks.PreToolUse and .hooks.Stop and ([.. | objects | select(has("shell")) | .shell] | all(. == "powershell"))' .agents/adapters/claude/hooks.powershell.json >/dev/null || { printf 'E_CLAUDE_POWERSHELL_HOOK_CONTRACT\n' >&2; exit 2; }
grep -Fq '${CLAUDE_PROJECT_DIR}' .agents/adapters/claude/hooks.bash.json || { printf 'E_CLAUDE_BASH_ROOT\n' >&2; exit 2; }
grep -Fq '$env:CLAUDE_PROJECT_DIR' .agents/adapters/claude/hooks.powershell.json || { printf 'E_CLAUDE_POWERSHELL_ROOT\n' >&2; exit 2; }
! grep -Fq 'git rev-parse' .agents/adapters/claude/hooks.bash.json .agents/adapters/claude/hooks.powershell.json || { printf 'E_CLAUDE_GIT_DEPENDENCY\n' >&2; exit 2; }

# Codex hook KOMUTLARI gercekten calistirilir. Codex binary'si olmadan
# istemcinin .codex/hooks.json dosyasini KESFEDIP GUVENDIGI dogrulanamaz,
# ama komutlarin kendisi dogrulanir: kok cozumu, cikti sozlesmesi ve karar.
codex_session_command=$(jq -r '.hooks.SessionStart[0].hooks[0].command' .codex/hooks.json)
codex_session_output=$(printf '%s' '{"source":"startup"}' | /bin/sh -c "$codex_session_command") || { printf 'E_CODEX_SESSION_COMMAND\n' >&2; exit 2; }
printf '%s' "$codex_session_output" | grep -Fq 'Agents Kit' || { printf 'E_CODEX_SESSION_CONTEXT\n' >&2; exit 2; }

# PreToolUse ve Stop komutlari da calisir ve gecerli JSON uretir.
codex_pre_command=$(jq -r '.hooks.PreToolUse[0].hooks[0].command' .codex/hooks.json)
codex_pre_output=$(printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | /bin/sh -c "$codex_pre_command") || { printf 'E_CODEX_PRE_COMMAND\n' >&2; exit 2; }
printf '%s' "$codex_pre_output" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' >/dev/null || { printf 'E_CODEX_PRE_CONTRACT %s\n' "$codex_pre_output" >&2; exit 2; }
codex_stop_command=$(jq -r '.hooks.Stop[0].hooks[0].command' .codex/hooks.json)
codex_stop_output=$(printf '%s' '{}' | /bin/sh -c "$codex_stop_command") || { printf 'E_CODEX_STOP_COMMAND\n' >&2; exit 2; }
printf '%s' "$codex_stop_output" | jq -e 'type == "object"' >/dev/null || { printf 'E_CODEX_STOP_CONTRACT %s\n' "$codex_stop_output" >&2; exit 2; }

# Git DISINDA kok cozumu ve gercek deny karari. Fixture depo disina
# kopyalanir; git rev-parse orada basarisiz olur ve komut isaretci
# aramasina duser. Bu yol yalnizca boyle test edilebilir.
codex_tmp=$(mktemp -d)
case "$codex_tmp" in /*) ;; *) printf 'E_CODEX_TMP %s\n' "$codex_tmp" >&2; exit 2 ;; esac
cleanup_codex() { case "$codex_tmp" in /*/*) rm -rf -- "$codex_tmp" ;; esac; }
trap cleanup_codex EXIT HUP INT TERM
cp -R .agents/tests/fixtures/validator/team-missing-work/repo "$codex_tmp/repo"
mkdir -p "$codex_tmp/repo/.agents/validators"
cp -R .agents/validators/sh "$codex_tmp/repo/.agents/validators/sh"
codex_deny=$(cd "$codex_tmp/repo" && printf '%s' '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}' | /bin/sh -c "$codex_pre_command") || { printf 'E_CODEX_NONGIT_COMMAND\n' >&2; exit 2; }
printf '%s' "$codex_deny" | jq -e '.hookSpecificOutput.permissionDecision == "deny" and (.hookSpecificOutput.permissionDecisionReason | contains("AKE203"))' >/dev/null \
  || { printf 'E_CODEX_NONGIT_DECISION %s\n' "$codex_deny" >&2; exit 2; }
cleanup_codex
trap - EXIT HUP INT TERM

printf '%s' "$(jq -r '.hooks.SessionStart[0].hooks[0].commandWindows' .codex/hooks.json)" | grep -Fq 'AGENTS.md' || { printf 'E_CODEX_WINDOWS_ROOT_FALLBACK\n' >&2; exit 2; }

grep -Fq 'Git deposu gerektirmez' .agents/adapters/claude.md || { printf 'E_CLAUDE_GIT_INDEPENDENCE_DOC\n' >&2; exit 2; }
grep -Fq 'Claude Code içinde `/hooks`' AGENT-KIT-START.md || { printf 'E_CLAUDE_HOOK_ACTIVATION_DOC\n' >&2; exit 2; }

for skill in artifact-router start-work resume-work checkpoint-work close-work archive-work kit-doctor; do
  # Kaynak kit deposunda skills/ altinda; kurulu projede .agents/skills/
  # altinda. Stub KURULU yolu gosterir, cunku kullaniciya o gider.
  wrapper=".claude/skills/$skill/SKILL.md"
  canonical="skills/$skill/SKILL.md"
  installed=".agents/skills/$skill/SKILL.md"
  [ -f "$canonical" ] || { printf 'E_CANONICAL_SKILL_MISSING %s\n' "$skill" >&2; exit 2; }
  [ -f "$wrapper" ] || { printf 'E_CLAUDE_SKILL_MISSING %s\n' "$skill" >&2; exit 2; }
  grep -Fq "\`$installed\` dosyasını tamamen oku ve uygula." "$wrapper" || { printf 'E_CLAUDE_SKILL_TARGET %s\n' "$skill" >&2; exit 2; }
  grep -Fq 'Bu adaptör ek commit, branch, worktree, alt ajan veya harici yazma yetkisi vermez.' "$wrapper" || { printf 'E_CLAUDE_SKILL_AUTHORITY %s\n' "$skill" >&2; exit 2; }
  [ "$(grep -Fc 'skills/' "$wrapper")" -eq 1 ] || { printf 'E_CLAUDE_SKILL_NOT_THIN %s\n' "$skill" >&2; exit 2; }
done

printf 'PASS provider-adapters\n'
