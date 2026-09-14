#!/bin/sh
set -u

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
test_root="$project_root/.agents/tests"
results="$test_root/results/unix.tsv"
runtime_root="$project_root/.agents/runtime"
mkdir -p "$test_root/results" "$runtime_root"
run_tmp=$(mktemp -d "$runtime_root/test-run.XXXXXX") || {
  printf 'FAIL temporary results directory could not be created\n' >&2
  exit 3
}
results_tmp="$run_tmp/unix.tsv"
cleanup_results_tmp() {
  case ${run_tmp:-} in
    "$runtime_root"/test-run.*)
      for temp_file in "$run_tmp"/*.tsv; do
        [ ! -e "$temp_file" ] || rm -f -- "$temp_file"
      done
      rmdir -- "$run_tmp" 2>/dev/null || true
      ;;
  esac
  case ${isolated_home:-} in
    "$runtime_root"/test-home.*) rm -rf -- "$isolated_home" ;;
  esac
}
trap cleanup_results_tmp EXIT HUP INT TERM

# Dogrulayici artik kullanici Claude ve Codex yapilandirmasina da bakiyor. Sonuc
# gelistiricinin makinesinde plugin kurulu olup olmamasina gore degismesin diye
# butun kosum yalitilmis ve bos bir yapilandirma dizini kullanir. Tek tek
# kaynaklari sinayan test kendi degerini onune yazar.
isolated_home=$(mktemp -d "$runtime_root/test-home.XXXXXX") || {
  printf 'FAIL isolated Claude config directory could not be created\n' >&2
  exit 3
}
CLAUDE_CONFIG_DIR=$isolated_home
CODEX_HOME=$isolated_home
export CLAUDE_CONFIG_DIR CODEX_HOME

cd "$project_root" || exit 3

static_index=0
for test in "$test_root"/static/*.sh; do
  static_index=$((static_index + 1))
  static_row=$(printf '%s/static-%03d.tsv' "$run_tmp" "$static_index")
  name=$(basename -- "$test")
  if output=$(sh "$test" "$project_root" 2>&1); then
    printf 'static:%s\tPASS\tPASS\t%s\n' "$name" ".agents/tests/static/$name" > "$static_row"
  else
    code=$?
    printf 'static:%s\tFAIL\texit-%s\t%s\n' "$name" "$code" ".agents/tests/static/$name" > "$static_row"
    printf '%s\n' "$output" >&2
  fi
done

expected_static=$(find "$test_root/static" -type f -name '*.sh' -print | awk 'NF {n++} END {print n+0}')
actual_static=$(find "$run_tmp" -type f -name 'static-*.tsv' -print | awk 'NF {n++} END {print n+0}')
[ "$actual_static" -eq "$expected_static" ] || { printf 'FAIL static result completeness expected=%s actual=%s\n' "$expected_static" "$actual_static" >&2; exit 2; }

while IFS="$(printf '\t')" read -r id name fixture class profile expected; do
  [ "$id" = id ] && continue
  [ -n "$id" ] || continue
  case_row=$(printf '%s/case-%s.tsv' "$run_tmp" "$id")
  row=''
  if row=$(sh "$test_root/lib/run-case.sh" "$project_root" "$id" "$test_root/fixtures/acceptance/$fixture" "$class" "$profile" "$expected"); then
    printf '%s\n' "$row" > "$case_row"
  else
    code=$?
    if [ -n "$row" ]; then printf '%s\n' "$row" > "$case_row"; else printf '%s\tFAIL\texit-%s\t%s\n' "$id" "$code" "$fixture" > "$case_row"; fi
  fi
done < "$test_root/scenarios/cases.tsv"

expected_cases=$(awk -F '\t' 'NR > 1 && NF {n++} END {print n+0}' "$test_root/scenarios/cases.tsv")
actual_cases=$(find "$run_tmp" -type f -name 'case-*.tsv' -print | awk 'NF {n++} END {print n+0}')
[ "$actual_cases" -eq "$expected_cases" ] || { printf 'FAIL case result completeness expected=%s actual=%s\n' "$expected_cases" "$actual_cases" >&2; exit 2; }

{
  printf 'id\tstatus\tobserved\tevidence\n'
  for row_file in "$run_tmp"/static-*.tsv "$run_tmp"/case-*.tsv; do
    [ -f "$row_file" ] || continue
    cat -- "$row_file"
  done
} > "$results_tmp"

actual_rows=$(awk 'NR > 1 {n++} END {print n+0}' "$results_tmp")
expected_rows=$((expected_static + expected_cases))
[ "$actual_rows" -eq "$expected_rows" ] || { printf 'FAIL result completeness expected=%s actual=%s\n' "$expected_rows" "$actual_rows" >&2; exit 2; }

mv -- "$results_tmp" "$results"
cleanup_results_tmp
if [ -d "$run_tmp" ]; then
  printf 'FAIL temporary results directory could not be removed: %s\n' "$run_tmp" >&2
  exit 3
fi
run_tmp=''
results_tmp=''

if awk -F '\t' 'NR > 1 && ($2 == "FAIL" || $2 == "BLOCKED") { found=1 } END { exit !found }' "$results"; then
  printf 'FAIL acceptance; ayrıntı: %s\n' "$results" >&2
  exit 2
fi

awk -F '\t' 'NR > 1 {count[$2]++} END {printf "PASS acceptance"; for (key in count) printf " %s=%d", key, count[key]; printf "\n"}' "$results"
exit 0
