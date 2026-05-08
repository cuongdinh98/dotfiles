# Personal customization layer for the dotfiles project

**Date:** 2026-05-08
**Status:** Approved (pending spec review)

## Problem

This is a public dotfiles repo (`github.com/cuongdinh98/dotfiles`). When a new
user runs `bootstrap.sh` on a Mac that already has a `~/.zshrc` containing
their own aliases, exports, or functions, the installer:

1. Moves their existing `~/.zshrc` to `~/.zshrc.backup.<timestamp>` (good).
2. Symlinks `~/.zshrc` → `~/dotfiles/zsh/zshrc` (good).
3. Tells them nothing about the backup at the end (bad — silent loss).

Result: the user's personal aliases are gone from their active shell, and
they have no place inside the project to put their personal stuff that
won't get overwritten on the next install or pull.

A second, related problem: the public `zsh/zshrc` currently ships personal
content (`alias sshToTh10="ssh dinhd@…"`, a hardcoded Qt 6.9.1 path, a
Garmin-Connect-IQ-specific `openjdk@17` PATH entry). These have no place in
a public repo.

## Goals

- A canonical, documented place for personal customizations that survives
  re-runs of `bootstrap.sh`, `git pull`, and re-installs on new machines.
- First-time installers don't lose their pre-existing zshrc customizations
  silently.
- The public repo stops shipping personal content.

## Non-goals

- Pre-install interactive confirmation in `bootstrap.sh`. Preserving the
  one-line install (`git clone … && bootstrap.sh`) is a selling point.
- Auto-seeding `~/.zshrc.local` verbatim from the backup. Verbatim copies
  cause double-init issues (plugins sourced twice, prompt initialized
  twice, etc.).
- A general-purpose dotfiles framework (categories, modules, etc.). Stay
  focused on the smallest change that solves the problem.

## Design

### 1. Personal layer: `~/.zshrc.local`

The dotfiles `zsh/zshrc` sources `~/.zshrc.local` at the very end if it
exists:

```sh
# --- Personal customizations (not tracked by this repo) ---
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
```

Properties:

- File lives in `$HOME`, not in the dotfiles repo. `bootstrap.sh` never
  creates, modifies, or symlinks it.
- Sourced last so personal config overrides any defaults set by the public
  zshrc (PATH prepends, alias overrides, etc.).
- Absent file is silently a no-op.

### 2. Bootstrap notice

`bootstrap.sh` accumulates the list of files it backed up during `link()`
and, at the end of the script, prints a prominent block when that list is
non-empty:

```
!!  Pre-existing config files were backed up. Personal customizations are
!!  NOT in your active shell. Move them into ~/.zshrc.local
!!  (auto-sourced by zshrc), or use the migration helper:

    ~/dotfiles/bin/migrate-customizations.sh ~/.zshrc.backup.<timestamp>

    Or compare manually:
    diff ~/dotfiles/zsh/zshrc ~/.zshrc.backup.<timestamp>
```

The notice is suppressed when no backups were created (clean machine /
re-run on a system already symlinked).

### 3. Migration helper: `bin/migrate-customizations.sh`

A standalone POSIX-ish bash script that helps a user move personal content
from a backup into `~/.zshrc.local`.

**Usage:**

```
bin/migrate-customizations.sh [backup-file]
```

If `backup-file` is omitted, the script auto-detects the most recent
`~/.zshrc.backup.*` file (sorted by mtime, newest wins) and uses that. If
none exists, it exits with a clear message.

**What it extracts (single-line patterns only):**

- `^alias …`
- `^export …` (PATH= entries especially)
- `^bindkey …`
- Single-line function definitions `^[a-zA-Z_][a-zA-Z0-9_]*\(\) {`

**What it deliberately does NOT try to extract:**

- Multi-line function bodies, conditional blocks (`if … fi`), here-docs.
  Detection logic surfaces these as `# REVIEW: multi-line construct at
  <backup>:<line>` markers in the output, so the user knows they're there
  but has to migrate them by hand.

**Filtering:**

- Lines that match verbatim against any line in the dotfiles
  `zsh/zshrc` are dropped (no point migrating identical content).
- Lines starting with `#` (comments) are skipped — comments around
  customizations are usually personal context but rarely transferable.

**Output flow:**

1. Print extracted candidates to stdout, prefixed with their line number
   in the backup.
2. Prompt: `Append these to ~/.zshrc.local? [y/N]`
3. On yes:
   - Create `~/.zshrc.local` if it doesn't exist.
   - Append a header block:
     ```
     # ─── Migrated from <backup> on <date> ─────────────────────
     ```
   - Append the candidates verbatim.
   - Print final path and instruct user to `exec zsh` to pick it up.
4. On no: exit 0, no changes made.

**Known limitations (documented in the script and README):**

- Won't capture multi-line constructs. Surfaces them as REVIEW markers.
- Doesn't reorder PATH carefully. If user's backup has `export
  PATH=/x:$PATH` and dotfiles already adds `/x` to PATH, the entry is
  duplicated harmlessly but isn't deduplicated by the helper.
- Idempotency: re-running the helper on the same backup will append
  another block to `~/.zshrc.local`. The header timestamp makes it easy to
  identify and remove duplicates. The helper does not deduplicate
  automatically.

### 4. `zsh/zshrc` cleanup

Remove personal content from the public file:

- `alias sshToTh10="ssh dinhd@193.55.164.41"` (line 38) — personal SSH
  shortcut. Move to a private template documented in README.
- `alias sshToTh10ForParaview=…` (line 39) — same.
- `export PATH="$HOME/Qt/6.9.1/macos/bin:$PATH"` (line 3) — version-pinned
  personal Qt install.
- `export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"` with the "Garmin
  Connect IQ SDK" comment (line 4) — personal SDK path.

These belong in the user's own `~/.zshrc.local`. The `openjdk@17`
**Brewfile entry** is also dropped, since it's only there for the Garmin
SDK case.

### 5. `README.md` updates

- New section **"Personal customizations"** explaining `~/.zshrc.local`,
  with a small example block (a couple of aliases, a PATH export). This
  doubles as the documentation users expect from a public dotfiles repo.
- New section **"Upgrading from an existing zshrc"** documenting the
  migration helper and its known limitations.
- Update the existing **"Re-run bootstrap.sh is safe"** sentence (line
  51) — clarify that "safe" means "your old config is backed up, and the
  helper can extract aliases for you."
- The **"Aliases"** section (lines 73–81) is already clean (only common
  defaults: `ls/ll/gs/gd/gl/..`). No edit needed there.

## Components and interfaces

| Unit | Lives in | Depends on | Consumed by |
|---|---|---|---|
| `~/.zshrc.local` source line | `zsh/zshrc` (last block) | `$HOME/.zshrc.local` (optional file) | every interactive shell |
| BACKUPS tracking | `bootstrap.sh` `link()` + post-install block | local bash array | the user, at end of install |
| Migration helper | `bin/migrate-customizations.sh` | a backup file path; `zsh/zshrc` (for filtering) | the user, manually |
| README sections | `README.md` | nothing | new installers reading the repo |

Each unit is independently understandable and replaceable. The helper
script in particular is self-contained and could be deleted without
breaking anything else — the `~/.zshrc.local` mechanism still works
without it.

## Error handling

- `~/.zshrc.local` missing: silent no-op (the source line is guarded with
  `[ -f ]`).
- Bootstrap with no existing config files to back up: BACKUPS array is
  empty; notice block is suppressed entirely.
- Helper run with no backup file argument and no `~/.zshrc.backup.*` files
  on disk: exits 1 with a clear "no backup found" message.
- Helper run on an empty / commented-only backup: produces an empty
  candidate set, prints "no migratable lines found", exits 0 without
  modifying anything.
- Helper run when `~/.zshrc.local` already exists: appends with a header
  block (does not overwrite). User can review and edit.

## Testing plan

Manual test fixture: create a synthetic `~/.zshrc.test-backup` containing:

```
alias gp="git push"                         # new personal alias
alias ll="ls -lah"                          # duplicate of dotfiles entry
export PATH="$HOME/Code/scripts:$PATH"      # new personal PATH
my_func() {                                 # multi-line function
  echo "hi"
}
# a comment alone                            # ignored
bindkey -s '^[g' 'git status\n'             # custom binding
```

Then verify:

1. **Bootstrap notice** — running `bootstrap.sh` on a clean machine with a
   pre-existing `~/.zshrc` produces the post-install warning block with
   the correct backup path and helper command.
2. **Helper extraction** — running the helper on the test backup outputs:
   - The `gp` alias and the `gp` PATH export and the `bindkey` line as
     candidates.
   - The `ll` alias filtered out (duplicate of dotfiles).
   - A REVIEW marker for the multi-line `my_func`.
   - No comment-only lines.
3. **Helper append** — answering `y` creates `~/.zshrc.local` with the
   header block + extracted lines. `exec zsh` then has the new alias
   active. Re-sourcing zshrc twice doesn't break (idempotent source).
4. **Cleanup of public zshrc** — fresh `zsh -i -c 'alias | grep sshToTh10'`
   returns empty (alias removed). `zsh -i -c 'echo $PATH'` no longer
   contains `Qt/6.9.1` or `openjdk@17` paths (unless the user has them in
   their own `~/.zshrc.local`).

## Out of scope (for this spec)

- Conversion to a templating system (chezmoi, yadm, stow). The current
  symlink approach stays.
- Tracking `~/.zshrc.local` in any sort of registry or backup. It's the
  user's file; user owns its persistence.
- An equivalent `~/.zprofile.local`. Currently `zprofile` only sets brew
  shellenv and we have no signal that users need a personal layer there.
  Easy to add later if asked.
