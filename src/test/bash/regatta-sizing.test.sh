#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/main/resources/com/rustyrazorblade/easydblab/kits/regatta/lib/regatta-sizing.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../../main/resources/com/rustyrazorblade/easydblab/kits/regatta/lib/regatta-sizing.sh"

tests_run=0
tests_failed=0

assert_rdb_threads() {
  local description="$1"
  local expected="$2"
  local actual
  actual="$(regatta_rdb_threads "$3" "$4" "$5" "$6")"
  tests_run=$((tests_run + 1))

  if [[ "$actual" == "$expected" ]]; then
    echo "ok   - ${description} (rdb_threads=${actual})"
  else
    echo "FAIL - ${description}: expected rdb_threads=${expected}, got ${actual}"
    tests_failed=$((tests_failed + 1))
  fi
}

assert_rdb_threads "single DB node with app node uses all CPU remaining after SM" 12 16 4 1 1
assert_rdb_threads "single DB node without app node retains conservative allocation" 8 16 4 1 0
assert_rdb_threads "multiple DB nodes give each RDB the full DB-node CPU" 16 16 4 2 1
assert_rdb_threads "low-core single DB node without app node retains minimum allocation" 1 4 4 1 0

echo
echo "${tests_run} tests, ${tests_failed} failed"
[[ "$tests_failed" -eq 0 ]]
