#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# doctor bloklayici tanida 2 ile cikar; test onu rapor edebilmeli,
# set -e ile olmemeli.
run_doctor() {
  set +e
  sh "$validator" doctor --root "$1" --client codex --format json
  set -e
}

# --- Sema yalniz solo ve team tasimali -------------------------------
for schema in "$root/.agents/schemas/config.schema.json" "$root/.agents/schemas/work.schema.json"; do
  if grep -Fq 'high-assurance' "$schema"; then
    printf 'FAIL %s hala high-assurance tasiyor\n' "$schema" >&2; fail=1
  fi
done
if grep -Fq '"auto", "solo"' "$root/.agents/schemas/config.schema.json"; then
  printf 'FAIL config semasi hala auto tasiyor\n' >&2; fail=1
fi

# --- Eski high-assurance degeri team olarak calismali ----------------
tmp=$(mktemp -d "$root/.agents/runtime/profile-test.XXXXXX")
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$tmp/repo"
jq '.profile="high-assurance"' "$tmp/repo/.agents/config.json" > "$tmp/c.json"
mv "$tmp/c.json" "$tmp/repo/.agents/config.json"
out=$(run_doctor "$tmp/repo")
printf '%s' "$out" | jq -e '.profile == "team"' >/dev/null \
  || { printf 'FAIL eski high-assurance team olarak calismali\n' >&2; fail=1; }
printf '%s' "$out" | jq -e 'any(.diagnostics[]; .code == "AKW102" and .blocking == false)' >/dev/null \
  || { printf 'FAIL eski profil degeri icin AKW102 uyarisi yok\n' >&2; fail=1; }
rm -rf "$tmp"

# --- Aktif is sayisi profili degistirmemeli --------------------------
tmp2=$(mktemp -d "$root/.agents/runtime/profile-count.XXXXXX")
cp -R "$root/.agents/tests/fixtures/validator/team-multiple-active/repo" "$tmp2/repo"
jq '.profile="solo"' "$tmp2/repo/.agents/config.json" > "$tmp2/c.json"
mv "$tmp2/c.json" "$tmp2/repo/.agents/config.json"
out2=$(run_doctor "$tmp2/repo")
printf '%s' "$out2" | jq -e '.profile == "solo"' >/dev/null \
  || { printf 'FAIL iki aktif is profili degistirmemeli\n' >&2; fail=1; }
printf '%s' "$out2" | jq -e '.blocking == false' >/dev/null \
  || { printf 'FAIL iki aktif is bloklamamali\n' >&2; fail=1; }

# --- auto degeri solo olarak calismali ve uyarmali -------------------
jq '.profile="auto"' "$tmp2/repo/.agents/config.json" > "$tmp2/c2.json"
mv "$tmp2/c2.json" "$tmp2/repo/.agents/config.json"
out3=$(run_doctor "$tmp2/repo")
printf '%s' "$out3" | jq -e '.profile == "solo"' >/dev/null \
  || { printf 'FAIL auto solo olarak calismali\n' >&2; fail=1; }
printf '%s' "$out3" | jq -e '.blocking == false' >/dev/null \
  || { printf 'FAIL auto bloklamamali\n' >&2; fail=1; }
printf '%s' "$out3" | jq -e 'any(.diagnostics[]; .code == "AKW102")' >/dev/null \
  || { printf 'FAIL auto icin AKW102 uyarisi yok\n' >&2; fail=1; }
rm -rf "$tmp2"

# --- Butce asimi iki profilde de uyari olmali ------------------------
# Butce maliyet ve kalite konusu; ekip calismasiyla ilgisi yok.
tmp3=$(mktemp -d "$root/.agents/runtime/budget-test.XXXXXX")
for prof in solo team; do
  rm -rf "$tmp3/repo"
  cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$tmp3/repo"
  jq --arg p "$prof" '.profile=$p' "$tmp3/repo/.agents/config.json" > "$tmp3/c.json"
  mv "$tmp3/c.json" "$tmp3/repo/.agents/config.json"
  limit=$(jq -r '.instructionBudgets.agentsMaxBytes' "$tmp3/repo/.agents/config.json")
  awk -v n="$((limit + 10))" 'BEGIN { for (i = 0; i < n; i++) printf "a" }' > "$tmp3/repo/AGENTS.md"
  out4=$(run_doctor "$tmp3/repo")
  printf '%s' "$out4" | jq -e 'any(.diagnostics[]; .code == "AKW101" and .blocking == false)' >/dev/null \
    || { printf 'FAIL %s profilinde AKW101 uyari olmali\n' "$prof" >&2; fail=1; }
  printf '%s' "$out4" | jq -e 'all(.diagnostics[]; .code != "AKE102")' >/dev/null \
    || { printf 'FAIL %s profilinde AKE102 uretilmemeli\n' "$prof" >&2; fail=1; }
done
rm -rf "$tmp3"

[ "$fail" -eq 0 ] || exit 1
printf 'PASS profile-model\n'
