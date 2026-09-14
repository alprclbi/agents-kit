#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# ISKELE BILDIRIMI SOZLESMESI.
#
# Kullanici komut ezberlemesin diye oturum baglami iki seyi bildirir:
# iskele hic yoksa, ve iskele plugin surumunun gerisindeyse. Ajan bunu
# gorup kurulumu/tazelemeyi teklif eder. Bildirim yoksa kullanici
# plugin'i kurar ama projede hicbir sey olmaz ve sebebini bilmez.

tmp=$(mktemp -d "$root/.agents/runtime/scaffold-test.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

# --- 1. Iskele hic yok ------------------------------------------------
mkdir -p "$tmp/bos"
set +e
out=$(sh "$validator" session-context --root "$tmp/bos" --client claude --source startup --format text 2>&1)
set -e
printf '%s' "$out" | grep -Fq 'Iskele: yok' \
  || { printf 'FAIL iskele yoklugu bildirilmedi: %s\n' "$out" >&2; fail=1; }

# --- 2. Iskele plugin surumunun gerisinde -----------------------------
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$tmp/eski"
printf '1.0.0\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup \
      --format text --plugin-version 1.9.9)
printf '%s' "$out" | grep -Fq 'Iskele: 1.0.0 (plugin 1.9.9)' \
  || { printf 'FAIL eski iskele bildirilmedi\n' >&2; fail=1; }

# --- 3. Surumler esitse gurultu yapilmamali ---------------------------
printf '1.9.9\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup \
      --format text --plugin-version 1.9.9)
printf '%s' "$out" | grep -Fq 'Iskele:' \
  && { printf 'FAIL surumler esitken bildirim basildi\n' >&2; fail=1; }

# --- 4. Plugin surumu bilinmiyorsa iddia edilmemeli -------------------
printf '1.0.0\n' > "$tmp/eski/.agents/VERSION"
out=$(sh "$validator" session-context --root "$tmp/eski" --client claude --source startup --format text)
printf '%s' "$out" | grep -Fq 'plugin' \
  && { printf 'FAIL plugin surumu bilinmezken iddia edildi\n' >&2; fail=1; }

[ "$fail" -eq 0 ] || exit 1
printf 'PASS scaffold-notice\n'
