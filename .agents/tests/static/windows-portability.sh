#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"
failed=0

while IFS= read -r file; do
  [ -n "$file" ] || continue
  prefix=$(od -An -tx1 -N3 "$file" | tr -d ' \n')
  if [ "$prefix" != efbbbf ]; then
    printf 'E_POWERSHELL_UTF8_BOM %s\n' "$file" >&2
    failed=1
  fi
  if ! iconv -f UTF-8 -t UTF-8 "$file" >/dev/null; then
    printf 'E_POWERSHELL_UTF8_INVALID %s\n' "$file" >&2
    failed=1
  fi
done <<EOF
$(find . -type f \( -name '*.ps1' -o -name '*.psm1' \) -print | LC_ALL=C sort)
EOF

if grep -En '@\(\$diagnostics\)' .agents/validators/ps/agent-kit.ps1 >/dev/null 2>&1; then
  printf 'E_PS51_DIRECT_GENERIC_LIST_ARRAY\n' >&2
  failed=1
fi
if grep -En '\$CodexDocLimit\.HasValue' .agents/validators/ps/agent-kit.ps1 >/dev/null 2>&1; then
  printf 'E_PS51_NULLABLE_HASVALUE\n' >&2
  failed=1
fi
# Windows PowerShell 5.1 stdout'u varsayilan olarak konsol kod sayfasiyla yazar.
# UTF-8 disi kod sayfasinda Turkce karakterler bozulur ve hook ciktisindaki kural
# metni ajana bozuk ulasir. Cikti kodlamasi acikca sabitlenmis olmali.
if ! grep -Fq '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8' .agents/validators/ps/agent-kit.ps1; then
  printf 'E_PS51_OUTPUT_ENCODING
' >&2
  exit 2
fi

if ! grep -Fq "\$PSBoundParameters.ContainsKey('Cwd')" .agents/validators/ps/agent-kit.ps1; then
  printf 'E_PS51_DEFAULT_CWD_ROOT\n' >&2
  failed=1
fi
if grep -En '\$arguments[[:space:]]*=[[:space:]]*@\(' .agents/tests/lib/RunCase.psm1 >/dev/null 2>&1; then
  printf 'E_PS51_POSITIONAL_ARRAY_SPLATTING\n' >&2
  failed=1
fi

runtime="$root/.agents/runtime"
temp_root=$(mktemp -d "$runtime/windows-portability.XXXXXX")
cleanup() {
  case "$temp_root" in
    "$runtime"/windows-portability.*) [ ! -d "$temp_root" ] || rm -rf -- "$temp_root" ;;
    *) printf 'W_PORTABILITY_CLEANUP_SKIPPED %s\n' "$temp_root" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

repo="$temp_root/repo"
mkdir -p "$repo/.agents/validators/sh" "$repo/.agents/runtime"
cp .agents/validators/sh/agent-kit.sh .agents/validators/sh/lib.sh "$repo/.agents/validators/sh/"
cp .agents/config.json "$repo/.agents/config.json"
printf '# CRLF manifest fixture\n' > "$repo/AGENTS.md"
sh "$repo/.agents/validators/sh/agent-kit.sh" manifest --root "$repo" --write --generated-at '2026-08-02T00:00:00Z' >/dev/null

real_jq=$(command -v jq)
fake_bin="$temp_root/fake-bin"
mkdir "$fake_bin"
cat > "$fake_bin/jq" <<'EOF'
#!/bin/sh
set -eu
output=$("$AGENT_KIT_REAL_JQ" "$@")
printf '%s\n' "$output" | sed 's/$/\r/'
EOF
chmod +x "$fake_bin/jq"

if ! PATH="$fake_bin:$PATH" AGENT_KIT_REAL_JQ="$real_jq" sh "$repo/.agents/validators/sh/agent-kit.sh" manifest --root "$repo" --check >/dev/null 2>"$temp_root/crlf.err"; then
  printf 'E_MANIFEST_CRLF_NORMALIZATION\n' >&2
  failed=1
else
  printf 'changed\n' >> "$repo/AGENTS.md"
  if PATH="$fake_bin:$PATH" AGENT_KIT_REAL_JQ="$real_jq" sh "$repo/.agents/validators/sh/agent-kit.sh" manifest --root "$repo" --check >/dev/null 2>&1; then
    printf 'E_MANIFEST_CRLF_MASKED_REAL_MISMATCH\n' >&2
    failed=1
  fi
fi

[ "$failed" -eq 0 ] || exit 2
printf 'PASS windows-portability\n'
