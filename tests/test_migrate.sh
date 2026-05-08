#!/usr/bin/env bash
# Tests for bin/migrate-customizations.sh
# Usage: tests/test_migrate.sh
#
# Each test sets up a sandbox HOME and DOTFILES, runs the helper, and
# asserts on exit code + output. Failing tests cause the script to exit 1.

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
export DOTFILES
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

# --- Test 2: extracts alias / export / bindkey lines from a backup ---
test_extract_simple() {
  make_sandbox
  cat > "$HOME/.zshrc.backup.20990101-000000" <<'BACKUP'
alias gp="git push"
export PATH="$HOME/scripts:$PATH"
bindkey -s '^[g' 'git status\n'
# a comment alone — should not be extracted
BACKUP
  # Pipe "n" so the prompt doesn't actually write — we just want to see candidates.
  output=$(printf 'n\n' | "$HELPER" 2>&1 || true)
  if echo "$output" | grep -q 'gp="git push"' \
     && echo "$output" | grep -q 'PATH="$HOME/scripts' \
     && echo "$output" | grep -q "bindkey -s" \
     && ! echo "$output" | grep -q 'a comment alone' \
     && echo "$output" | grep -q "No changes made"
  then
    pass_test "extract: alias/export/bindkey shown, comments skipped"
  else
    fail_test "extract: missing or wrong candidates. output: $output"
  fi
  cleanup_sandbox
}

# --- Test 3: lines already present in public zshrc are filtered out ---
test_dedup_against_public() {
  make_sandbox
  # Use the actual public zshrc (which has `alias ll="ls -lah"`).
  cat > "$HOME/.zshrc.backup.20990101-000001" <<'BACKUP'
alias ll="ls -lah"
alias gp="git push"
BACKUP
  output=$(printf 'n\n' | "$HELPER" 2>&1 || true)
  # gp should appear, ll should NOT (it's in public zshrc).
  if echo "$output" | grep -q 'gp="git push"' \
     && ! echo "$output" | grep -q 'alias ll=' \
     && echo "$output" | grep -q "No changes made"
  then
    pass_test "dedup: filters lines already in public zshrc"
  else
    fail_test "dedup: wrong filtering. output: $output"
  fi
  cleanup_sandbox
}

# --- Run all tests ---
test_missing_backup
test_extract_simple
test_dedup_against_public

echo
echo "=== $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]
