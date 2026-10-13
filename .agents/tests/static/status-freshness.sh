#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# STOP HOOK KAYIT GUNCELLIGI (AKW301).
#
# Aktif is varken calisma agacinda status.md'den daha yeni bir degisiklik
# varsa checkpoint atlanmistir; sonraki oturum yalniz diske guvenebilir.
# Uyaridir, hicbir profilde kapanisi engellemez. Kaynak git: degismis ve
# izlenmeyen (ignore disi) dosyalar; is kaydi ve runtime sayilmaz.

# Gecici depo kitin deposu DISINDA: icinde olsaydi git kitin kendi
# durumunu raporlardi.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/akfresh.XXXXXX")
case "$tmp" in /*/*) ;; *) printf 'FAIL gecici dizin: %s\n' "$tmp" >&2; exit 1 ;; esac
cleanup() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup EXIT HUP INT TERM

repo="$tmp/repo"
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$repo"
printf 'build/\n' > "$repo/.gitignore"
git -C "$repo" init -q
git -C "$repo" add -A
git -C "$repo" -c user.email=test@example.invalid -c user.name=test commit -q -m init
status="$repo/.agents/changes/active/123/status.md"
old() { touch -t 202001010000 "$status"; }

warns() {
  printf '{}' | sh "$validator" stop-check --root "$1" --client claude --format json \
    | jq -e '.continue == true and (has("decision") | not) and (.systemMessage // "" | contains("AKW301"))' >/dev/null
}
expect_warn() { warns "$1" || { printf 'FAIL %s: AKW301 beklendi\n' "$2" >&2; fail=1; }; }
expect_quiet() { if warns "$1"; then printf 'FAIL %s: AKW301 yanlis uyari\n' "$2" >&2; fail=1; fi; }

# --- 1. Temiz agac ------------------------------------------------------
old
expect_quiet "$repo" 'temiz agac'

# --- 2. status.md'den yeni izlenmeyen dosya -------------------------------
mkdir -p "$repo/src/solo"
printf 'x\n' > "$repo/src/solo/yeni.txt"
expect_warn "$repo" 'yeni dosya'
# Uyari metni dosyayi ve isi soylemeli; kod tek basina anlamsiz.
printf '{}' | sh "$validator" stop-check --root "$repo" --client claude --format json \
  | jq -e '.systemMessage | contains("123") and contains("src/solo/yeni.txt")' >/dev/null \
  || { printf 'FAIL uyari metni is ve dosyayi soylemiyor\n' >&2; fail=1; }

# --- 3. team profilinde de uyari, kapi degil -------------------------------
jq '.profile = "team"' "$repo/.agents/config.json" > "$tmp/c.json"
cp "$tmp/c.json" "$repo/.agents/config.json"
expect_warn "$repo" 'team profili'
git -C "$repo" checkout -q -- .agents/config.json

# --- 4. status.md guncellendi -----------------------------------------
touch "$status"
expect_quiet "$repo" 'checkpoint yapildi'

# --- 5. Yalniz is kaydi ve ignore edilen dosya degisti ---------------------
rm -f "$repo/src/solo/yeni.txt"
old
mkdir -p "$repo/build"
printf 'x\n' > "$repo/build/cikti.txt"
printf 'not\n' >> "$repo/.agents/changes/active/123/status.md"
touch -t 202001010000 "$status"
printf 'x\n' > "$repo/.agents/changes/active/123/notes.md"
expect_quiet "$repo" 'is kaydi ve ignore'

# --- 6. Izlenen dosya degisti ---------------------------------------------
printf 'degisti\n' >> "$repo/AGENTS.md"
expect_warn "$repo" 'izlenen dosya'
git -C "$repo" checkout -q -- AGENTS.md

# --- 7. Git deposu degil: sessiz ve hatasiz ------------------------------
cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$tmp/gitsiz"
touch -t 202001010000 "$tmp/gitsiz/.agents/changes/active/123/status.md"
printf 'x\n' > "$tmp/gitsiz/yeni.txt"
expect_quiet "$tmp/gitsiz" 'git disi'

# --- 8. PowerShell paritesi --------------------------------------------
ps_bin=$(command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null || true)
if [ -n "$ps_bin" ]; then
  ps_entry="$root/.agents/validators/ps/agent-kit.ps1"
  ps_repo=$repo
  if command -v cygpath >/dev/null 2>&1; then ps_entry=$(cygpath -w "$ps_entry"); ps_repo=$(cygpath -w "$repo"); fi
  ps_warns() {
    printf '{}' | "$ps_bin" -NoProfile -NonInteractive -File "$ps_entry" stop-check -Root "$ps_repo" -Client claude -Format json 2>/dev/null \
      | jq -e '.continue == true and (.systemMessage // "" | contains("AKW301"))' >/dev/null
  }
  old
  printf 'x\n' > "$repo/src/solo/yeni.txt"
  ps_warns || { printf 'FAIL ps paritesi: yeni dosyada AKW301 yok\n' >&2; fail=1; }
  touch "$status"
  if ps_warns; then printf 'FAIL ps paritesi: guncel status.md ile AKW301\n' >&2; fail=1; fi
else
  printf 'SKIP ps paritesi: PowerShell bulunamadi\n' >&2
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS status-freshness\n'
