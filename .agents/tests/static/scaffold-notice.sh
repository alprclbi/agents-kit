#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# ISKELE BILDIRIMI SOZLESMESI.
#
# Iki ayri durum, iki ayri kural:
#
# 1. Iskele HIC YOKSA kit o projede kurulu degildir. Plugin kullanici
#    seviyesinde etkinlestirildiginde hook HER projede calisir, yalniz
#    iskelenin bulundugu projede degil. Orada dogrulayicinin yapacagi is
#    yoktur: hicbir cikti vermeden 0 ile cikar. Cokerse istemci her
#    mutasyon aracinda hook hatasi gosterir; bildirim yaparsa iskelesi
#    olmayan her projede her oturum tekrarlanan gurultu olur. Kit istenen
#    projede /agents-kit:init ile acilir; kesif yolu odur.
#
# 2. Iskele VARSA ama plugin surumunun gerisindeyse tek satirla bildirilir.
#    Ajan bunu gorup tazelemeyi teklif eder.

tmp=$(mktemp -d "$root/.agents/runtime/scaffold-test.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

# --- 1. Iskele hic yok: session-context sessiz -------------------------
mkdir -p "$tmp/bos"
set +e
out=$(sh "$validator" session-context --root "$tmp/bos" --client claude --source startup --format text 2>&1)
code=$?
set -e
[ "$code" -eq 0 ] \
  || { printf 'FAIL iskelesiz session-context %s ile dustu: %s\n' "$code" "$out" >&2; fail=1; }
[ -z "$out" ] \
  || { printf 'FAIL iskelesiz session-context cikti verdi: %s\n' "$out" >&2; fail=1; }

# --- 2. Iskele hic yok: pre-tool-use sessizce gecer --------------------
set +e
out=$(printf '%s' '{"tool_name":"Write","tool_input":{}}' \
      | sh "$validator" pre-tool-use --root "$tmp/bos" --client claude --format json 2>&1)
code=$?
set -e
[ "$code" -eq 0 ] \
  || { printf 'FAIL iskelesiz pre-tool-use %s ile dustu: %s\n' "$code" "$out" >&2; fail=1; }
[ "$out" = '{"hookSpecificOutput":{"hookEventName":"PreToolUse"}}' ] \
  || { printf 'FAIL iskelesiz pre-tool-use bos karar dondurmedi: %s\n' "$out" >&2; fail=1; }

# --- 3. Iskele hic yok: stop-check sessizce gecer ----------------------
set +e
out=$(sh "$validator" stop-check --root "$tmp/bos" --client claude --format json 2>&1)
code=$?
set -e
[ "$code" -eq 0 ] \
  || { printf 'FAIL iskelesiz stop-check %s ile dustu: %s\n' "$code" "$out" >&2; fail=1; }
[ "$out" = '{"continue":true}' ] \
  || { printf 'FAIL iskelesiz stop-check devam karari vermedi: %s\n' "$out" >&2; fail=1; }

# --- 4. Kapi dar: iskele VARSA denetim dusmez --------------------------
# Kapi yalniz config.json yoklugunda acilmali. Genis acilirsa kitin kurulu
# oldugu projede mutasyon kapisi sessizce devre disi kalir ve bunu hicbir
# sey fark etmez.
set +e
out=$(printf '%s' '{"tool_name":"Write","tool_input":{}}' \
      | sh "$validator" pre-tool-use \
        --root "$root/.agents/tests/fixtures/validator/team-missing-work/repo" \
        --client claude --format json 2>&1)
set -e
printf '%s' "$out" | grep -Fq '"permissionDecision":"deny"' \
  || { printf 'FAIL iskele varken mutasyon kapisi denetlemedi: %s\n' "$out" >&2; fail=1; }

# --- 5. Iskele plugin surumunun gerisinde -----------------------------
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$tmp/eski"
printf '1.0.0\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup \
      --format text --plugin-version 1.9.9)
printf '%s' "$out" | grep -Fq 'Iskele: 1.0.0 (plugin 1.9.9)' \
  || { printf 'FAIL eski iskele bildirilmedi\n' >&2; fail=1; }

# --- 6. Surumler esitse gurultu yapilmamali ---------------------------
printf '1.9.9\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup \
      --format text --plugin-version 1.9.9)
printf '%s' "$out" | grep -Fq 'Iskele:' \
  && { printf 'FAIL surumler esitken bildirim basildi\n' >&2; fail=1; }

# --- 7. Plugin surumu bilinmiyorsa iddia edilmemeli -------------------
printf '1.0.0\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup --format text)
printf '%s' "$out" | grep -Fq 'plugin' \
  && { printf 'FAIL plugin surumu bilinmezken iddia edildi\n' >&2; fail=1; }

[ "$fail" -eq 0 ] || exit 1
printf 'PASS scaffold-notice\n'
