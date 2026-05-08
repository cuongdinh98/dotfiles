# Personal customization layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make this public dotfiles repo safe for first-time installers — give them `~/.zshrc.local` as a personal layer, a migration helper to move existing customizations into it, and a loud bootstrap notice so customizations aren't lost silently. Strip personal content from the public zshrc/Brewfile.

**Architecture:** Two-layer model. Public layer = `zsh/zshrc` in this repo, common to everyone. Personal layer = `~/.zshrc.local`, owned by the user, sourced at the end of the public zshrc, never touched by `bootstrap.sh`. New `bin/migrate-customizations.sh` helper extracts single-line aliases / exports / bindkeys / single-line functions from a backup file into `~/.zshrc.local`, filtering out lines already present verbatim in the public zshrc.

**Tech Stack:** Bash, Zsh. No new dependencies.

**Spec:** [`docs/superpowers/specs/2026-05-08-personal-customization-layer-design.md`](../specs/2026-05-08-personal-customization-layer-design.md)

---

### Task 1: Add `~/.zshrc.local` source line to the public zshrc

**Files:**
- Modify: `zsh/zshrc` (append a new block at the end)

- [ ] **Step 1: Confirm the source line is absent today**

Run:
```sh
grep -c 'zshrc\.local' /Users/dinhduycuong/dotfiles/zsh/zshrc
```
Expected: `0`

- [ ] **Step 2: Verify behavior — a fresh `~/.zshrc.local` is NOT sourced today (this is our failing test)**

Run:
```sh
mv "$HOME/.zshrc.local" "$HOME/.zshrc.local.preplan" 2>/dev/null || true
echo 'export ZSHRC_LOCAL_LOADED_TEST=YES' > "$HOME/.zshrc.local"
zsh -i -c 'echo "loaded=${ZSHRC_LOCAL_LOADED_TEST:-NO}"'
```
Expected: `loaded=NO` (line is currently NOT sourced).

- [ ] **Step 3: Append the source block to `zsh/zshrc`**

Append to `zsh/zshrc` (after the existing iTerm2 shell-integration line):
```sh

# --- Personal customizations (not tracked by this repo) ---
# Put your aliases / exports / functions in ~/.zshrc.local. bootstrap.sh
# never touches that file. See README "Personal customizations".
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
```

- [ ] **Step 4: Verify behavior — a fresh `~/.zshrc.local` IS now sourced (test passes)**

Run:
```sh
zsh -i -c 'echo "loaded=${ZSHRC_LOCAL_LOADED_TEST:-NO}"'
```
Expected: `loaded=YES`

- [ ] **Step 5: Verify the missing-file case is silent**

Run:
```sh
rm -f "$HOME/.zshrc.local"
zsh -i -c 'echo ok' 2>&1 | tail -5
```
Expected: ends with `ok`, no error about missing file.

- [ ] **Step 6: Restore the user's prior `~/.zshrc.local`, if any**

Run:
```sh
[ -f "$HOME/.zshrc.local.preplan" ] && mv "$HOME/.zshrc.local.preplan" "$HOME/.zshrc.local"
echo done
```
Expected: `done` (and any prior file restored).

- [ ] **Step 7: Commit**

```sh
git add zsh/zshrc
git commit -m "feat(zsh): source ~/.zshrc.local for personal customizations"
```

---

### Task 2: Remove personal content from the public zshrc

**Files:**
- Modify: `zsh/zshrc:3-4` (delete two PATH lines)
- Modify: `zsh/zshrc:38-39` (delete two SSH alias lines)

- [ ] **Step 1: Confirm the personal lines are present today**

Run:
```sh
grep -nE '(sshToTh10|Qt/6\.9\.1|openjdk@17)' /Users/dinhduycuong/dotfiles/zsh/zshrc
```
Expected: 4 matches (lines 3, 4, 38, 39).

- [ ] **Step 2: Delete the Qt PATH line (line 3)**

In `zsh/zshrc`, delete the exact line:
```
export PATH="$HOME/Qt/6.9.1/macos/bin:$PATH"
```

- [ ] **Step 3: Delete the openjdk@17 PATH line (line 4)**

In `zsh/zshrc`, delete the exact line:
```
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"  # Garmin Connect IQ SDK requires Java
```

- [ ] **Step 4: Delete the two SSH aliases (lines 38-39)**

In `zsh/zshrc`, delete the exact lines:
```
alias sshToTh10="ssh dinhd@193.55.164.41"
alias sshToTh10ForParaview="ssh -L 1111:localhost:1111 dinhd@193.55.164.28"
```

- [ ] **Step 5: Verify removal succeeded**

Run:
```sh
grep -cE '(sshToTh10|Qt/6\.9\.1|openjdk@17)' /Users/dinhduycuong/dotfiles/zsh/zshrc
```
Expected: `0`

- [ ] **Step 6: Verify zsh still loads cleanly**

Run:
```sh
zsh -i -c 'echo ok'
```
Expected: `ok` (no errors).

- [ ] **Step 7: Commit**

```sh
git add zsh/zshrc
git commit -m "refactor(zsh): move personal aliases/PATHs out of public zshrc"
```

---

### Task 3: Drop personal package from Brewfile

**Files:**
- Modify: `Brewfile:10-11` (delete the `# Languages / runtimes` section, since openjdk@17 is its only entry)

- [ ] **Step 1: Confirm openjdk@17 is in Brewfile**

Run:
```sh
grep -n 'openjdk@17' /Users/dinhduycuong/dotfiles/Brewfile
```
Expected: 1 match at line 11.

- [ ] **Step 2: Remove both the section header and the openjdk@17 line**

In `Brewfile`, delete these two lines (and the empty line that separates this from the previous section, to avoid leaving a double blank):
```
# Languages / runtimes
brew "openjdk@17"
```

- [ ] **Step 3: Verify removal**

Run:
```sh
grep -c 'openjdk@17' /Users/dinhduycuong/dotfiles/Brewfile
```
Expected: `0`

- [ ] **Step 4: Verify Brewfile still parses**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && brew bundle list --file=Brewfile | head -5
```
Expected: lists remaining packages (`iterm2`, `starship`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `gh`) without errors.

- [ ] **Step 5: Commit**

```sh
git add Brewfile
git commit -m "chore(brew): drop openjdk@17 (Garmin SDK is user-specific)"
```

---

### Task 4: bootstrap.sh — track backups and print post-install notice

**Files:**
- Modify: `bootstrap.sh:9` (add BACKUPS array decl after TIMESTAMP)
- Modify: `bootstrap.sh:34-46` (append to BACKUPS inside `link()`)
- Modify: `bootstrap.sh:109-117` (replace the trailing notice with a backup-aware version)

- [ ] **Step 1: Failing test — verify the script currently doesn't mention the migration helper**

Run:
```sh
grep -c 'migrate-customizations' /Users/dinhduycuong/dotfiles/bootstrap.sh
```
Expected: `0`

- [ ] **Step 2: Add the BACKUPS array declaration**

In `bootstrap.sh`, after the line:
```
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
```
add:
```sh
BACKUPS=()  # entries: "<backup-path>|<source-symlink-target>"
```

- [ ] **Step 3: Push backup info into BACKUPS inside `link()`**

In `bootstrap.sh`, inside the `link()` function, locate this block:
```sh
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.backup.${TIMESTAMP}"
    mv "$dst" "$backup"
    warn "Existing $dst backed up to $backup"
  fi
```
Add a new line right after the `warn` line so it becomes:
```sh
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.backup.${TIMESTAMP}"
    mv "$dst" "$backup"
    warn "Existing $dst backed up to $backup"
    BACKUPS+=("${backup}|${src}")
  fi
```

- [ ] **Step 4: Replace the final notice block**

In `bootstrap.sh`, locate the final block that begins with:
```sh
echo
ok "Bootstrap complete."
cat <<'EOF'
```
and ends with `EOF`. Replace the **entire** block (including the `cat <<'EOF' ... EOF` heredoc) with:
```sh
echo
ok "Bootstrap complete."

if [[ ${#BACKUPS[@]} -gt 0 ]]; then
  echo
  warn "Pre-existing config files were backed up. Personal customizations"
  warn "are NOT in your active shell. Use the migration helper to move"
  warn "aliases / exports / bindkeys into ~/.zshrc.local (auto-sourced):"
  for entry in "${BACKUPS[@]}"; do
    backup="${entry%%|*}"
    printf "    %s/bin/migrate-customizations.sh %q\n" "$DOTFILES" "$backup"
  done
  warn "Or compare manually:"
  for entry in "${BACKUPS[@]}"; do
    backup="${entry%%|*}"
    src="${entry#*|}"
    printf "    diff %q %q\n" "$src" "$backup"
  done
fi

cat <<'EOF'

Next steps:
  1. Quit and relaunch iTerm2 so the Tokyo Night dynamic profile loads.
  2. Run:  exec zsh    (to pick up the new shell config in your current session)

EOF
```

- [ ] **Step 5: Syntax-check bootstrap.sh**

Run:
```sh
bash -n /Users/dinhduycuong/dotfiles/bootstrap.sh && echo OK
```
Expected: `OK`

- [ ] **Step 6: Unit-test the notice block in isolation**

Run:
```sh
bash -c '
  set -euo pipefail
  warn() { printf "!! %s\n" "$*"; }
  ok()   { printf "OK %s\n" "$*"; }
  DOTFILES=/repo
  BACKUPS=("/home/u/.zshrc.backup.test|/repo/zsh/zshrc")

  if [[ ${#BACKUPS[@]} -gt 0 ]]; then
    echo
    warn "Pre-existing config files were backed up. Personal customizations"
    warn "are NOT in your active shell. Use the migration helper to move"
    warn "aliases / exports / bindkeys into ~/.zshrc.local (auto-sourced):"
    for entry in "${BACKUPS[@]}"; do
      backup="${entry%%|*}"
      printf "    %s/bin/migrate-customizations.sh %q\n" "$DOTFILES" "$backup"
    done
  fi
'
```
Expected output contains a line like:
```
    /repo/bin/migrate-customizations.sh /home/u/.zshrc.backup.test
```

- [ ] **Step 7: Verify the empty-BACKUPS case prints no notice**

Run:
```sh
bash -c '
  warn() { printf "!! %s\n" "$*"; }
  BACKUPS=()
  if [[ ${#BACKUPS[@]} -gt 0 ]]; then warn "should not print"; fi
  echo done
'
```
Expected: just `done` (no `!!` line).

- [ ] **Step 8: Commit**

```sh
git add bootstrap.sh
git commit -m "feat(bootstrap): warn about backed-up configs + point to migration helper"
```

---

### Task 5: Migration helper script — skeleton, auto-detection, and missing-backup error

**Files:**
- Create: `bin/migrate-customizations.sh`
- Create: `tests/test_migrate.sh`

- [ ] **Step 1: Create the test fixture script with the FIRST test (helper missing → fail)**

Create `tests/test_migrate.sh`:
```sh
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
make_sandbox() {
  SANDBOX=$(mktemp -d)
  export HOME="$SANDBOX"
}
cleanup_sandbox() { rm -rf "$SANDBOX"; }

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
```

Make the test runnable:
```sh
chmod +x /Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```

- [ ] **Step 2: Run the test — expect FAIL because helper doesn't exist yet**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `FAIL: missing backup: ...` (or "command not found" → caught by exit-non-zero branch in the test).

- [ ] **Step 3: Create the helper skeleton with arg parsing + auto-detect + missing-backup error**

Create `bin/migrate-customizations.sh`:
```sh
#!/usr/bin/env bash
# migrate-customizations.sh — extract single-line customizations (aliases,
# exports, bindkeys, single-line functions) from a zshrc backup into
# ~/.zshrc.local. Filters out lines already present in the public zshrc.
#
# Usage: migrate-customizations.sh [backup-file]
#   If backup-file is omitted, the most recent ~/.zshrc.backup.* is used.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
ZSHRC_PUBLIC="$DOTFILES/zsh/zshrc"
ZSHRC_LOCAL="$HOME/.zshrc.local"

# 1. Resolve backup file
backup="${1:-}"
if [[ -z "$backup" ]]; then
  backup=$(ls -t "$HOME"/.zshrc.backup.* 2>/dev/null | head -1 || true)
fi
if [[ -z "$backup" || ! -f "$backup" ]]; then
  echo "no backup file found (looked for ~/.zshrc.backup.*)" >&2
  exit 1
fi

echo "Scanning $backup ..."
# Further logic added in subsequent tasks.
```

Make it executable:
```sh
chmod +x /Users/dinhduycuong/dotfiles/bin/migrate-customizations.sh
```

- [ ] **Step 4: Re-run the test — expect PASS**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `PASS: missing backup: clear error message` and `=== 1 passed, 0 failed ===`.

- [ ] **Step 5: Commit**

```sh
git add bin/migrate-customizations.sh tests/test_migrate.sh
git commit -m "feat(migrate): skeleton + missing-backup error path"
```

---

### Task 6: Migration helper — pattern extraction and dedup against public zshrc

**Files:**
- Modify: `bin/migrate-customizations.sh` (extend with extraction + filter)
- Modify: `tests/test_migrate.sh` (add tests for extraction + dedup)

- [ ] **Step 1: Add a failing test for extraction (alias/export/bindkey lines should appear in dry-run output)**

In `tests/test_migrate.sh`, add this test function before the `# --- Run all tests ---` line:
```sh
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
     && ! echo "$output" | grep -q 'a comment alone'
  then
    pass_test "extract: alias/export/bindkey shown, comments skipped"
  else
    fail_test "extract: missing or wrong candidates. output: $output"
  fi
  cleanup_sandbox
}
```

Then add `test_extract_simple` to the run section:
```sh
test_missing_backup
test_extract_simple
```

- [ ] **Step 2: Add a failing test for dedup (lines already in public zshrc are filtered out)**

In `tests/test_migrate.sh`, add another test function:
```sh
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
     && ! echo "$output" | grep -q 'alias ll='
  then
    pass_test "dedup: filters lines already in public zshrc"
  else
    fail_test "dedup: wrong filtering. output: $output"
  fi
  cleanup_sandbox
}
```

And add to the run section:
```sh
test_missing_backup
test_extract_simple
test_dedup_against_public
```

- [ ] **Step 3: Run tests — expect new ones to FAIL**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `PASS: missing backup ...`, `FAIL: extract: ...`, `FAIL: dedup: ...`.

- [ ] **Step 4: Add extraction + filter logic to the helper**

In `bin/migrate-customizations.sh`, **replace** the trailing `# Further logic added in subsequent tasks.` line with:
```sh
# 2. Extract candidate single-line patterns
candidates=$(grep -nE '^(alias |export |bindkey |[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{.*\}[[:space:]]*$)' "$backup" || true)

# 3. Filter out lines that exist verbatim in the public zshrc
filtered=""
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  content="${line#*:}"
  if ! grep -Fxq -- "$content" "$ZSHRC_PUBLIC"; then
    filtered+="${line}"$'\n'
  fi
done <<< "$candidates"

# 4. Show user
if [[ -z "$filtered" ]]; then
  echo "No migratable customizations found."
  exit 0
fi

echo
echo "Candidates to migrate:"
printf '%s' "$filtered"

# 5. Prompt
echo
read -r -p "Append the candidates above to $ZSHRC_LOCAL? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "No changes made."
  exit 0
fi

echo "(append logic comes in next task)"
```

- [ ] **Step 5: Run tests — expect new ones to PASS**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `=== 3 passed, 0 failed ===`.

- [ ] **Step 6: Commit**

```sh
git add bin/migrate-customizations.sh tests/test_migrate.sh
git commit -m "feat(migrate): extract aliases/exports/bindkeys, dedup against public zshrc"
```

---

### Task 7: Migration helper — multi-line REVIEW markers and append-to-local

**Files:**
- Modify: `bin/migrate-customizations.sh` (add REVIEW detection + append block)
- Modify: `tests/test_migrate.sh` (add tests for REVIEW + append)

- [ ] **Step 1: Add a failing test for multi-line REVIEW markers**

In `tests/test_migrate.sh`, add:
```sh
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
  if echo "$output" | grep -q "REVIEW.*my_helper"; then
    pass_test "review: multi-line function flagged"
  else
    fail_test "review: missing marker. output: $output"
  fi
  cleanup_sandbox
}
```

And add to the run section.

- [ ] **Step 2: Add a failing test for append-to-local**

In `tests/test_migrate.sh`, add:
```sh
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
```

And add to the run section.

- [ ] **Step 3: Add a failing test for empty backup → exit 0 cleanly**

In `tests/test_migrate.sh`, add:
```sh
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
```

And add to the run section. Final run order should be:
```sh
test_missing_backup
test_extract_simple
test_dedup_against_public
test_multiline_review
test_append_to_local
test_empty_backup
```

- [ ] **Step 4: Run all tests — expect 3 new ones to FAIL**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: 3 PASS, 3 FAIL.

- [ ] **Step 5: Add REVIEW marker logic + append block to the helper**

In `bin/migrate-customizations.sh`, replace the `echo "(append logic comes in next task)"` placeholder (and adjust the surrounding logic) so the section from `# 4. Show user` onward looks like:
```sh
# 4. Detect multi-line function declarations (lines like `name() {` on
#    their own — body follows). These can't be safely auto-migrated.
multiline=$(grep -nE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{[[:space:]]*$' "$backup" || true)

# 5. Show user
if [[ -z "$filtered" && -z "$multiline" ]]; then
  echo "No migratable customizations found."
  exit 0
fi

echo
if [[ -n "$filtered" ]]; then
  echo "Candidates to migrate:"
  printf '%s' "$filtered"
fi
if [[ -n "$multiline" ]]; then
  echo
  echo "Multi-line constructs (NOT auto-migrated, review by hand):"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    echo "  # REVIEW: $backup:$line"
  done <<< "$multiline"
fi

# 6. If only multi-line constructs (nothing to actually append), exit 0
if [[ -z "$filtered" ]]; then
  echo
  echo "Nothing to append automatically. Migrate the REVIEW items by hand."
  exit 0
fi

# 7. Prompt
echo
read -r -p "Append the candidates above to $ZSHRC_LOCAL? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "No changes made."
  exit 0
fi

# 8. Append with header
{
  echo
  echo "# ─── Migrated from ${backup} on $(date) ───"
  printf '%s' "$filtered" | sed 's/^[0-9]*://'
} >> "$ZSHRC_LOCAL"

echo "Appended to $ZSHRC_LOCAL. Run: exec zsh"
```

- [ ] **Step 6: Run all tests — expect 6 PASS**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `=== 6 passed, 0 failed ===`.

- [ ] **Step 7: Commit**

```sh
git add bin/migrate-customizations.sh tests/test_migrate.sh
git commit -m "feat(migrate): REVIEW markers for multi-line, append to ~/.zshrc.local"
```

---

### Task 8: README updates

**Files:**
- Modify: `README.md` (new sections + small wording fix)

- [ ] **Step 1: Update the "Re-run bootstrap.sh is safe" sentence**

In `README.md`, find this line (around line 51):
```
- **Re-run bootstrap.sh** is safe — it backs up anything it would overwrite.
```
Replace it with:
```
- **Re-run bootstrap.sh** is safe — it backs up anything it would overwrite, and on first install it tells you to migrate any aliases from your old zshrc into `~/.zshrc.local` (see "Personal customizations" below).
```

- [ ] **Step 2: Add a new "Personal customizations" section**

In `README.md`, after the existing `## Customizing` section (which ends with the "Add brew packages" subsection around line 100), add a new top-level section:
```markdown
---

## Personal customizations

This repo is the **public, common** layer. Per-user content (your SSH aliases, project-specific PATHs, machine-specific exports) belongs in `~/.zshrc.local` — a file outside this repo that the public `zshrc` sources at the very end if it exists.

```sh
# ~/.zshrc.local — example
alias gp="git push"
alias mywork="ssh me@my-private-server"
export PATH="$HOME/Code/bin:$PATH"
```

`bootstrap.sh` never creates, modifies, or symlinks `~/.zshrc.local`. Re-installing the dotfiles or pulling upstream changes will not touch it.

### Upgrading from an existing zshrc

If you already had a `~/.zshrc` with personal aliases when you ran `bootstrap.sh`, it was backed up to `~/.zshrc.backup.<timestamp>` and the install printed instructions pointing here. Run the migration helper to extract aliases / exports / bindkeys into `~/.zshrc.local` automatically:

```sh
~/dotfiles/bin/migrate-customizations.sh   # auto-detects newest backup
~/dotfiles/bin/migrate-customizations.sh ~/.zshrc.backup.20260508-172142   # explicit
```

The helper:
- Extracts single-line `alias`, `export`, `bindkey`, and `name() { …; }` declarations.
- Filters out lines already present in the public `zshrc` (no duplicates).
- Flags multi-line constructs (functions spanning multiple lines, `if`/`while` blocks, here-docs) as `# REVIEW: <path>:<line>` markers so you can migrate those by hand.
- Asks before writing. Appends to `~/.zshrc.local` with a clear `# ─── Migrated from … on … ───` header.
```

- [ ] **Step 3: Verify both edits land where intended**

Run:
```sh
grep -n 'Personal customizations\|migrate-customizations\|~/.zshrc.local' /Users/dinhduycuong/dotfiles/README.md
```
Expected: at least 5 matches across the new section.

- [ ] **Step 4: Commit**

```sh
git add README.md
git commit -m "docs: document ~/.zshrc.local pattern and migration helper"
```

---

### Task 9: End-to-end smoke test

**Files:** none (verification only)

- [ ] **Step 1: Confirm the unit-test suite passes**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/test_migrate.sh
```
Expected: `=== 6 passed, 0 failed ===`.

- [ ] **Step 2: Confirm bootstrap.sh syntax is valid**

Run:
```sh
bash -n /Users/dinhduycuong/dotfiles/bootstrap.sh && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Confirm a fresh interactive zsh loads cleanly**

Run:
```sh
zsh -i -c '
  echo "PATH lines:"
  echo "$PATH" | tr ":" "\n" | grep -E "(Qt/6\.9\.1|openjdk@17)" || echo "  (none — good)"
  echo "personal aliases:"
  alias | grep -E "sshToTh10" || echo "  (none — good)"
  echo "local override hook:"
  grep -c "zshrc.local" "$HOME/.zshrc" 2>/dev/null || echo 0
'
```
Expected: PATH lines section shows "(none — good)", personal aliases section shows "(none — good)", local override hook count is `1` (from the source line we added in Task 1).

- [ ] **Step 4: Integration test — link() + notice + helper, in a sandbox HOME**

This intentionally does NOT run all of `bootstrap.sh` (which would invoke `brew bundle` and `defaults write` on the real system). Instead it sources the `link()` function and the post-install notice block in isolation, then runs the helper.

Run:
```sh
SAND=$(mktemp -d)
DOT=/Users/dinhduycuong/dotfiles

# Synthesize an existing user zshrc with a personal alias + a personal PATH.
echo 'alias mycustom="echo hi"' > "$SAND/.zshrc"
echo 'export PATH="$HOME/Code/bin:$PATH"' >> "$SAND/.zshrc"

# Drive link() + the notice block in a subshell with HOME=SAND.
HOME="$SAND" DOTFILES="$DOT" bash -c '
  set -euo pipefail
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  BACKUPS=()
  log()  { printf "==> %s\n" "$*"; }
  warn() { printf "!! %s\n" "$*"; }
  ok()   { printf "OK  %s\n" "$*"; }

  # Source the link() function from bootstrap.sh.
  source <(awk "/^link\(\) \{/,/^\}/" "'"$DOT"'/bootstrap.sh")

  # Run the symlink step that bootstrap would do for zshrc.
  link "'"$DOT"'/zsh/zshrc" "$HOME/.zshrc"

  # Run the post-install notice block (extract from bootstrap.sh).
  source <(awk "/^if \[\[ \\\${#BACKUPS\[@\]} -gt 0 \]\]; then/,/^fi$/" "'"$DOT"'/bootstrap.sh")
'

echo "---"

# Now run the helper against the auto-detected backup, answer y.
HOME="$SAND" DOTFILES="$DOT" bash -c 'printf "y\n" | "$DOTFILES/bin/migrate-customizations.sh"'

echo "---"
echo "Resulting ~/.zshrc.local:"
cat "$SAND/.zshrc.local"

rm -rf "$SAND"
```
Expected:
- A `!!` warn block referencing `migrate-customizations.sh` and the `*.backup.<timestamp>` path.
- The helper output lists `mycustom` and the personal PATH export as candidates.
- `~/.zshrc.local` contains the `# ─── Migrated from … ───` header and the two migrated lines.

- [ ] **Step 5: Final review — list commits made by this plan**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && git log --oneline -10
```
Expected: 8 new commits since the spec commit, matching the task commit messages above (zshrc source, zshrc cleanup, Brewfile, bootstrap notice, 3 × migrate helper, README).
