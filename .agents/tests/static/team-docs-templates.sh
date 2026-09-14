#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

for name in feature-issue.md bug-issue.md pull-request.md CODEOWNERS.example ruleset.example.json agent-kit-validation.example.yml; do
  [ -f ".agents/templates/github/$name" ] || { printf 'E_TEMPLATE_MISSING %s\n' "$name" >&2; exit 2; }
done
for name in adr.md runbook.md docs-impact.md; do
  [ -f ".agents/templates/documentation/$name" ] || { printf 'E_DOCUMENTATION_TEMPLATE_MISSING %s\n' "$name" >&2; exit 2; }
done
for name in project.md preferences.md CLAUDE.local.md.example; do
  [ -f ".agents/templates/project/$name" ] || { printf 'E_PROJECT_TEMPLATE_MISSING %s\n' "$name" >&2; exit 2; }
done

jq -e '.enforcement == "disabled" and .target == "branch" and .bypass_actors == []' .agents/templates/github/ruleset.example.json >/dev/null
grep -Fq 'Açık yetki olmadan uygulanmaz' .agents/templates/github/CODEOWNERS.example
grep -Fq '{{OWNER}}' .agents/templates/github/CODEOWNERS.example
grep -Fq 'work-id' .agents/templates/github/pull-request.md
grep -Fq 'Doğrulama' .agents/templates/github/pull-request.md
grep -Fq '{{PINNED_SHA}}' .agents/templates/github/agent-kit-validation.example.yml
grep -Fq 'contents: read' .agents/templates/github/agent-kit-validation.example.yml
grep -Fq 'none|possible|required|generated' .agents/templates/documentation/docs-impact.md
grep -Fq '@.agents/local/preferences.md' .agents/templates/project/CLAUDE.local.md.example

[ ! -e .agents/templates/project-overlay.example.md ] || { printf 'E_LEGACY_PROJECT_TEMPLATE\n' >&2; exit 2; }
[ ! -e .agents/templates/evidence-review.md ] || { printf 'E_LEGACY_EVIDENCE_TEMPLATE\n' >&2; exit 2; }

if grep -rEn '^[[:space:]]*-[[:space:]]*\[[xX]\]|status:[[:space:]]*(passed|success)|result:[[:space:]]*(passed|success)' .agents/templates/github .agents/templates/documentation >/dev/null 2>&1; then
  printf 'E_PREFILLED_SUCCESS_CLAIM\n' >&2
  exit 2
fi

printf 'PASS team-docs-templates\n'
