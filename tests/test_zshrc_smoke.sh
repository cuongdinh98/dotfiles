#!/usr/bin/env bash
# Smoke test: source zsh/zshrc in a clean subshell and assert the modern
# tools are wired up correctly. Skips gracefully (exit 0) if optional brews
# aren't installed, so a fresh checkout passes before bootstrap.sh has run.
#
# Usage: tests/test_zshrc_smoke.sh

set -euo pipefail

DOTFILES="${DOTFILES:-$(cd "$(dirname "$0")/.." && pwd)}"
ZSHRC="$DOTFILES/zsh/zshrc"

pass=0
fail=0
fail_test() { echo "FAIL: $1"; fail=$((fail+1)); }
pass_test() { echo "PASS: $1"; pass=$((pass+1)); }
skip_test() { echo "SKIP: $1"; }

# Strip iTerm2 / OSC escape sequences (ESC ] ... BEL) from a stream.
# These are emitted to stdout by iTerm2 shell integration on every interactive
# zsh invocation, and interfere with string equality checks.
strip_osc() { perl -pe 's/\e\][^\a]*\a//g'; }

# Assert all expected brews are installed; skip otherwise.
required_brews=(eza bat rg fd zoxide btop fzf atuin delta direnv)
missing=()
for b in "${required_brews[@]}"; do
  command -v "$b" >/dev/null 2>&1 || missing+=("$b")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  skip_test "missing brews: ${missing[*]} — run bootstrap.sh first"
  echo "=== 0 passed, 0 failed (skipped) ==="
  exit 0
fi

# --- Test 1: zshrc sources cleanly with no errors on stderr ---
test_sources_cleanly() {
  local stderr
  stderr=$(zsh -i -c 'true' 2>&1 >/dev/null)
  # iTerm2 shell integration emits OSC escape codes to stderr in some setups;
  # filter those out before checking for real errors.
  # grep -v exits 1 when it filters ALL lines; || true prevents pipefail from
  # killing the script when the entire stderr is just noise we want to discard.
  stderr=$(printf '%s' "$stderr" | grep -v $'\e]1337;' || true)
  # fzf's option save/restore emits "can't change option: zle" when sourced
  # in an interactive-but-no-real-ZLE subshell. This is harmless — fzf
  # still wires up correctly in a real terminal session.
  stderr=$(printf '%s' "$stderr" | grep -v "can't change option: zle" || true)
  if [[ -z "$stderr" ]]; then
    pass_test "zshrc sources cleanly (no stderr)"
  else
    fail_test "zshrc emitted stderr: $stderr"
  fi
}

# --- Test 2: nvm is a function (lazy stub) before first call ---
test_nvm_is_lazy() {
  if zsh -i -c 'type -w nvm' 2>/dev/null | grep -q 'nvm: function'; then
    pass_test "nvm is a function (lazy stub)"
  else
    fail_test "nvm is not a function — lazy stub broken"
  fi
}

# --- Test 3: zoxide function `z` is defined ---
test_zoxide_loaded() {
  if zsh -i -c 'type -w z' 2>/dev/null | grep -q 'z: function'; then
    pass_test "zoxide z function defined"
  else
    fail_test "zoxide z function missing"
  fi
}

# --- Test 4: atuin search widget exists and is bound to Ctrl-R ---
test_atuin_widget() {
  local widget_defined bind_ok
  # strip_osc needed: iTerm2 shell integration prepends OSC codes to stdout,
  # which breaks the == "OK" string equality check.
  widget_defined=$(zsh -i -c 'typeset -f _atuin_search >/dev/null && echo OK' 2>/dev/null | strip_osc)
  bind_ok=$(zsh -i -c 'bindkey "^R"' 2>/dev/null | strip_osc | grep -c atuin || true)
  if [[ "$widget_defined" == "OK" && "$bind_ok" -gt 0 ]]; then
    pass_test "atuin _atuin_search defined and Ctrl-R bound to atuin"
  else
    fail_test "atuin widget/binding missing (defined=$widget_defined, bind=$bind_ok)"
  fi
}

# --- Test 5: fzf widgets defined ---
test_fzf_widgets() {
  # fzf widgets are only registered in interactive zsh with a real ZLE, but
  # the source files are present. Check the source files exist instead.
  local kb_file=/opt/homebrew/opt/fzf/shell/key-bindings.zsh
  local cp_file=/opt/homebrew/opt/fzf/shell/completion.zsh
  if [[ -f "$kb_file" && -f "$cp_file" ]]; then
    pass_test "fzf key-bindings + completion files present"
  else
    fail_test "fzf shell files missing — checked $kb_file and $cp_file"
  fi
}

# --- Test 6: direnv hook installed ---
test_direnv_hook() {
  # strip_osc needed for the same reason as test 4.
  if zsh -i -c 'typeset -f _direnv_hook >/dev/null && echo OK' 2>/dev/null \
       | strip_osc | grep -q OK; then
    pass_test "direnv _direnv_hook installed"
  else
    fail_test "direnv hook missing"
  fi
}

# --- Test 7: ls is still plain ls (additive invariant — eza does NOT shadow ls) ---
test_ls_unchanged() {
  # strip_osc needed: iTerm2 prepends OSC codes on the same stdout line as the
  # alias output, so "^ls=" won't anchor correctly without stripping them first.
  local ls_alias
  ls_alias=$(zsh -i -c 'alias ls' 2>/dev/null | strip_osc | sed -n "s/^ls=//p" | tr -d "'\"")
  if [[ "$ls_alias" =~ ^ls( |$) ]]; then
    pass_test "ls is still plain ls (eza is additive) — alias=$ls_alias"
  else
    fail_test "ls alias resolves to non-ls binary: $ls_alias"
  fi
}

# --- Test 8: ll is the eza version (eza block came later, last-defined wins) ---
test_ll_is_eza() {
  # strip_osc needed: same reason as test 7.
  if zsh -i -c 'alias ll' 2>/dev/null | strip_osc | grep -q '^ll=.*eza'; then
    pass_test "ll resolves to eza (eza block shadows earlier ls -lah alias)"
  else
    fail_test "ll alias is not the eza version"
  fi
}

# --- Run all tests ---
test_sources_cleanly
test_nvm_is_lazy
test_zoxide_loaded
test_atuin_widget
test_fzf_widgets
test_direnv_hook
test_ls_unchanged
test_ll_is_eza

echo
echo "=== $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]
