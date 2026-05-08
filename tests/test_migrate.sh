#!/usr/bin/env bash
# Tests for bin/migrate-customizations.sh
# Usage: tests/test_migrate.sh
#
# Each test sets up a sandbox HOME and DOTFILES, runs the helper, and
# asserts on exit code + output. Failing tests cause the script to exit 1.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
HELPER="$DOTFILES/bin/migrate-customizations.sh"

pass=0
fail=0
fail_test() { echo "FAIL: $1"; fail=$((fail+1)); }
pass_test() { echo "PASS: $1"; pass=$((pass+1)); }

# Each test runs in its own sandbox HOME.
_ORIG_HOME="$HOME"
SANDBOX=""
make_sandbox() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX"
}
cleanup_sandbox() {
  rm -rf "$SANDBOX"
  export HOME="$_ORIG_HOME"
}

# --- Test 1: missing backup file → exit 1 with clear message ---
test_missing_backup() {
  make_sandbox
  if output=$("$HELPER" 2>&1); then
    fail_test "missing backup: expected exit 1, got 0. output: $output"
  else
    if echo "$output" | grep -q "no backup file found"; then
      pass_test "missing backup: clear error message"
    else
      fail_test "missing backup: exit 1 but wrong message: $output"
    fi
  fi
  cleanup_sandbox
}

# --- Run all tests ---
test_missing_backup

echo
echo "=== $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]
