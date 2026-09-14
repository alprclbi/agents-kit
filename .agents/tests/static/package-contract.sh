#!/bin/sh
set -eu

root=${1:-"$(pwd)"}
cd "$root"

[ -f .agents/tests/package-release.sh ] || { printf 'E_PACKAGE_UNIX_MISSING\n' >&2; exit 2; }
[ -f .agents/tests/package-release.ps1 ] || { printf 'E_PACKAGE_WINDOWS_MISSING\n' >&2; exit 2; }
sh -n .agents/tests/package-release.sh

for phrase in E_OUTPUT_INSIDE_SOURCE E_RELEASE_TARGET 'unzip -t' 'manifest --root' 'sha256'; do
  grep -Fq "$phrase" .agents/tests/package-release.sh || { printf 'E_PACKAGE_UNIX_CONTRACT %s\n' "$phrase" >&2; exit 2; }
done
for phrase in E_OUTPUT_INSIDE_SOURCE Assert-ReleaseChild Compress-Archive Expand-Archive Get-FileHash E_OUTPUT_COPY_HASH; do
  grep -Fq "$phrase" .agents/tests/package-release.ps1 || { printf 'E_PACKAGE_WINDOWS_CONTRACT %s\n' "$phrase" >&2; exit 2; }
done

grep -Fq '.agents/changes/active' .agents/tests/package-release.sh
grep -Fq '.agents/tests/results' .agents/tests/package-release.sh
grep -Fq 'README.md' .agents/tests/package-release.sh
grep -Fq '.gitignore' .agents/tests/package-release.sh

version=$(tr -d '\r\n' < .agents/VERSION)
[ "$version" = "$(jq -r '.kitVersion' .agents/config.json)" ] || { printf 'E_PACKAGE_VERSION_CONFIG\n' >&2; exit 2; }

runtime="$root/.agents/runtime"
temp_root=$(mktemp -d "$runtime/package-contract.XXXXXX")
cleanup() {
  case "$temp_root" in
    "$runtime"/package-contract.*) [ ! -d "$temp_root" ] || rm -rf -- "$temp_root" ;;
    *) printf 'W_PACKAGE_CONTRACT_CLEANUP_SKIPPED %s\n' "$temp_root" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM
repo="$temp_root/repo"
mkdir -p "$repo/.agents/validators/sh" "$repo/.agents/runtime"
cp .agents/validators/sh/agent-kit.sh .agents/validators/sh/lib.sh "$repo/.agents/validators/sh/"
cp .agents/config.json "$repo/.agents/config.json"
printf '9.9.9\n' > "$repo/.agents/VERSION"
jq '.kitVersion = "9.9.9"' "$repo/.agents/config.json" > "$repo/.agents/config.json.next"
mv "$repo/.agents/config.json.next" "$repo/.agents/config.json"
printf '# Package version fixture\n' > "$repo/AGENTS.md"
sh "$repo/.agents/validators/sh/agent-kit.sh" manifest --root "$repo" --write --generated-at '2026-08-02T00:00:00Z' >/dev/null
jq -e '.kitVersion == "9.9.9"' "$repo/.agents/manifest.json" >/dev/null || { printf 'E_MANIFEST_DYNAMIC_KIT_VERSION\n' >&2; exit 2; }

printf 'PASS package-contract\n'
