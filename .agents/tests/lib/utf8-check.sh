#!/bin/sh
set -eu

[ "$#" -gt 0 ] || { printf 'E_UTF8_INPUT_MISSING\n' >&2; exit 2; }

if command -v iconv >/dev/null 2>&1; then
  for file do iconv -f UTF-8 -t UTF-8 "$file" >/dev/null; done
elif command -v python3 >/dev/null 2>&1; then
  python3 -c 'import pathlib,sys; [pathlib.Path(p).read_bytes().decode("utf-8") for p in sys.argv[1:]]' "$@"
elif command -v node >/dev/null 2>&1; then
  node -e 'const fs=require("fs"),d=new TextDecoder("utf-8",{fatal:true}); for(const p of process.argv.slice(1)) d.decode(fs.readFileSync(p));' "$@"
else
  printf 'E_UTF8_CHECKER_UNAVAILABLE iconv|python3|node\n' >&2
  exit 3
fi
