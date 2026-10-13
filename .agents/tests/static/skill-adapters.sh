#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# HER KANONIK SKILL'IN TAM BIR CLAUDE ADAPTORU OLMALI, TERSI DE.
#
# skills/<ad>/SKILL.md kanonik kaynaktir; .claude/skills/<ad>/SKILL.md
# yalniz kurulu yolu (.agents/skills/<ad>/SKILL.md) gosteren ince bir
# adaptordur. Icerikleri bilerek farklidir. Tasinan risk icerik farki
# degil kume farkidir: provider-adapters.sh ve kit-management.sh skill
# adlarini elle sayar, yeni bir skill ikisine de eklenmezse adaptoru
# eksik kalir ve hicbir test dusmez. Bu kontrol kumeyi dizinden okur.
fail=0
canonical=$(find skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | awk -F/ '{print $2}' | LC_ALL=C sort)
adapters=$(find .claude/skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | awk -F/ '{print $3}' | LC_ALL=C sort)
[ -n "$canonical" ] || { printf 'FAIL skills/ altinda skill yok\n' >&2; exit 1; }

for skill in $canonical; do
  wrapper=".claude/skills/$skill/SKILL.md"
  [ -f "$wrapper" ] || { printf 'FAIL %s icin Claude adaptoru yok: %s\n' "$skill" "$wrapper" >&2; fail=1; continue; }
  name=$(sed -n 's/^name: *//p' "$wrapper" | head -n 1)
  [ "$name" = "$skill" ] || { printf 'FAIL %s adaptor adi uyusmuyor: %s\n' "$wrapper" "$name" >&2; fail=1; }
  sed -n 's/^description: *//p' "$wrapper" | grep . >/dev/null || { printf 'FAIL %s description yok\n' "$wrapper" >&2; fail=1; }
  grep -Fq "\`.agents/skills/$skill/SKILL.md\` dosyasını tamamen oku ve uygula." "$wrapper" \
    || { printf 'FAIL %s kurulu yolu gostermiyor\n' "$wrapper" >&2; fail=1; }
  grep -Fq "\`skills/$skill/SKILL.md\`" "$wrapper" \
    || { printf 'FAIL %s kanonik kaynagi gostermiyor\n' "$wrapper" >&2; fail=1; }
done

for skill in $adapters; do
  [ -f "skills/$skill/SKILL.md" ] || { printf 'FAIL .claude/skills/%s kanonik kaynagi olmayan adaptor\n' "$skill" >&2; fail=1; }
done

[ "$fail" -eq 0 ] || exit 1
printf 'PASS skill-adapters\n'
