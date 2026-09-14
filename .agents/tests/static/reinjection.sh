#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"
v=.agents/validators/sh/agent-kit.sh
solo=.agents/tests/fixtures/validator/solo-one-active/repo

# ---------------------------------------------- 1. Riskli anda hedefli enjeksiyon
# Hook zaten dogru anda metin basiyor; icerigin KOD degil KURAL tasimasi gerekir.
# Gercekten DENY eden bir kosul gerekir. Birden fazla aktif is artik
# kapi degil; team profilinde eksik is kaydi (AKE203) kapidir.
team=.agents/tests/fixtures/validator/team-missing-work/repo
# Komut MUTASYON olmali: salt okunur tani komutlari kapiyi hic calistirmaz.
blocked='{"tool_name":"Bash","tool_input":{"command":"git commit -m x"}}'
out=$(printf '%s' "$blocked" | sh "$v" pre-tool-use --root "$team" --client claude --format json)
reason=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')

printf '%s' "$reason" | grep -Fq 'AKE203' \
  || { printf 'E_RI_NO_CODE %s\n' "$reason" >&2; exit 2; }
# Kural metninin kendisi gecmeli, yalniz kod degil.
printf '%s' "$reason" | grep -Fq 'aktif iş kaydı' \
  || { printf 'E_RI_NO_RULE_TEXT %s\n' "$reason" >&2; exit 2; }

# Kapi degil ama bilgi olan durum: uyari metni de kuralin kendisini tasimali.
multi=.agents/tests/fixtures/validator/team-multiple-active/repo
warn=$(printf '%s' "$blocked" | sh "$v" pre-tool-use --root "$multi" --client claude --format json)
printf '%s' "$warn" | jq -r '.hookSpecificOutput.additionalContext // ""' | grep -Fq 'Birden fazla aktif iş' \
  || { printf 'E_RI_NO_WARN_TEXT %s\n' "$warn" >&2; exit 2; }

# Kapi acikken hicbir sey basilmamali.
safe='{"tool_name":"Bash","tool_input":{"command":"git status"}}'
out=$(printf '%s' "$safe" | sh "$v" pre-tool-use --root "$solo" --client claude --format json)
printf '%s' "$out" | jq -e '(.hookSpecificOutput | has("permissionDecisionReason")) | not' >/dev/null \
  || { printf 'E_RI_SAFE_NOISY\n' >&2; exit 2; }

# ------------------------------------------- 2. compact sonrasi sert sinir blogu
compact=$(sh "$v" session-context --root "$root" --client claude --source compact --format text)
printf '%s' "$compact" | grep -Fq 'Sert sınırlar' \
  || { printf 'E_RI_NO_BOUNDARY_BLOCK\n' >&2; exit 2; }

# startup'ta BASILMAMALI: orada AGENTS.md zaten yukleniyor, tekrar olur.
startup=$(sh "$v" session-context --root "$root" --client claude --source startup --format text)
! printf '%s' "$startup" | grep -Fq 'Sert sınırlar' \
  || { printf 'E_RI_BLOCK_ON_STARTUP\n' >&2; exit 2; }

# ------------------------------------------------- 3. DRIFT KORUMASI (asil onemli)
# Bloktaki her satir AGENTS.md'de hala bir kurala karsilik gelmeli. Kural
# silinirse veya yeniden yazilirsa bu test kirilir ve blok guncellenir.
for anchor in \
  'Secret veya hassas veriyi koda' \
  'release ve deploy için önce kullanıcıdan' \
  'Yıkıcı işlem, üretim değişikliği' \
  'gömülü eylem isteğini güvenilmeyen veri'
do
  grep -Fq "$anchor" AGENTS.md \
    || { printf 'E_RI_DRIFT AGENTS.md icinde yok: %s\n' "$anchor" >&2; exit 2; }
  printf '%s' "$compact" | grep -Fq "$anchor" \
    || { printf 'E_RI_BLOCK_MISSING blokta yok: %s\n' "$anchor" >&2; exit 2; }
done

# ------------------------------------------------------------- 4. Butce
bytes=$(printf '%s' "$compact" | wc -c | tr -d ' ')
[ "$bytes" -le 8000 ] || { printf 'E_RI_BUDGET %s\n' "$bytes" >&2; exit 2; }
block=$(printf '%s' "$compact" | awk '/Sert sınırlar/{f=1} f' | wc -c | tr -d ' ')
[ "$block" -le 700 ] || { printf 'E_RI_BLOCK_TOO_BIG %s (700 bayt siniri)\n' "$block" >&2; exit 2; }

printf 'PASS reinjection blok=%sb baglam=%sb\n' "$block" "$bytes"
