#!/bin/sh
set -eu
. "$(dirname "$0")/slugify.sh"
fail=0
check() {
  got=$(slugify "$1")
  if [ "$got" = "$2" ]; then
    printf 'ok   %-24s -> %s\n' "$1" "$got"
  else
    printf 'FAIL %-24s -> %s (beklenen %s)\n' "$1" "$got" "$2"; fail=1
  fi
}
check 'Hello World'        'hello-world'
check '  spaced  out  '    'spaced-out'
check 'UPPER_case'         'upper-case'
check 'a--b'               'a-b'
check 'trailing---'        'trailing'
check ''                   ''
exit $fail
