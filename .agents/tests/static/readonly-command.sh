#!/bin/sh
set -eu
root=$1
. "$root/.agents/validators/sh/lib.sh"

fail=0
expect_readonly() {
  if ak_readonly_command "$1"; then :; else printf 'FAIL salt okunur sayilmali: %s\n' "$1" >&2; fail=1; fi
}
expect_mutating() {
  if ak_readonly_command "$1"; then printf 'FAIL mutasyon sayilmali: %s\n' "$1" >&2; fail=1; fi
}

expect_readonly 'git status --short'
expect_readonly 'git log --oneline'
expect_readonly 'git diff HEAD'
expect_readonly 'ls -la'
expect_readonly 'cat AGENTS.md'
expect_readonly 'echo test'
expect_readonly 'wc -l AGENTS.md'
expect_readonly 'pwd'

expect_mutating 'git status > out.txt'
expect_mutating 'cat a.txt >> b.txt'
expect_mutating 'ls | tee x'
expect_mutating 'echo hi && rm -rf /'
expect_mutating 'echo $(rm x)'
expect_mutating 'rm -rf .agents'
expect_mutating 'git commit -m x'
expect_mutating 'git push'
expect_mutating 'sed -i s/a/b/ x'
expect_mutating 'cat < x'
expect_mutating 'echo ${HOME}'
expect_mutating ''

# PowerShell paritesi: ayni komut ayni sonucu vermeli.
ps_bin=$(command -v pwsh 2>/dev/null || command -v powershell 2>/dev/null || true)
if [ -n "$ps_bin" ]; then
  # PowerShell MSYS yolunu (/d/...) anlamaz; varsa Windows yoluna cevir.
  module="$root/.agents/validators/ps/AgentKit.psm1"
  if command -v cygpath >/dev/null 2>&1; then
    module=$(cygpath -w "$module")
  fi
  for pair in \
    'git status:True' \
    'git log --oneline:True' \
    'ls -la:True' \
    'cat AGENTS.md:True' \
    'echo test:True' \
    'pwd:True' \
    'git status > x:False' \
    'ls | tee x:False' \
    'rm -rf x:False' \
    'git commit -m x:False' \
    'sed -i s/a/b/ x:False'
  do
    cmd=${pair%:*}
    want=${pair##*:}
    got=$("$ps_bin" -NoProfile -NonInteractive -Command \
      "Import-Module '$module' -Force; Test-AgentKitReadOnlyCommand -Command '$cmd'" 2>/dev/null | tr -d ' \r\n')
    [ "$got" = "$want" ] || { printf 'FAIL ps paritesi [%s]: beklenen %s gelen %s\n' "$cmd" "$want" "$got" >&2; fail=1; }
  done
else
  printf 'SKIP ps paritesi: PowerShell bulunamadi\n' >&2
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS readonly-command siniflandirmasi\n'
