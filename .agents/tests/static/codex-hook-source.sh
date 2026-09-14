#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# CODEX HOOK KAYNAGI SOZLESMESI.
#
# Claude tarafiyla ayni hata sinifi: AKW401 yalniz <proje>/.codex/hooks.json
# dosyasina bakiyordu, oysa Codex plugin'i de hooks/hooks.json tasiyor.
# Plugin ile kurulmus bir projede dosya yoktur ama hook calisir.
#
# Codex'in kayit yeri TOML'dur, JSON degil. Iki kanit kabul edilir:
#   1. <CODEX_HOME>/plugins/cache/<market>/<ad>/<surum>/hooks/hooks.json
#   2. config.toml icindeki [hooks.state."<ad>@<market>:...] kaydi
# Ikisi de yalniz [plugins."<ad>@<market>"] blogu enabled = true ise sayilir.
#
# Test kendi CODEX_HOME degerini kurar; sonuc gelistiricinin makinesinde
# plugin kurulu olup olmamasina gore degismez.

tmp=$(mktemp -d "$root/.agents/runtime/codex-hook-test.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

repo="$tmp/repo"
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$repo"

package="$tmp/home-plugin/plugins/cache/agents-kit/agents-kit/1.2.0"
mkdir -p "$package/hooks"
printf '%s\n' '{"hooks":{"SessionStart":[]}}' > "$package/hooks/hooks.json"

write_config() {
  home_dir=$1
  enabled=$2
  extra=$3
  mkdir -p "$home_dir"
  {
    printf '[marketplaces.agents-kit]\nsource_type = "git"\n\n'
    printf '[plugins."agents-kit@agents-kit"]\nenabled = %s\n\n' "$enabled"
    printf '%s' "$extra"
  } > "$home_dir/config.toml"
}

warns() {
  CODEX_HOME=$1 sh "$validator" doctor --root "$repo" --client codex --format json 2>/dev/null \
    | jq -e 'any(.diagnostics[]; .code == "AKW401" and .path == ".codex/hooks.json")' >/dev/null
}

expect_warn() {
  warns "$1" || { printf 'FAIL %s: AKW401 beklendi, cikmadi\n' "$2" >&2; fail=1; }
}

expect_quiet() {
  warns "$1" && { printf 'FAIL %s: AKW401 yanlis uyari\n' "$2" >&2; fail=1; }
  return 0
}

# --- 1. Hicbir kaynak yok --------------------------------------------
mkdir -p "$tmp/home-bos"
expect_warn "$tmp/home-bos" 'kaynak yok'

# --- 2. Etkin plugin, paketinde hook dosyasi -------------------------
write_config "$tmp/home-plugin" true ''
expect_quiet "$tmp/home-plugin" 'etkin plugin paketi'

# --- 3. Plugin kurulu ama etkin degil --------------------------------
mkdir -p "$tmp/home-kapali/plugins/cache/agents-kit/agents-kit/1.2.0/hooks"
printf '%s\n' '{"hooks":{}}' > "$tmp/home-kapali/plugins/cache/agents-kit/agents-kit/1.2.0/hooks/hooks.json"
write_config "$tmp/home-kapali" false ''
expect_warn "$tmp/home-kapali" 'kapali plugin'

# --- 4. Etkin plugin ama ne paket ne hook kaydi ----------------------
write_config "$tmp/home-hooksuz" true ''
expect_warn "$tmp/home-hooksuz" 'kanitsiz etkin plugin'

# --- 5. Paket yok ama Codex hook guvenini kaydetmis ------------------
write_config "$tmp/home-state" true \
  '[hooks.state."agents-kit@agents-kit:hooks/hooks.json:session_start:0:0"]
trusted_hash = "sha256:abc"
'
expect_quiet "$tmp/home-state" 'guvenilen hook kaydi'

# --- 6. Alt bolumdeki enable plugin blogu sayilmamali ----------------
mkdir -p "$tmp/home-altbolum"
{
  printf '[plugins."agents-kit@agents-kit".policy]\nenabled = true\n\n'
  printf '[hooks.state."agents-kit@agents-kit:hooks/hooks.json:stop:0:0"]\ntrusted_hash = "sha256:abc"\n'
} > "$tmp/home-altbolum/config.toml"
expect_warn "$tmp/home-altbolum" 'alt bolum enabled'

# --- 7. Kullanici duzeyi hooks.json ----------------------------------
mkdir -p "$tmp/home-kullanici"
printf '%s\n' '{"hooks":{}}' > "$tmp/home-kullanici/hooks.json"
expect_quiet "$tmp/home-kullanici" 'kullanici hooks.json'

# --- 8. Proje dosyasi (eski davranis korunur) ------------------------
mkdir -p "$repo/.codex"
printf '%s\n' '{"hooks":{}}' > "$repo/.codex/hooks.json"
expect_quiet "$tmp/home-bos" 'proje hooks.json'

[ "$fail" -eq 0 ] || exit 1
printf 'PASS codex-hook-source\n'
