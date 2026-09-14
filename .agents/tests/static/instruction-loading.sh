#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

bytes=$(wc -c < AGENTS.md | tr -d ' ')
lines=$(wc -l < AGENTS.md | tr -d ' ')
[ "$bytes" -le 16384 ] || { printf 'E_AGENTS_MAX_BYTES %s\n' "$bytes" >&2; exit 2; }
[ "$lines" -le 200 ] || { printf 'E_AGENTS_MAX_LINES %s\n' "$lines" >&2; exit 2; }
[ "$bytes" -le 12288 ] || printf 'W_AGENTS_TARGET_BYTES %s\n' "$bytes"
[ "$lines" -le 150 ] || printf 'W_AGENTS_TARGET_LINES %s\n' "$lines"

grep -Fqx '@AGENTS.md' CLAUDE.md || { printf 'E_CLAUDE_IMPORT AGENTS.md\n' >&2; exit 2; }
grep -Fqx '@.agents/config.json' CLAUDE.md || { printf 'E_CLAUDE_IMPORT config.json\n' >&2; exit 2; }
grep -Fqx '@.agents/project.md' CLAUDE.md || { printf 'E_CLAUDE_IMPORT project.md\n' >&2; exit 2; }
! grep -Fq '@.agents/preferences.md' CLAUDE.md || { printf 'E_CLAUDE_LEGACY_IMPORT\n' >&2; exit 2; }
[ ! -e .agents/preferences.md ] || { printf 'E_LEGACY_PREFERENCES_FILE\n' >&2; exit 2; }

[ -f .codex/config.toml ] || { printf 'E_CODEX_CONFIG_MISSING\n' >&2; exit 2; }
! grep -Eq '^[[:space:]]*project_doc_max_bytes[[:space:]]*=' .codex/config.toml
[ -f .claude/settings.json ] || { printf 'E_CLAUDE_SETTINGS_MISSING\n' >&2; exit 2; }
sh .agents/tests/lib/json-parse.sh .claude/settings.json
[ "$(jq -r '.plansDirectory' .claude/settings.json)" = '.agents/runtime/claude-plans' ]

for marker in '.agents/config.json' '.agents/project.md' '.agents/local/preferences.md' 'work.json' 'status.md' 'birden fazla' 'Arşivleri' 'toplu okuma'; do
  grep -Fiq "$marker" AGENTS.md || { printf 'E_AGENTS_BOOTSTRAP %s\n' "$marker" >&2; exit 2; }
done

grep -Fq 'makine-yerel yardımcı önbellek' .agents/contracts/session-bootstrap.md || { printf 'E_AUTO_MEMORY_CACHE_BOUNDARY\n' >&2; exit 2; }
grep -Fq 'kanonik takım kaydı değildir' .agents/adapters/claude.md || { printf 'E_AUTO_MEMORY_CANONICAL_BOUNDARY\n' >&2; exit 2; }

printf 'PASS instruction-loading bytes=%s lines=%s\n' "$bytes" "$lines"
