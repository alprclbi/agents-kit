#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# CLAUDE HOOK KAYNAGI SOZLESMESI.
#
# AKW401 "hook yok" demeden once hook'un gelebilecegi her kaynak taranir:
# proje ayari, proje yerel ayari, kullanici ayari ve kurulu+etkin plugin
# paketi. Kit 1.2.0 ile hook'lar plugin ile geliyor; goc edilmis projede
# .claude/settings.json bos kalir ama koruma calisir. Yalniz proje
# dosyasina bakmak o projelerin hepsinde yanlis uyari uretir.
#
# Test kendi CLAUDE_CONFIG_DIR degerini kurar; sonuc gelistiricinin
# makinesinde plugin kurulu olup olmamasina gore degismez.

tmp=$(mktemp -d "$root/.agents/runtime/hook-source-test.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

repo="$tmp/repo"
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$repo"

package="$tmp/paket"
mkdir -p "$package/hooks"
printf '%s\n' '{"hooks":{"SessionStart":[]}}' > "$package/hooks/hooks.json"

hooksuz="$tmp/paket-hooksuz"
mkdir -p "$hooksuz/skills"

write_home() {
  home_dir=$1
  enabled=$2
  install_path=$3
  mkdir -p "$home_dir/plugins"
  printf '{"enabledPlugins":{"agents-kit@agents-kit":%s}}\n' "$enabled" > "$home_dir/settings.json"
  printf '{"version":2,"plugins":{"agents-kit@agents-kit":[{"scope":"user","installPath":"%s","version":"1.2.0"}]}}\n' \
    "$install_path" > "$home_dir/plugins/installed_plugins.json"
}

warns() {
  CLAUDE_CONFIG_DIR=$1 sh "$validator" doctor --root "$repo" --client claude --format json 2>/dev/null \
    | jq -e 'any(.diagnostics[]; .code == "AKW401" and .path == ".claude/settings.json")' >/dev/null
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

# --- 2. Plugin kurulu ve etkin ---------------------------------------
write_home "$tmp/home-plugin" true "$package"
expect_quiet "$tmp/home-plugin" 'etkin plugin'

# --- 3. Plugin kurulu ama etkin degil --------------------------------
write_home "$tmp/home-kapali" false "$package"
expect_warn "$tmp/home-kapali" 'kapali plugin'

# --- 4. Plugin etkin ama paket hook tasimiyor ------------------------
write_home "$tmp/home-hooksuz" true "$hooksuz"
expect_warn "$tmp/home-hooksuz" 'hooksuz paket'

# --- 5. Kullanici ayarinda hook --------------------------------------
mkdir -p "$tmp/home-kullanici"
printf '%s\n' '{"hooks":{"SessionStart":[]}}' > "$tmp/home-kullanici/settings.json"
expect_quiet "$tmp/home-kullanici" 'kullanici ayari'

# --- 6. Proje ayarinda hook (eski davranis korunur) ------------------
mkdir -p "$repo/.claude"
printf '%s\n' '{"hooks":{"SessionStart":[]}}' > "$repo/.claude/settings.json"
expect_quiet "$tmp/home-bos" 'proje ayari'

# --- 7. Bos hooks nesnesi yapilandirma degildir ----------------------
printf '%s\n' '{"hooks":{}}' > "$repo/.claude/settings.json"
expect_warn "$tmp/home-bos" 'bos hooks nesnesi'

# --- 8. Proje yerel ayarinda hook ------------------------------------
printf '%s\n' '{"hooks":{"Stop":[]}}' > "$repo/.claude/settings.local.json"
expect_quiet "$tmp/home-bos" 'proje yerel ayari'
rm -f "$repo/.claude/settings.local.json"

# --- 9. Plugin projede etkinlestirilmis -------------------------------
mkdir -p "$tmp/home-proje/plugins"
printf '{"version":2,"plugins":{"agents-kit@agents-kit":[{"installPath":"%s"}]}}\n' "$package" \
  > "$tmp/home-proje/plugins/installed_plugins.json"
printf '{"hooks":{},"enabledPlugins":{"agents-kit@agents-kit":true}}\n' > "$repo/.claude/settings.json"
expect_quiet "$tmp/home-proje" 'projede etkinlestirilen plugin'

# --- 10. Proje kapatmasi kullanici acmasini ezmeli ---------------------
# Claude Code ayar onceligi: proje yerel > proje > kullanici. Kullanici
# plugini acmis ama proje kapatmissa o projede hook YUKLENMEZ. Dogrulayici
# bunu gormezse kapali plugini calisiyor sayar ve korumayi oldugundan
# genis gosterir.
write_home "$tmp/home-oncelik" true "$package"
printf '{"enabledPlugins":{"agents-kit@agents-kit":false}}' > "$repo/.claude/settings.json"
expect_warn "$tmp/home-oncelik" 'proje kapatmasi kullaniciyi ezer'

# --- 11. Ters yon: kullanici kapatmis, proje acmis --------------------
write_home "$tmp/home-ters" false "$package"
printf '{"enabledPlugins":{"agents-kit@agents-kit":true}}' > "$repo/.claude/settings.json"
expect_quiet "$tmp/home-ters" 'proje acmasi kullaniciyi ezer'

# --- 12. Proje yerel ayari en yuksek oncelik --------------------------
printf '{"enabledPlugins":{"agents-kit@agents-kit":true}}' > "$repo/.claude/settings.json"
printf '{"enabledPlugins":{"agents-kit@agents-kit":false}}' > "$repo/.claude/settings.local.json"
expect_warn "$tmp/home-oncelik" 'proje yerel ayari en ustte'
rm -f "$repo/.claude/settings.local.json"

[ "$fail" -eq 0 ] || exit 1
printf 'PASS claude-hook-source\n'
