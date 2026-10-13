#!/bin/sh
set -eu
root=$1
fail=0
validator="$root/.agents/validators/sh/agent-kit.sh"

# OTURUM BASI OZET SOZLESMESI (resume-work).
#
# Aktif is cozulduyse oturum baglami asama, son checkpoint, siradaki adim
# ve acik kabul olcutlerini tek blokta verir. Kaynak yalniz is kaydidir;
# eksik alan "kayıtlı değil" yazar, tahmin uretilmez. Spec yolu proje
# disina cikiyorsa okunmaz.

tmp=$(mktemp -d "$root/.agents/runtime/session-summary.XXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT HUP INT TERM

make_repo() {
  repo=$1
  cp -R "$root/.agents/tests/fixtures/validator/solo-one-active/repo" "$repo"
}

summary() {
  sh "$validator" session-context --root "$1" --client claude --source startup --format text \
    | awk '/^Özet:$/ {f=1} f && /^#/ {exit} f'
}

expect_line() {
  printf '%s\n' "$1" | grep -Fxq -- "$2" || { printf 'FAIL %s: satir yok: %s\n' "$3" "$2" >&2; fail=1; }
}

# --- 1. Tam kayit -------------------------------------------------------
make_repo "$tmp/tam"
work="$tmp/tam/.agents/changes/active/123"
jq '.updatedAt = "2026-10-01T12:00:00Z" | .artifacts.spec = ".agents/changes/active/123/spec.md"' "$work/work.json" > "$tmp/w.json"
mv "$tmp/w.json" "$work/work.json"
cat > "$work/status.md" <<'MD'
# Sentetik — Durum

## Mevcut aşama

- Uygulama: ikinci görev

## Sıradaki en küçük güvenli adım

Doğrulayıcı testini yaz.
MD
{
  printf '# Spec\n\n## Kabul kriterleri\n\n- [x] tamamlanan madde\n'
  for n in 1 2 3 4 5 6 7; do printf -- '- [ ] açık madde %s\n' "$n"; done
  printf '\n## Riskler, varsayımlar ve açık kararlar\n\n- [ ] kapsam dışı madde\n'
} > "$work/spec.md"
out=$(summary "$tmp/tam")
expect_line "$out" '- Aşama: Uygulama: ikinci görev' tam
expect_line "$out" '- Son checkpoint: 2026-10-01T12:00:00Z' tam
expect_line "$out" '- Sıradaki adım: Doğrulayıcı testini yaz.' tam
expect_line "$out" '- Açık kabul ölçütü: 7' tam
expect_line "$out" '  - açık madde 5' tam
expect_line "$out" '  - (+2 daha)' tam
printf '%s' "$out" | grep -Fq 'açık madde 6' && { printf 'FAIL tam: bes maddeden fazlasi listelendi\n' >&2; fail=1; }
printf '%s' "$out" | grep -Fq 'tamamlanan' && { printf 'FAIL tam: isaretli madde acik sayildi\n' >&2; fail=1; }
printf '%s' "$out" | grep -Fq 'kapsam dışı' && { printf 'FAIL tam: baska bolumun maddesi sayildi\n' >&2; fail=1; }

# --- 2. Bos sablon, spec yok ----------------------------------------------
make_repo "$tmp/bos"
sed 's/{{WORK_TITLE}}/Sentetik/' "$root/.agents/templates/change/status.md" > "$tmp/bos/.agents/changes/active/123/status.md"
out=$(summary "$tmp/bos")
expect_line "$out" '- Aşama: kayıtlı değil' bos
expect_line "$out" '- Son checkpoint: kayıtlı değil' bos
expect_line "$out" '- Sıradaki adım: kayıtlı değil' bos
expect_line "$out" '- Açık kabul ölçütü: spec kayıtlı değil' bos

# --- 3. Proje disina cikan spec yolu okunmaz -------------------------------
make_repo "$tmp/kacak"
mkdir -p "$tmp/dis"
printf '## Kabul kriterleri\n\n- [ ] dis madde\n' > "$tmp/dis/spec.md"
jq '.artifacts.spec = "../dis/spec.md"' "$tmp/kacak/.agents/changes/active/123/work.json" > "$tmp/w.json"
mv "$tmp/w.json" "$tmp/kacak/.agents/changes/active/123/work.json"
out=$(summary "$tmp/kacak")
expect_line "$out" '- Açık kabul ölçütü: spec kayıtlı değil' kacak

# --- 4. CRLF status.md ------------------------------------------------------
make_repo "$tmp/crlf"
printf '## Mevcut aşama\r\n\r\nTest\r\n' > "$tmp/crlf/.agents/changes/active/123/status.md"
out=$(summary "$tmp/crlf")
expect_line "$out" '- Aşama: Test' crlf

# --- 5. PowerShell metin paritesi ------------------------------------------
ps_bin=$(command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null || true)
if [ -n "$ps_bin" ]; then
  ps_entry="$root/.agents/validators/ps/agent-kit.ps1"
  command -v cygpath >/dev/null 2>&1 && ps_entry=$(cygpath -w "$ps_entry")
  for name in tam bos kacak crlf; do
    ps_repo="$tmp/$name"
    command -v cygpath >/dev/null 2>&1 && ps_repo=$(cygpath -w "$ps_repo")
    want=$(summary "$tmp/$name")
    got=$("$ps_bin" -NoProfile -NonInteractive -File "$ps_entry" session-context -Root "$ps_repo" -Client claude -Source startup -Format text 2>/dev/null \
      | tr -d '\r' | awk '/^Özet:$/ {f=1} f && /^#/ {exit} f')
    [ "$got" = "$want" ] || { printf 'FAIL ps paritesi [%s]:\n%s\n---\n%s\n' "$name" "$want" "$got" >&2; fail=1; }
  done
else
  printf 'SKIP ps paritesi: PowerShell bulunamadi\n' >&2
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS session-summary\n'
