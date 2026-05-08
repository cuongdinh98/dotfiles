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

# --- Test 4: multi-line function declarations get a REVIEW marker ---
test_multiline_review() {
  make_sandbox
  cat > "$HOME/.zshrc.backup.20990101-000002" <<'BACKUP'
alias gp="git push"
my_helper() {
  echo hi
}
BACKUP
  output=$(printf 'n\n' | "$HELPER" 2>&1 || true)
  # After Fix 1 the REVIEW line is "# REVIEW: <path>:<lineno>" only —
  # the function name no longer appears in the marker itself.
  if echo "$output" | grep -qE "REVIEW:.*\.zshrc\.backup\.[^:]+:[0-9]+$"; then
    pass_test "review: multi-line function flagged"
  else
    fail_test "review: missing marker. output: $output"
  fi
  cleanup_sandbox
}

# --- Test 5: 'y' answer appends to ~/.zshrc.local with header ---
test_append_to_local() {
  make_sandbox
  cat > "$HOME/.zshrc.backup.20990101-000003" <<'BACKUP'
alias gp="git push"
BACKUP
  output=$(printf 'y\n' | "$HELPER" 2>&1 || true)
  if [[ -f "$HOME/.zshrc.local" ]] \
     && grep -q 'alias gp="git push"' "$HOME/.zshrc.local" \
     && grep -q 'Migrated from' "$HOME/.zshrc.local"
  then
    pass_test "append: ~/.zshrc.local created with content + header"
  else
    fail_test "append: missing file or content. output: $output; local: $(cat "$HOME/.zshrc.local" 2>&1 || echo missing)"
  fi
  cleanup_sandbox
}

# --- Test 6: backup with no migratable lines exits 0 cleanly ---
test_empty_backup() {
  make_sandbox
  cat > "$HOME/.zshrc.backup.20990101-000004" <<'BACKUP'
# only a comment
BACKUP
  if output=$("$HELPER" 2>&1); then
    if echo "$output" | grep -q "No migratable customizations found"; then
      pass_test "empty: exit 0, clear message, no ~/.zshrc.local created"
    else
      fail_test "empty: exit 0 but wrong output: $output"
    fi
  else
    fail_test "empty: expected exit 0, got non-zero. output: $output"
  fi
  if [[ -f "$HOME/.zshrc.local" ]]; then
    fail_test "empty: ~/.zshrc.local should not have been created"
  fi
  cleanup_sandbox
}

# --- Test 7: backup with ONLY multi-line constructs exits 0 with hint ---
test_only_multiline() {
  make_sandbox
  cat > "$HOME/.zshrc.backup.20990101-000005" <<'BACKUP'
my_func() {
  echo hi
}
BACKUP
  if output=$("$HELPER" 2>&1 < /dev/null); then
    if echo "$output" | grep -qE "REVIEW:.*\.zshrc\.backup\.[^:]+:[0-9]+$" \
       && echo "$output" | grep -q "Nothing to append automatically"
    then
      pass_test "only-multiline: REVIEW shown, exits 0 with hint"
    else
      fail_test "only-multiline: wrong output: $output"
    fi
  else
    fail_test "only-multiline: expected exit 0, got non-zero: $output"
  fi
  if [[ -f "$HOME/.zshrc.local" ]]; then
    fail_test "only-multiline: ~/.zshrc.local should not have been created"
  fi
  cleanup_sandbox
}

# --- Run all tests ---
test_missing_backup
test_extract_simple
test_dedup_against_public
test_multiline_review
test_append_to_local
test_empty_backup
test_only_multiline

echo
echo "=== $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]
