#!/bin/sh
set -eu

root=${1:-"$(git rev-parse --show-toplevel 2>/dev/null || pwd)"}
failed=0

while IFS= read -r path; do
  [ -z "$path" ] && continue
  if [ ! -f "$root/$path" ]; then
    printf 'E_LAYOUT_MISSING %s\n' "$path" >&2
    failed=1
  fi
done <<'PATHS'
AGENT-KIT-START.md
AGENTS.md
CLAUDE.md
.agents/README.md
.agents/VERSION
.agents/CHANGELOG.md
.agents/NOTICE.md
.agents/config.json
.agents/project.md
.agents/preferences.example.md
.agents/changes/active/README.md
.agents/changes/archive/README.md
.agents/specs/README.md
.agents/roadmaps/README.md
.agents/local/README.md
.agents/runtime/README.md
.agents/tests/lib/json-parse.sh
.agents/tests/lib/utf8-check.sh
PATHS

[ "$failed" -eq 0 ] || exit 2
exit 0
