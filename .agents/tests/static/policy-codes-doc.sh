#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# POLITIKA KODLARI SAYFASI KODLA AYRISMAMALI.
#
# Kullanici bir hook ciktisinda AKE203 gibi bir kod gorur ve anlamini
# docs/politika-kodlari.md icinde arar. Sayfa elle yazilir; katalog veya
# dogrulayici degisip sayfa geride kalirsa kullanici yanlis cozum uygular.
# 2026-10-13: katalogda 17 kod vardi, dogrulayicilar katalogda olmayan
# AKW102 ve AKW103'u de uretiyordu; README yalniz dort belirti anlatiyordu.
#
# Uc yon denetlenir:
#  1. Katalogdaki her kodun bolumu var ve anlam satiri katalogla birebir.
#  2. Dogrulayici, hook, skill ve sozlesmelerde gecen her kodun bolumu var.
#  3. Sayfadaki her bolum katalogda veya kodda bulunuyor (olu bolum yok)
#     ve hizli bakis tablosu bolumlerle ayni kumeyi tasiyor.

doc=docs/politika-kodlari.md
catalog=.agents/validators/policy-codes.json
[ -f "$doc" ] || { printf 'E_PCD_MISSING %s\n' "$doc" >&2; exit 2; }
[ -f "$catalog" ] || { printf 'E_PCD_NO_CATALOG %s\n' "$catalog" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { printf 'E_PCD_NO_JQ\n' >&2; exit 2; }

tmp=$(mktemp -d)
case "$tmp" in /*) ;; *) printf 'E_PCD_TMP %s\n' "$tmp" >&2; exit 2 ;; esac
cleanup_pcd() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup_pcd EXIT HUP INT TERM

fail=0

jq -r 'keys[]' "$catalog" | LC_ALL=C sort -u > "$tmp/catalog"
sed -n 's/^### \(AK[EWS][0-9][0-9][0-9]\)[[:space:]]*$/\1/p' "$doc" | LC_ALL=C sort > "$tmp/headings"
sed -n 's/^| `\(AK[EWS][0-9][0-9][0-9]\)` |.*/\1/p' "$doc" | LC_ALL=C sort > "$tmp/table"

# Ayni kod iki kez bolum almamali; hangisinin dogru oldugu belirsizlesir.
dup=$(uniq -d "$tmp/headings")
[ -z "$dup" ] || { printf 'E_PCD_DUPLICATE %s\n' $dup >&2; fail=1; }

# Kodun gectigi kaynaklar: kullaniciya kodu basan her yer.
grep -rhoE 'AK[EWS][0-9]{3}' .agents/validators .agents/contracts .agents/adapters skills hooks 2>/dev/null \
  | LC_ALL=C sort -u > "$tmp/emitted"

# 1. Katalog -> sayfa, anlam satiri birebir.
while IFS= read -r code; do
  [ -n "$code" ] || continue
  if ! grep -Fxq "$code" "$tmp/headings"; then
    printf 'E_PCD_CATALOG_UNDOCUMENTED %s\n' "$code" >&2; fail=1; continue
  fi
  meaning=$(jq -r --arg c "$code" '.[$c]' "$catalog")
  section=$(awk -v h="### $code" '$0==h {on=1; next} on && /^### / {exit} on {print}' "$doc")
  printf '%s\n' "$section" | grep -Fxq "**Anlam:** $meaning" \
    || { printf 'E_PCD_MEANING_DRIFT %s: katalog "%s"\n' "$code" "$meaning" >&2; fail=1; }
done < "$tmp/catalog"

# 2. Kod -> sayfa.
while IFS= read -r code; do
  [ -n "$code" ] || continue
  grep -Fxq "$code" "$tmp/headings" || { printf 'E_PCD_EMITTED_UNDOCUMENTED %s\n' "$code" >&2; fail=1; }
done < "$tmp/emitted"

# 3. Sayfa -> katalog veya kod; tablo -> bolumler.
LC_ALL=C sort -u "$tmp/catalog" "$tmp/emitted" > "$tmp/known"
while IFS= read -r code; do
  [ -n "$code" ] || continue
  grep -Fxq "$code" "$tmp/known" || { printf 'E_PCD_STALE_SECTION %s\n' "$code" >&2; fail=1; }
done < "$tmp/headings"
cmp -s "$tmp/headings" "$tmp/table" || { printf 'E_PCD_TABLE_MISMATCH hizli bakis tablosu bolumlerle ayni kodlari tasimiyor\n' >&2; fail=1; }

[ "$fail" -eq 0 ] || exit 2
exit 0
