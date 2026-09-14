#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

run_doctor() {
  set +e
  sh "$validator" doctor --root "$1" --client codex --format json
  set -e
}

tmp=$(mktemp -d "$root/.agents/runtime/pointer-test.XXXXXX")
cp -R "$root/.agents/tests/fixtures/validator/team-multiple-active/repo" "$tmp/repo"
mkdir -p "$tmp/repo/.agents/runtime"

first=$(ls "$tmp/repo/.agents/changes/active" | head -1)

# --- Gecerli isaretci isi cozmeli -----------------------------------
printf '%s\n' "$first" > "$tmp/repo/.agents/runtime/current-work"
out=$(run_doctor "$tmp/repo")
printf '%s' "$out" | jq -e --arg id "$first" '.resolvedWorkId == $id' >/dev/null \
  || { printf 'FAIL isaretci ile is cozulmedi\n' >&2; fail=1; }
printf '%s' "$out" | jq -e '.workSource == "pointer"' >/dev/null \
  || { printf 'FAIL workSource pointer degil\n' >&2; fail=1; }
printf '%s' "$out" | jq -e 'all(.diagnostics[]; .code != "AKE201")' >/dev/null \
  || { printf 'FAIL isaretci varken AKE201 cikmamali\n' >&2; fail=1; }

# --- Bayat isaretci yok sayilmali ve uyarmali ------------------------
printf 'olmayan-is\n' > "$tmp/repo/.agents/runtime/current-work"
out=$(run_doctor "$tmp/repo")
printf '%s' "$out" | jq -e 'any(.diagnostics[]; .code == "AKW103" and .blocking == false)' >/dev/null \
  || { printf 'FAIL bayat isaretci uyarmadi\n' >&2; fail=1; }
printf '%s' "$out" | jq -e '.resolvedWorkId != "olmayan-is"' >/dev/null \
  || { printf 'FAIL bayat isaretci kullanildi\n' >&2; fail=1; }

# --- Isaretci yokken kaynak dogru raporlanmali -----------------------
rm -f "$tmp/repo/.agents/runtime/current-work"
out=$(run_doctor "$tmp/repo")
printf '%s' "$out" | jq -e '.workSource == "none"' >/dev/null \
  || { printf 'FAIL isaretci yokken workSource none olmali\n' >&2; fail=1; }

rm -rf "$tmp"

# --- Skill sozlesmeleri isaretciyi tanimlamali -----------------------
for s in start-work resume-work; do
  grep -Fq 'current-work' "$root/skills/$s/SKILL.md" \
    || { printf 'FAIL %s isaretciyi yazmiyor\n' "$s" >&2; fail=1; }
done
for s in close-work archive-work; do
  grep -Fq 'current-work' "$root/skills/$s/SKILL.md" \
    || { printf 'FAIL %s isaretciyi temizlemiyor\n' "$s" >&2; fail=1; }
done

[ "$fail" -eq 0 ] || exit 1
printf 'PASS current-work isaretcisi\n'
