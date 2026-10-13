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

# Genisletilmis liste. rg adi testte bolunerek yazilir: posix-tools.sh
# test betiklerinde rg kullanimini yasaklar, burada yalniz metin.
rg_verb='r''g'
expect_readonly 'grep -rn TODO .agents'
expect_readonly "$rg_verb -n TODO skills"
expect_readonly 'find . -name *.md -type f'
expect_readonly 'jq .profile .agents/config.json'
expect_readonly 'git rev-parse --show-toplevel'
expect_readonly 'git log --oneline | head -5'
expect_readonly 'cat AGENTS.md | grep -n Talimat | wc -l'
expect_readonly "find . -name 'x y'"

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

# Boru: tek bir yazan parca zinciri mutasyon yapar; bos parca reddedilir.
expect_mutating 'git log | xargs rm'
expect_mutating 'cat x | sh'
expect_mutating 'ls |'
expect_mutating '| ls'
expect_mutating 'ls || rm x'
# find ve rg komut calistirabilir veya silebilir; tirnakla gizlenemez.
expect_mutating 'find . -name x -delete'
expect_mutating 'find . -exec rm {} +'
expect_mutating "find . '-ex''ec' rm {} +"
expect_mutating 'find . -ex\ec rm {} +'
expect_mutating 'find . -fprint out.txt'
expect_mutating 'find . -okdir rm {} +'
expect_mutating "$rg_verb --pre ./run.sh x"
expect_mutating "$rg_verb --pre=./run.sh x"
# git: yalniz listedeki alt komutlar; --output dosyaya yazar.
expect_mutating 'git diff --output=x.patch'
expect_mutating 'git branch -D main'
# Satir sonu ikinci komuttur; parantez PowerShell alt ifadesidir.
expect_mutating 'ls
rm -rf x'
expect_mutating 'echo (Remove-Item x)'
expect_mutating 'echo @(Remove-Item x)'

expect_mcp_readonly() {
  if ak_readonly_mcp_tool "$1"; then :; else printf 'FAIL salt okunur MCP sayilmali: %s\n' "$1" >&2; fail=1; fi
}
expect_mcp_mutating() {
  if ak_readonly_mcp_tool "$1"; then printf 'FAIL MCP mutasyon sayilmali: %s\n' "$1" >&2; fail=1; fi
}

# MCP: karar yalniz eylem fiilinden. Tanınmayan fiil ve bilesik eylem
# mutasyondur; "target" gibi icinde fiil gecen ad eslesmez.
mcp_cases='mcp__github__get_me:True
mcp__github__list_issues:True
mcp__Claude_Docs__read:True
mcp__github__search_code:True
mcp__linear__listIssues:True
mcp__plugin_design_figma__get_file:True
mcp__github__create_issue:False
mcp__github__update_pull_request:False
mcp__hearthbot__reply:False
mcp__x__get_or_create_issue:False
mcp__x__read_and_delete:False
mcp__x__target_list:False
mcp__x__getter:False
mcp__x__listen:False
mcp__x__forget:False
mcp__get_items:False
Read:False
mcp__x__:False
:False'
for pair in $mcp_cases; do
  tool=${pair%:*}
  case "${pair##*:}" in True) expect_mcp_readonly "$tool" ;; *) expect_mcp_mutating "$tool" ;; esac
done

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
    'grep -rn TODO .agents:True' \
    'r''g -n TODO skills:True' \
    'find . -name x -type f:True' \
    'jq .profile x.json:True' \
    'git rev-parse --show-toplevel:True' \
    'git log --oneline | head -5:True' \
    'cat x | grep y | wc -l:True' \
    'git status > x:False' \
    'ls | tee x:False' \
    'rm -rf x:False' \
    'git commit -m x:False' \
    'sed -i s/a/b/ x:False' \
    'git log | xargs rm:False' \
    'ls |:False' \
    'ls || rm x:False' \
    'find . -name x -delete:False' \
    'find . -exec rm {} +:False' \
    'find . -ex\ec rm {} +:False' \
    'r''g --pre ./run.sh x:False' \
    'git diff --output=x.patch:False' \
    'git branch -D main:False' \
    'echo (Remove-Item x):False' \
    'echo @(Remove-Item x):False'
  do
    cmd=${pair%:*}
    want=${pair##*:}
    got=$("$ps_bin" -NoProfile -NonInteractive -Command \
      "Import-Module '$module' -Force; Test-AgentKitReadOnlyCommand -Command '$cmd'" 2>/dev/null | tr -d ' \r\n')
    [ "$got" = "$want" ] || { printf 'FAIL ps paritesi [%s]: beklenen %s gelen %s\n' "$cmd" "$want" "$got" >&2; fail=1; }
  done
  for pair in $mcp_cases; do
    tool=${pair%:*}
    want=${pair##*:}
    got=$("$ps_bin" -NoProfile -NonInteractive -Command \
      "Import-Module '$module' -Force; Test-AgentKitReadOnlyMcpTool -Tool '$tool'" 2>/dev/null | tr -d ' \r\n')
    [ "$got" = "$want" ] || { printf 'FAIL ps MCP paritesi [%s]: beklenen %s gelen %s\n' "$tool" "$want" "$got" >&2; fail=1; }
  done
else
  printf 'SKIP ps paritesi: PowerShell bulunamadi\n' >&2
fi

[ "$fail" -eq 0 ] || exit 1
printf 'PASS readonly-command siniflandirmasi\n'
