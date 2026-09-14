#!/bin/sh
set -eu

package_root=${1:-$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)}
output_zip=${2:-$(dirname -- "$package_root")/agents-kit.zip}
package_root=$(CDPATH= cd -- "$package_root" && pwd -P)
output_parent=$(CDPATH= cd -- "$(dirname -- "$output_zip")" && pwd -P)
output_zip="$output_parent/$(basename -- "$output_zip")"

case "$output_zip" in
  "$package_root"|"$package_root"/*) printf 'E_OUTPUT_INSIDE_SOURCE %s\n' "$output_zip" >&2; exit 2 ;;
esac
for tool in mktemp cp mv; do
  command -v "$tool" >/dev/null 2>&1 || { printf 'E_PACKAGE_TOOL_MISSING %s\n' "$tool" >&2; exit 3; }
done

# ZIP uretimi: Unix-te `zip`, yoksa Python zipfile.
# Git Bash `zip` ile gelmiyor; geri dusus olmadan kit kendi Windows
# destegini paketleyemiyordu (2026-09-08 bulgusu).
#
# Denenip REDDEDILENLER:
#  - PowerShell Compress-Archive: girdi yollarini TERS BOLU ile yaziyor,
#    uretilen ZIP Linux/macOS-ta bozuk aciliyor.
#  - Windows bsdtar: UTF-8 dosya adlarini kaybediyor; kitin kendi
#    18-cross-platform-utf8-paths fixture-i bunu yakaladi.
#    `--options zip:encoding=UTF-8` desteklenmiyor.
# Python zipfile ileri bolu yazar ve ASCII disi adlarda UTF-8 bayragini
# (bit 11) kurar; ikisi de tasinabilirlik icin gerekli.
if command -v zip >/dev/null 2>&1; then
  make_zip() { zip -X -q -r "$1" "$2"; }
  test_zip() { unzip -t "$1" >/dev/null; }
  extract_zip() { unzip -q "$1" -d "$2"; }
  zip_backend=zip
  command -v unzip >/dev/null 2>&1     || { printf 'E_PACKAGE_TOOL_MISSING unzip\n' >&2; exit 3; }
else
  # Adayi CALISTIRARAK sec: Windows-ta `python` Microsoft Store kisayoluna
  # dusebiliyor ve command -v onu gercek yorumlayici saniyor (2026-09-08).
  py_exe=''
  for cand in python3 python py; do
    cand_path=$(command -v "$cand" 2>/dev/null) || continue
    "$cand_path" -c 'import zipfile,sys; sys.exit(0)' >/dev/null 2>&1 || continue
    py_exe="$cand_path"
    break
  done
  [ -n "$py_exe" ] || { printf 'E_PACKAGE_TOOL_MISSING zip (veya calisan python)\n' >&2; exit 3; }
  make_zip() {
    "$py_exe" -c 'import os,sys,zipfile
dest, base = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(base):
        dirs.sort(); files.sort()
        for f in files:
            full = os.path.join(root, f)
            z.write(full, full.replace(os.sep, "/"))' "$1" "$2"
  }
  # Ac/dogrula da AYNI arka uca baglanir. Git Bash `unzip` Windows-ta
  # UTF-8 bayragini yok sayiyor ve Turkce yollari bozarak aciyor; dogru
  # uretilmis bir ZIP onun yuzunden hatali raporlaniyordu (2026-09-08).
  test_zip() {
    "$py_exe" -c 'import sys,zipfile
z = zipfile.ZipFile(sys.argv[1])
bad = z.testzip()
sys.exit(1 if bad else 0)' "$1"
  }
  extract_zip() {
    "$py_exe" -c 'import sys,zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$1" "$2"
  }
  zip_backend="$(basename "$py_exe")/zipfile"
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  printf 'E_PACKAGE_TOOL_MISSING sha256\n' >&2
  exit 3
fi

release_root=$(mktemp -d "$output_parent/.agent-kit-release.XXXXXX")
release_package="$release_root/agents-kit"
output_tmp=''

cleanup() {
  case "$output_tmp" in
    "$output_parent"/.agents-kit.zip.*) [ ! -f "$output_tmp" ] || rm -- "$output_tmp" ;;
    '') ;;
    *) printf 'W_OUTPUT_CLEANUP_SKIPPED %s\n' "$output_tmp" >&2 ;;
  esac
  case "$release_root:$release_package" in
    "$output_parent"/.agent-kit-release.*:"$release_root"/agents-kit) [ ! -d "$release_root" ] || rm -rf -- "$release_root" ;;
    *) printf 'W_RELEASE_CLEANUP_SKIPPED %s\n' "$release_root" >&2 ;;
  esac
}
trap cleanup EXIT HUP INT TERM

case "$release_package" in
  "$release_root"/agents-kit) ;;
  *) printf 'E_RELEASE_TARGET %s\n' "$release_package" >&2; exit 2 ;;
esac

cp -R -- "$package_root" "$release_package"

assert_release_child() {
  case "$1" in "$release_package"/*) return 0 ;; *) printf 'E_RELEASE_CHILD %s\n' "$1" >&2; return 2 ;; esac
}

clear_except() {
  base=$1
  keep=$2
  assert_release_child "$base"
  [ -d "$base" ] || return 0
  for target in "$base"/* "$base"/.[!.]* "$base"/..?*; do
    [ -e "$target" ] || [ -L "$target" ] || continue
    [ "$(basename -- "$target")" = "$keep" ] && continue
    assert_release_child "$target"
    rm -rf -- "$target"
  done
}

clear_except "$release_package/.agents/changes/active" README.md
clear_except "$release_package/.agents/changes/archive" README.md
clear_except "$release_package/.agents/local" README.md
clear_except "$release_package/.agents/runtime" README.md
clear_except "$release_package/.agents/tests/results" .gitignore
clear_except "$release_package/.agents/evals/results" .gitignore

logs_path="$release_package/.agents/logs"
assert_release_child "$logs_path"
[ ! -e "$logs_path" ] || rm -rf -- "$logs_path"
# Git deposu dagitim paketine GIRMEZ. 2026-09-08: git init sonrasi ilk
# paketleme .git altindaki 429 dosyayi da ZIP'e koydu; paket 242 KB'den
# 697 KB'ye cikti ve gelistirme gecmisi kullaniciya dagitilmis oldu.
git_path="$release_package/.git"
assert_release_child "$git_path"
[ ! -e "$git_path" ] || rm -rf -- "$git_path"
for extra in .gitignore.bak .git-rewrite; do
  extra_path="$release_package/$extra"
  assert_release_child "$extra_path"
  [ ! -e "$extra_path" ] || rm -rf -- "$extra_path"
done

# GitHub depo yonetim dosyalari dagitim paketine GIRMEZ: issue ve PR
# sablonlari GitHub davranisini degistirir, kiti benimseyen kisinin
# deposunda kitin sablonlari cikmamali.
for repo_only in .github/ISSUE_TEMPLATE .github/PULL_REQUEST_TEMPLATE.md CODE_OF_CONDUCT.md; do
  repo_only_path="$release_package/$repo_only"
  assert_release_child "$repo_only_path"
  [ ! -e "$repo_only_path" ] || rm -rf -- "$repo_only_path"
done

nested_zip="$release_package/agents-kit.zip"
assert_release_child "$nested_zip"
[ ! -e "$nested_zip" ] || rm -- "$nested_zip"

# Paket icinde TUM test paketi kosar, alt kume degil. 2026-09-10:
# alt kume kosuyordu ve style-preferences paket icinde DUSUYORDU --
# tercih dosyasi pakete girmiyor, test ise kullanicinin gercek
# dosyasina bagimliydi. Yani README'nin "sunu calistir" dedigi komut
# indiren kiside hata veriyordu. package-release.ps1 zaten run.ps1
# tamamini kosuyordu; parite acigiydi.
(
  cd "$release_package"
  sh .agents/tests/run.sh
  sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check
)
clear_except "$release_package/.agents/tests/results" .gitignore

temp_zip="$release_root/agents-kit.zip"
(
  cd "$release_root"
  make_zip "$temp_zip" agents-kit
)
test_zip "$temp_zip"

verify_root="$release_root/verify"
mkdir "$verify_root"
extract_zip "$temp_zip" "$verify_root"
(
  cd "$verify_root/agents-kit"
  sh .agents/tests/run.sh
  sh .agents/validators/sh/agent-kit.sh manifest --root "$PWD" --check
)

output_tmp=$(mktemp "$output_parent/.agents-kit.zip.XXXXXX")
cp -- "$temp_zip" "$output_tmp"
[ "$(sha256_file "$temp_zip")" = "$(sha256_file "$output_tmp")" ] || { printf 'E_OUTPUT_COPY_HASH\n' >&2; exit 2; }
test_zip "$output_tmp"
mv -f -- "$output_tmp" "$output_zip"
output_tmp=''

printf 'PASS package-release backend=%s\n' "$zip_backend"
printf 'PASS package-release sha256=%s bytes=%s\n' "$(sha256_file "$output_zip")" "$(wc -c < "$output_zip" | tr -d ' ')"
