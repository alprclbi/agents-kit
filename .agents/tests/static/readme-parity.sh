#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# INGILIZCE README TURKCE README'NIN GERISINDE KALMAMALI.
#
# README.en.md bir ceviridir. Kurulum veya guncelleme komutu yalniz
# Turkce surumde degisirse Ingilizce okuyan kullanici eski komutu
# calistirir. Metnin cevirisi denetlenemez; komutlar ve bolum yapisi
# denetlenebilir:
#  - Iki dosyadaki bash bloklarinda claude/codex/git/sh ile baslayan
#    komut satirlari birebir ayni olmali. Ornek yollar (cd /senin/projen)
#    cevrilebilir, komutlar cevrilmez.
#  - /agents-kit: komut adlari ayni kumede olmali.
#  - Ikinci duzey baslik sayisi esit olmali.

tr=README.md
en=README.en.md
[ -f "$tr" ] || { printf 'E_RP_MISSING %s\n' "$tr" >&2; exit 2; }
[ -f "$en" ] || { printf 'E_RP_MISSING %s\n' "$en" >&2; exit 2; }

tmp=$(mktemp -d)
case "$tmp" in /*) ;; *) printf 'E_RP_TMP %s\n' "$tmp" >&2; exit 2 ;; esac
cleanup_rp() { case "$tmp" in /*/*) rm -rf -- "$tmp" ;; esac; }
trap cleanup_rp EXIT HUP INT TERM

fail=0

bash_lines() {
  awk '/^```bash$/ {on=1; next} on && /^```$/ {on=0; next} on && /^(claude|codex|git|sh) / {print}' "$1"
}
bash_lines "$tr" > "$tmp/tr.bash"
bash_lines "$en" > "$tmp/en.bash"
cmp -s "$tmp/tr.bash" "$tmp/en.bash" || {
  printf 'E_RP_COMMANDS bash bloklari farkli:\n' >&2
  diff "$tmp/tr.bash" "$tmp/en.bash" >&2 || true
  fail=1
}

skill_names() { grep -oE '/agents-kit:[a-z-]+' "$1" | LC_ALL=C sort -u || true; }
skill_names "$tr" > "$tmp/tr.skills"
skill_names "$en" > "$tmp/en.skills"
cmp -s "$tmp/tr.skills" "$tmp/en.skills" || { printf 'E_RP_SKILLS /agents-kit: komutlari farkli\n' >&2; fail=1; }

tr_h=$(grep -c '^## ' "$tr" || true)
en_h=$(grep -c '^## ' "$en" || true)
[ "$tr_h" = "$en_h" ] || { printf 'E_RP_SECTIONS baslik sayisi %s != %s\n' "$tr_h" "$en_h" >&2; fail=1; }

[ "$fail" -eq 0 ] || exit 2
exit 0
