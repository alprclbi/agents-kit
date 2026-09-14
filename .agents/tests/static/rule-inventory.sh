#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
inv=.agents/rule-inventory.md
[ -f "$inv" ] || { printf 'E_INV_MISSING\n' >&2; exit 2; }

# 1. Envanter HICBIR talimat zincirinden import edilmemeli (runtime maliyeti sifir).
for f in CLAUDE.md AGENTS.md .agents/project.md; do
  [ -f "$f" ] || continue
  ! grep -Fq 'rule-inventory' "$f" || { printf 'E_INV_IMPORTED %s\n' "$f" >&2; exit 2; }
done

# 2. Karar sayilari spec ile uyusmali.
k=$(grep -c '^| .* | keep | ' "$inv" || true)
d=$(grep -c '^| .* | delete | ' "$inv" || true)
m=$(grep -c '^| .* | move | ' "$inv" || true)
[ "$k" = 58 ] || { printf 'E_INV_KEEP %s (58 bekleniyor)\n' "$k" >&2; exit 2; }
[ "$d" = 15 ] || { printf 'E_INV_DELETE %s (15 bekleniyor)\n' "$d" >&2; exit 2; }
[ "$m" = 7 ]  || { printf 'E_INV_MOVE %s (7 bekleniyor)\n' "$m" >&2; exit 2; }

# 3. Cikan her kuralin TAM METNI saklanmali.
n=$(awk '/^### Çıkan kuralların tam metni/{f=1;next} f&&/^> /{n++} END{print n+0}' "$inv")
[ "$n" = 22 ] || { printf 'E_INV_FULLTEXT %s (22 bekleniyor)\n' "$n" >&2; exit 2; }

# 4. Capraz dogrulama: envanterde tam metni saklanan her kural AGENTS.md'den
#    CIKMIS olmali. Envanter ile dosya birbirini tutmuyorsa budama eksik demektir.
extra=0
awk '/^### Çıkan kuralların tam metni/{f=1;next} f&&/^> /{print substr($0,3)}' "$inv" |
while IFS= read -r body; do
  [ -n "$body" ] || continue
  if grep -Fq "$body" AGENTS.md; then
    printf 'E_INV_STILL_PRESENT %s\n' "$(printf '%s' "$body" | cut -c1-55)" >&2
    exit 9
  fi
done || extra=1
[ "$extra" = 0 ] || { printf 'E_INV_CROSSCHECK cikmasi gereken satir AGENTS.md icinde\n' >&2; exit 2; }

# 5. Tasinan kurallar HEDEFLERINDE bulunmali; kaybolmus olmamali.
for probe in 'Basit kodu, açık veri akışını' 'birbirine dönüştürme' 'sessizce yutma'; do
  grep -Fq "$probe" .agents/playbooks/verification.md \
    || { printf 'E_INV_MOVE_LOST verification.md: %s\n' "$probe" >&2; exit 2; }
done
for probe in 'tekrarlanan hata, inceleme geri bildirimi' 'en yakın kapsamlı talimat dosyasına koy' 'mekanik zorunluluğu test/linter' 'kısa, somut, test edilebilir'; do
  grep -Fq "$probe" .agents/README.md \
    || { printf 'E_INV_MOVE_LOST README.md: %s\n' "$probe" >&2; exit 2; }
done

# 6. Budanmis dosyada kural sayisi 56 olmali.
rc=$(awk '/^- /{n++} /^[0-9]+\. /{n++} END{print n+0}' AGENTS.md)
[ "$rc" = 58 ] || { printf 'E_INV_RULECOUNT %s (58 bekleniyor)\n' "$rc" >&2; exit 2; }

iconv -f UTF-8 -t UTF-8 "$inv" >/dev/null || { printf 'E_INV_UTF8\n' >&2; exit 2; }
printf 'PASS rule-inventory keep=%s delete=%s move=%s kural=%s\n' "$k" "$d" "$m" "$rc"
