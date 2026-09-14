#!/bin/sh
set -eu

[ "$#" -gt 0 ] || { printf 'E_JSON_INPUT_MISSING\n' >&2; exit 2; }

if command -v jq >/dev/null 2>&1; then
  for file do jq -e . "$file" >/dev/null; done
elif command -v python3 >/dev/null 2>&1; then
  for file do python3 -m json.tool "$file" >/dev/null; done
elif command -v node >/dev/null 2>&1; then
  node -e 'const fs=require("fs"); for (const p of process.argv.slice(1)) JSON.parse(fs.readFileSync(p,"utf8"));' "$@"
else
  printf 'E_JSON_PARSER_UNAVAILABLE jq|python3|node\n' >&2
  exit 3
fi
