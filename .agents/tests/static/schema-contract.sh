#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

schemas='config work manifest router-result diagnostic'
for name in $schemas; do
  path=".agents/schemas/$name.schema.json"
  [ -f "$path" ] || { printf 'E_SCHEMA_MISSING %s\n' "$path" >&2; exit 2; }
done

sh .agents/tests/lib/json-parse.sh .agents/schemas/*.schema.json

if command -v jq >/dev/null 2>&1; then
  for name in $schemas; do
    path=".agents/schemas/$name.schema.json"
    jq -e '."$schema" == "https://json-schema.org/draft/2020-12/schema"' "$path" >/dev/null
    jq -e '.additionalProperties == false' "$path" >/dev/null
  done
  jq -e '(.required | sort) == (["schemaVersion","kitVersion","language","profile","artifactBackend","instructionBudgets","workTracking","archiveStrategy","adapters"] | sort)' .agents/schemas/config.schema.json >/dev/null
  jq -e '(.required | sort) == (["schemaVersion","id","title","status","profile","profileReason","backend","artifacts","ownership","links","git","documentationImpact","createdAt","updatedAt"] | sort)' .agents/schemas/work.schema.json >/dev/null
  jq -e '(.required | sort) == (["$schema","schemaVersion","kitVersion","generatedAt","compatibility","files"] | sort)' .agents/schemas/manifest.schema.json >/dev/null
  jq -e '(.required | sort) == (["workId","backend","role","path","source","authorityRequired"] | sort)' .agents/schemas/router-result.schema.json >/dev/null
  jq -e '(.required | sort) == (["code","severity","blocking","message","path","remediation"] | sort)' .agents/schemas/diagnostic.schema.json >/dev/null
else
  printf 'E_SCHEMA_SEMANTIC_PARSER jq\n' >&2
  exit 3
fi

contracts='artifact-model work-lifecycle backend-resolution session-bootstrap ownership archive-policy documentation-impact kit-management'
for name in $contracts; do
  path=".agents/contracts/$name.md"
  [ -f "$path" ] || { printf 'E_CONTRACT_MISSING %s\n' "$path" >&2; exit 2; }
  for heading in '## Amaç' '## Girdiler' '## Çıktılar' '## Değişmezler' '## Hata ve Belirsizlik' '## Doğrulama'; do
    grep -Fqx "$heading" "$path" || { printf 'E_CONTRACT_HEADING %s %s\n' "$path" "$heading" >&2; exit 2; }
  done
done

printf 'PASS schema-contract\n'
