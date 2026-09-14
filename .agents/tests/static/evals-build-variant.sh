#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
bv=.agents/evals/lib/build-variant.sh
[ -f "$bv" ] || { printf 'E_BV_MISSING\n' >&2; exit 2; }

mkdir -p "$root/.agents/runtime"
tmp=$(mktemp -d "$root/.agents/runtime/bv.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

# A1: canli AGENTS.md ile isaretci satirlari haric ayni olmali.
sh "$bv" --root "$root" --arm A1 --out "$tmp/a1"
grep -v '^<!-- ak:block ' AGENTS.md > "$tmp/expected-a1"
diff -q "$tmp/expected-a1" "$tmp/a1/AGENTS.md" >/dev/null || { printf 'E_BV_A1_DIFF\n' >&2; exit 2; }

# A1 ciktisinda hicbir isaretci kalmamali.
! grep -q '^<!-- ak:block ' "$tmp/a1/AGENTS.md" || { printf 'E_BV_A1_MARKERS\n' >&2; exit 2; }

# A0: AGENTS.md yazilmamali ve CLAUDE.md import satiri kalmamali.
sh "$bv" --root "$root" --arm A0 --out "$tmp/a0"
[ ! -f "$tmp/a0/AGENTS.md" ] || { printf 'E_BV_A0_FILE\n' >&2; exit 2; }
! grep -q '^@AGENTS\.md' "$tmp/a0/CLAUDE.md" || { printf 'E_BV_A0_IMPORT\n' >&2; exit 2; }

# A2/A3/A4: ilgili blok icerigi dusmeli, digerleri kalmali.
sh "$bv" --root "$root" --arm A2 --out "$tmp/a2"
! grep -q '^## 1\. Talimat Sırası' "$tmp/a2/AGENTS.md" || { printf 'E_BV_A2_KEPT\n' >&2; exit 2; }
grep -q '^## 6\. Güvenlik ve Onay Sınırları' "$tmp/a2/AGENTS.md" || { printf 'E_BV_A2_LOST\n' >&2; exit 2; }

sh "$bv" --root "$root" --arm A3 --out "$tmp/a3"
! grep -q '^## 4\. Uygulama Tabanı' "$tmp/a3/AGENTS.md" || { printf 'E_BV_A3_KEPT\n' >&2; exit 2; }
grep -q '^## 1\. Talimat Sırası' "$tmp/a3/AGENTS.md" || { printf 'E_BV_A3_LOST\n' >&2; exit 2; }

sh "$bv" --root "$root" --arm A4 --out "$tmp/a4"
! grep -q '^## 6\. Güvenlik ve Onay Sınırları' "$tmp/a4/AGENTS.md" || { printf 'E_BV_A4_KEPT\n' >&2; exit 2; }
grep -q '^## 1\. Talimat Sırası' "$tmp/a4/AGENTS.md" || { printf 'E_BV_A4_LOST\n' >&2; exit 2; }

sh "$bv" --root "$root" --arm A5 --out "$tmp/a5"
! grep -q '^## 2\. Çalışma Sözleşmesi' "$tmp/a5/AGENTS.md" || { printf 'E_BV_A5_KEPT
' >&2; exit 2; }
grep -q '^## 6\. Güvenlik ve Onay Sınırları' "$tmp/a5/AGENTS.md" || { printf 'E_BV_A5_LOST
' >&2; exit 2; }

sh "$bv" --root "$root" --arm A6 --out "$tmp/a6"
! grep -q '^## 8\. Skill, Plugin, MCP ve Kaynaklar' "$tmp/a6/AGENTS.md" || { printf 'E_BV_A6_KEPT
' >&2; exit 2; }
grep -q '^## 1\. Talimat Sırası' "$tmp/a6/AGENTS.md" || { printf 'E_BV_A6_LOST
' >&2; exit 2; }

# Gecersiz kol reddedilmeli.
if sh "$bv" --root "$root" --arm A9 --out "$tmp/a9" 2>/dev/null; then
  printf 'E_BV_BAD_ARM_ACCEPTED\n' >&2; exit 2
fi

# UTF-8 korunmali.
iconv -f UTF-8 -t UTF-8 "$tmp/a1/AGENTS.md" >/dev/null || { printf 'E_BV_UTF8\n' >&2; exit 2; }
grep -q 'ğ\|ü\|ş\|ı\|ö\|ç' "$tmp/a1/AGENTS.md" || { printf 'E_BV_NO_TURKISH\n' >&2; exit 2; }

printf 'PASS evals-build-variant\n'
