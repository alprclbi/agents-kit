#!/bin/sh
set -eu
root=${1:-"$(pwd)"}
cd "$root"

# TUM METIN DOSYALARI LF OLMALI.
#
# 2026-09-08: `.agents/validators/policy-codes.json` ve
# `.claude/settings.json` diskte CRLF idi ve manifest onlarin CRLF
# hash'ini kaydetmisti. .gitattributes klonda LF'e cevirdigi icin
# `manifest --check` KLONLAYAN HERKESTE duserdi. Gelistiricide
# gorunmeyen, kullanicida patlayan tipte bir hata.
#
# Ayrica CRLF'e cevrilen kabuk betikleri Linux/macOS'ta `\r` hatasi verir.
#
# NOT: `grep $'\r'` KULLANMA. POSIX sh ANSI-C tirnaklamayi yorumlamaz,
# desen bos kalir ve HER dosya eslesir. Bu hata gelistirme sirasinda uc
# kez yapildi ve her seferinde yanlis sonuca goturdu. CR once printf ile
# uretilir.
CR=$(printf '\r')

# Git varsa izlenen dosyalar, yoksa kit agaci taranir.
if command -v git >/dev/null 2>&1 && [ -d .git ]; then
  list=$(git ls-files)
else
  # Git yoksa (ZIP dagitimi) kit agaci taranir. Plugin dizinleri de
  # listede olmali; yoksa paket icindeki CRLF sizintisi gorulmez.
  list=$(find AGENTS.md CLAUDE.md README.md install.sh install.ps1 \
              .agents .claude .codex .claude-plugin .codex-plugin skills hooks \
              -type f 2>/dev/null || true)
fi

hits=''
for f in $list; do
  [ -f "$f" ] || continue
  case "$f" in *.png|*.jpg|*.pdf|*.zip) continue ;; esac
  if LC_ALL=C grep -qU "$CR" "$f" 2>/dev/null; then
    hits="$hits$f
"
  fi
done

if [ -n "$hits" ]; then
  printf 'E_CRLF asagidaki dosyalar CRLF iceriyor:\n%s' "$hits" >&2
  printf 'Duzelt: CR karakterlerini sil (tr -d), sonra manifesti yeniden uret.\n' >&2
  exit 2
fi

n=$(printf '%s\n' "$list" | grep -c . || true)
printf 'PASS line-endings %s dosya, hepsi LF\n' "$n"
