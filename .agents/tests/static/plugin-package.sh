#!/bin/sh
set -eu
root=$1
fail=0
version=$(tr -d ' \r\n' < "$root/.agents/VERSION")

# Dort dosya senkron tutulur: iki manifest, iki katalog. Semalar Task 11'de
# resmi kaynaklardan dogrulandi; ayrintisi research.md icinde.
claude_plugin="$root/.claude-plugin/plugin.json"
claude_market="$root/.claude-plugin/marketplace.json"
codex_plugin="$root/.codex-plugin/plugin.json"
codex_market="$root/.agents/plugins/marketplace.json"

for f in "$claude_plugin" "$claude_market" "$codex_plugin" "$codex_market"; do
  [ -f "$f" ] || { printf 'FAIL eksik: %s\n' "${f#"$root"/}" >&2; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

# --- Iki manifest ayni ad ve surumu tasimali -------------------------
for m in "$claude_plugin" "$codex_plugin"; do
  jq -e --arg v "$version" '.name == "agents-kit" and .version == $v' "$m" >/dev/null \
    || { printf 'FAIL %s ad veya surum uyusmuyor (VERSION=%s)\n' "${m#"$root"/}" "$version" >&2; fail=1; }
done

# --- Codex manifesti bilesen yollarini acikca bildirmeli --------------
jq -e '.skills == "./skills/" and .hooks == "./hooks/hooks.json"' "$codex_plugin" >/dev/null \
  || { printf 'FAIL codex manifesti skills/hooks yollarini bildirmiyor\n' >&2; fail=1; }

# --- Claude katalogu -------------------------------------------------
claude_v=$(jq -r '.plugins[0].version // empty' "$claude_market")
[ "$claude_v" = "$version" ] || { printf 'FAIL claude katalog surumu: %s != %s\n' "$claude_v" "$version" >&2; fail=1; }
jq -e '.name == "agents-kit" and .plugins[0].name == "agents-kit"' "$claude_market" >/dev/null \
  || { printf 'FAIL claude katalog ad alanlari yanlis\n' >&2; fail=1; }

# --- Codex katalogu dogrulanmis semayi kullanmali ---------------------
# Girdide version YOKTUR; surum .codex-plugin/plugin.json icinde yasar.
jq -e '.name == "agents-kit"
       and (.interface.displayName | type == "string")
       and .plugins[0].name == "agents-kit"
       and .plugins[0].source.source == "url"
       and (.plugins[0].policy.installation | type == "string")
       and (.plugins[0].category | type == "string")' "$codex_market" >/dev/null \
  || { printf 'FAIL codex katalog girdisi semaya uymuyor\n' >&2; fail=1; }
jq -e '.plugins[0] | has("version") | not' "$codex_market" >/dev/null \
  || { printf 'FAIL codex katalog girdisinde version alani olmamali\n' >&2; fail=1; }

# policy.authentication bir ENUM: yalniz ON_INSTALL veya ON_USE. 2026-09-14:
# "NONE" yazilmisti ve gercek Codex kurulumu su hatayla reddetti:
#   unknown variant `NONE`, expected `ON_INSTALL` or `ON_USE`
# Kit kimlik dogrulamasi istemedigi icin alan hic yazilmiyor. Yazilacaksa
# iki gecerli degerden biri olmali.
jq -e '(.plugins[0].policy | has("authentication") | not)
       or (.plugins[0].policy.authentication == "ON_INSTALL")
       or (.plugins[0].policy.authentication == "ON_USE")' "$codex_market" >/dev/null \
  || { printf 'FAIL codex katalog policy.authentication gecersiz (ON_INSTALL, ON_USE veya hic olmali)\n' >&2; fail=1; }

# --- Plugin kokunde bilesenler bulunmali ------------------------------
[ -d "$root/skills" ] || { printf 'FAIL skills/ yok\n' >&2; fail=1; }
[ -f "$root/hooks/hooks.json" ] || { printf 'FAIL hooks/hooks.json yok\n' >&2; fail=1; }

# --- Hook degiskenleri yer degistirmemeli -----------------------------
# CLAUDE_PLUGIN_ROOT dogrulayiciyi, CLAUDE_PROJECT_DIR kullanicinin
# projesini gosterir. Yer degistirirlerse hook YANLIS depoyu denetler ve
# bunu sessizce yapar: cikti yine uretilir, sadece yanlis proje uzerinde.
if [ -f "$root/hooks/hooks.json" ]; then
  for event in SessionStart PreToolUse Stop; do
    cmd=$(jq -r --arg e "$event" '.hooks[$e][0].hooks[0].command // ""' "$root/hooks/hooks.json")
    [ -n "$cmd" ] || { printf 'FAIL %s hook komutu yok\n' "$event" >&2; fail=1; continue; }
    case "$cmd" in
      *'${CLAUDE_PLUGIN_ROOT}/.agents/validators/sh/agent-kit.sh'*) ;;
      *) printf 'FAIL %s dogrulayiciyi CLAUDE_PLUGIN_ROOT ile cagirmiyor\n' "$event" >&2; fail=1 ;;
    esac
    case "$cmd" in
      *'--root "${CLAUDE_PROJECT_DIR}"'*) ;;
      *) printf 'FAIL %s --root degeri CLAUDE_PROJECT_DIR degil\n' "$event" >&2; fail=1 ;;
    esac
  done
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS plugin-package\n'
