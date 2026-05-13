# Modernize the dotfiles toolbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a modern, Tokyo-Night-themed CLI toolbox (eza/bat/rg/fd/zoxide/dust/btop/fzf/atuin/delta/direnv) on top of the existing setup, and remove the slowest parts of zsh startup (eager `nvm`, uncached `compinit`) to bring cold start under 100ms on Apple Silicon.

**Architecture:** Additive everywhere — originals (`ls`, `cat`, `grep`, `cd`) keep working; new tools are accessible by their own names plus a few short aliases. New per-tool config/theme files live in `bat/`, `atuin/`, `btop/`, `git/` and are symlinked by the existing `bootstrap.sh` `link()` helper. The single `zsh/zshrc` is extended (not split) with clearly-headered sections; tool inits are ordered so atuin's ZLE widgets exist before zsh-syntax-highlighting wraps them.

**Tech Stack:** Bash, Zsh, Homebrew. New brews are all single-binary Rust/Go tools.

**Spec:** [`docs/superpowers/specs/2026-05-13-modernize-toolbox-design.md`](../specs/2026-05-13-modernize-toolbox-design.md)

---

### Task 1: Add the new brews to Brewfile

**Files:**
- Modify: `Brewfile`

- [ ] **Step 1: Verify the new brews are not in Brewfile yet (failing test)**

Run:
```sh
grep -cE '^brew "(eza|bat|ripgrep|fd|zoxide|dust|btop|fzf|atuin|git-delta|direnv)"$' /Users/dinhduycuong/dotfiles/Brewfile
```
Expected: `0`

- [ ] **Step 2: Append the new brews to Brewfile**

Append after the existing `brew "gh"` line (before the `# Fonts` block):

```ruby

# Modern CLI replacements (additive — originals keep working)
brew "eza"
brew "bat"
brew "ripgrep"
brew "fd"
brew "zoxide"
brew "dust"
brew "btop"

# Fuzzy + history
brew "fzf"
brew "atuin"

# Git ergonomics
brew "git-delta"

# Per-project env vars
brew "direnv"
```

- [ ] **Step 3: Verify Brewfile is parseable and the new brews are present**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && brew bundle list --file=Brewfile | grep -cE '^(eza|bat|ripgrep|fd|zoxide|dust|btop|fzf|atuin|git-delta|direnv)$'
```
Expected: `11`

- [ ] **Step 4: Install the new brews**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && brew bundle --file=Brewfile
```
Expected: every new tool installed (`==> Installing eza`, etc.). Idempotent on re-run.

- [ ] **Step 5: Verify each binary is on PATH**

Run:
```sh
for b in eza bat rg fd zoxide dust btop fzf atuin delta direnv; do
  command -v "$b" >/dev/null && echo "OK $b" || echo "MISSING $b"
done
```
Expected: 11 lines all `OK`.

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add Brewfile
git commit -m "feat(brew): add modern CLI toolbox (eza/bat/rg/fd/zoxide/dust/btop/fzf/atuin/delta/direnv)"
```

---

### Task 2: Cache `compinit` to skip the per-shell security audit

**Files:**
- Modify: `zsh/zshrc:23` (the `autoload -Uz compinit && compinit` line)

- [ ] **Step 1: Measure current cold-start time as a baseline (failing test)**

Run:
```sh
for i in 1 2 3; do /usr/bin/time -p zsh -i -c exit 2>&1 | awk '/^real/ {printf "  run %d: %.3fs\n", '"$i"', $2}'; done
```
Expected: three timings, typically each in the 0.20–0.45s range. Note the median.

- [ ] **Step 2: Replace the compinit block in `zsh/zshrc`**

Replace:
```sh
# --- Completion ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
```

With:
```sh
# --- Completion ---
# Rebuild the dump only if it's missing or older than 24h. The (#qN.mh+24)
# glob qualifier matches ~/.zcompdump only if it exists and is older than 24h;
# `compinit -C` skips the security audit (~100ms saved per shell).
autoload -Uz compinit
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
```

- [ ] **Step 3: Force a fresh dump, then re-measure to verify cache path is used**

Run:
```sh
rm -f ~/.zcompdump
zsh -i -c exit                       # populates the dump
for i in 1 2 3; do /usr/bin/time -p zsh -i -c exit 2>&1 | awk '/^real/ {printf "  run %d: %.3fs\n", '"$i"', $2}'; done
```
Expected: median ~80–150ms faster than baseline (depends on machine). Cache file `~/.zcompdump` exists.

- [ ] **Step 4: Verify completion still works**

Run:
```sh
zsh -i -c 'autoload -Uz compinit; print -l ${(k)_comps[git]}'
```
Expected: a non-empty line (e.g., `_git`) — proves git completions are loaded.

- [ ] **Step 5: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "perf(zsh): cache compinit dump, skip per-shell security audit"
```

---

### Task 3: Lazy-load nvm via stub functions

**Files:**
- Modify: `zsh/zshrc:37-40` (the existing nvm block)

- [ ] **Step 1: Confirm nvm is currently sourced eagerly (failing test)**

Run:
```sh
zsh -i -c 'type -w nvm; type -w node 2>/dev/null'
```
Expected: `nvm: function` (because nvm.sh defines it); `node: command` if installed via nvm. Either way, `nvm` is real (not a stub).

Then time the cost of the eager source specifically:
```sh
time zsh -i -c 'true'
time zsh -ic 'unset -f nvm 2>/dev/null; true'
```
The first line includes the nvm cost; expect this to drop noticeably after lazy-loading.

- [ ] **Step 2: Replace the nvm block in `zsh/zshrc`**

Replace:
```sh
# --- nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
```

With:
```sh
# --- nvm (lazy) ---
# Eager nvm sourcing is the single biggest source of slow zsh startup
# (~150-300ms). Define stubs for nvm/node/npm/npx that source nvm on first
# call, then transparently re-invoke the real binary.
export NVM_DIR="$HOME/.nvm"
_nvm_lazy_load() {
  unset -f nvm node npm npx 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _nvm_lazy_load; nvm  "$@"; }
node() { _nvm_lazy_load; node "$@"; }
npm()  { _nvm_lazy_load; npm  "$@"; }
npx()  { _nvm_lazy_load; npx  "$@"; }
```

- [ ] **Step 3: Verify `nvm`, `node`, `npm`, `npx` are functions before first call**

Run:
```sh
zsh -i -c 'for f in nvm node npm npx; do print -- "$f: $(type -w $f)"; done'
```
Expected: all four print `<name>: function`.

- [ ] **Step 4: Verify first call to nvm transparently swaps in the real one**

Run:
```sh
zsh -i -c 'nvm --version; type -w nvm'
```
Expected: an actual nvm version (e.g., `0.40.1`) followed by `nvm: function` — but now it's the real nvm function defined by `nvm.sh`, not our stub.

- [ ] **Step 5: Verify cold-start time dropped**

Run:
```sh
for i in 1 2 3; do /usr/bin/time -p zsh -i -c exit 2>&1 | awk '/^real/ {printf "  run %d: %.3fs\n", '"$i"', $2}'; done
```
Expected: median should now be roughly 100–200ms faster than after Task 2 alone, and well under 100ms on Apple Silicon.

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "perf(zsh): lazy-load nvm via stub functions (cuts cold start ~200ms)"
```

---

### Task 4: Add the "Modern tools" section + zoxide init

**Files:**
- Modify: `zsh/zshrc` (insert a new section between the Aliases block and the `# --- nvm (lazy) ---` block)

- [ ] **Step 1: Confirm `z` is not a function yet (failing test)**

Run:
```sh
zsh -i -c 'type -w z 2>&1 || true'
```
Expected: `z: none` or "z not found".

- [ ] **Step 2: Insert the new section into `zsh/zshrc`**

Locate the `# --- nvm (lazy) ---` line (added in Task 3). Insert *immediately above it*:

```sh
# --- Modern tools (init order matters — see spec) ---
# zoxide: smart `cd` replacement. `z foo` jumps to most-frecent dir matching foo,
# `zi` opens an fzf-style interactive picker.
eval "$(zoxide init zsh)"

```

(Note the trailing blank line — keeps the `# --- nvm (lazy) ---` header visually separated.)

- [ ] **Step 3: Verify `z` and `zi` are defined**

Run:
```sh
zsh -i -c 'type -w z zi'
```
Expected: `z: function` and `zi: function`.

- [ ] **Step 4: Verify zoxide tracks a `cd` and can jump to it**

Run:
```sh
zsh -i -c 'cd /tmp && cd ~ && z tmp && pwd'
```
Expected: ends in `/tmp` (or the canonical resolution like `/private/tmp` on macOS).

- [ ] **Step 5: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "feat(zsh): add zoxide for frecency-ranked cd"
```

---

### Task 5: fzf — keybindings + completion + Tokyo Night colors

**Files:**
- Modify: `zsh/zshrc` (insert into the "Modern tools" section, after zoxide; add `FZF_DEFAULT_OPTS` export)

- [ ] **Step 1: Confirm fzf widgets are not loaded yet (failing test)**

Run:
```sh
zsh -i -c 'zle -l fzf-cd-widget 2>&1 || echo "no widget"'
```
Expected: `no widget` (or empty).

- [ ] **Step 2: Insert fzf init into `zsh/zshrc`**

Locate the `eval "$(zoxide init zsh)"` line (Task 4). Insert *immediately after it*:

```sh

# fzf: source key-bindings (Ctrl-T / Alt-C / Ctrl-R) and fuzzy completion (** trigger).
# atuin (below) re-binds Ctrl-R; fzf's Ctrl-T and Alt-C survive.
if [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
fi
if [[ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]]; then
  source /opt/homebrew/opt/fzf/shell/completion.zsh
fi

# Tokyo Night palette for fzf (matches starship/iTerm2).
export FZF_DEFAULT_OPTS="--color=fg:#c0caf5,bg:#1a1b26,hl:#bb9af7,fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff,info:#7aa2f7,prompt:#7dcfff,pointer:#7dcfff,marker:#9ece6a,spinner:#9ece6a,header:#9ece6a"
```

- [ ] **Step 3: Verify fzf widgets and `FZF_DEFAULT_OPTS` are loaded**

Run:
```sh
zsh -i -c 'zle -l fzf-cd-widget fzf-history-widget fzf-file-widget && echo "OPTS=$FZF_DEFAULT_OPTS"'
```
Expected: three widget names printed (one per line), then `OPTS=--color=fg:#c0caf5...`.

- [ ] **Step 4: Smoke-test the file-picker widget non-interactively**

Run:
```sh
zsh -i -c 'echo file1.txt; echo file2.txt' | fzf --filter=file1
```
Expected: `file1.txt` (proves fzf is on PATH and accepts `FZF_DEFAULT_OPTS`).

- [ ] **Step 5: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "feat(zsh): add fzf keybindings + completion with Tokyo Night palette"
```

---

### Task 6: atuin — vendored config + init + Ctrl-R rebind

**Files:**
- Create: `atuin/config.toml`
- Modify: `zsh/zshrc` (insert atuin init after fzf in "Modern tools")
- Modify: `bootstrap.sh` (add symlink for `atuin/config.toml`)

- [ ] **Step 1: Confirm `_atuin_search` is not defined yet (failing test)**

Run:
```sh
zsh -i -c 'zle -l _atuin_search 2>&1 || echo "no widget"'
```
Expected: `no widget`.

- [ ] **Step 2: Create `atuin/config.toml`**

Create `/Users/dinhduycuong/dotfiles/atuin/config.toml` with:

```toml
# atuin — local-only smart shell history.
# Spec: docs/superpowers/specs/2026-05-13-modernize-toolbox-design.md

# UI
style = "compact"           # less screen real estate than "full"
inline_height = 20          # don't take over the whole terminal
show_preview = true
show_help = true

# Search
search_mode = "fuzzy"       # like fzf
filter_mode = "global"      # search across all sessions by default
filter_mode_shell_up_key_binding = "session"  # Up = current session only

# Sync — disabled. Opt in later with `atuin register`.
auto_sync = false
update_check = false
```

- [ ] **Step 3: Add the symlink in `bootstrap.sh`**

In `/Users/dinhduycuong/dotfiles/bootstrap.sh`, locate the existing block:

```sh
link "$DOTFILES/iterm2/tokyo-night.json"              "$HOME/Library/Application Support/iTerm2/DynamicProfiles/tokyo-night.json"
```

Insert *immediately after it*:

```sh
link "$DOTFILES/atuin/config.toml"                    "$HOME/.config/atuin/config.toml"
```

- [ ] **Step 4: Insert atuin init into `zsh/zshrc`**

Locate the `export FZF_DEFAULT_OPTS=...` line (Task 5). Insert *immediately after it*:

```sh

# atuin: rebinds Ctrl-R + Up for fzf-style history search.
# Must come BEFORE zsh-syntax-highlighting (highlighter wraps existing widgets;
# atuin's _atuin_search widget must exist when the highlighter loads).
# `filter_mode_shell_up_key_binding = "session"` in atuin/config.toml scopes
# Up to current-session history (zsh's classic prefix-history behavior),
# while Ctrl-R searches everything.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi
```

- [ ] **Step 5: Apply the new symlink by re-running bootstrap**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && NONINTERACTIVE=1 ./bootstrap.sh 2>&1 | grep -E 'atuin|backup'
```
Expected: `Linked config.toml` (and any backup messages if `~/.config/atuin/config.toml` already existed).

- [ ] **Step 6: Verify atuin widget is bound to Ctrl-R**

Run:
```sh
zsh -i -c 'zle -l _atuin_search && bindkey "^R"'
```
Expected: line 1 prints `_atuin_search`; line 2 prints `"^R" _atuin_search`.

- [ ] **Step 7: Verify atuin records and finds a command (no sync)**

Run:
```sh
atuin search --limit 1 --format '{command}' --search-mode fuzzy 'echo modernize-test' >/dev/null 2>&1 || true
zsh -i -c 'echo modernize-test-marker-$$'   # generates a uniquely-tagged history entry
sleep 1
atuin search --limit 5 modernize-test-marker | grep -q modernize-test-marker && echo OK || echo FAIL
```
Expected: `OK` (atuin captured the command).

- [ ] **Step 8: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add atuin/config.toml zsh/zshrc bootstrap.sh
git commit -m "feat(atuin): local-only smart history with fzf-style Ctrl-R"
```

---

### Task 7: direnv hook

**Files:**
- Modify: `zsh/zshrc` (insert direnv hook after atuin in "Modern tools")

- [ ] **Step 1: Confirm direnv hook is not active yet (failing test)**

Run:
```sh
zsh -i -c 'typeset -f _direnv_hook 2>&1 || echo "no hook"'
```
Expected: `no hook` (or empty).

- [ ] **Step 2: Insert direnv hook into `zsh/zshrc`**

Locate the `eval "$(atuin init zsh ...)"` block (Task 6). Insert *immediately after the closing `fi`*:

```sh

# direnv: per-project env vars from .envrc. Hook runs on every prompt.
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
```

- [ ] **Step 3: Verify the hook is registered**

Run:
```sh
zsh -i -c 'typeset -f _direnv_hook >/dev/null && echo OK || echo FAIL'
```
Expected: `OK`.

- [ ] **Step 4: Smoke-test direnv loads an `.envrc`**

Run:
```sh
tmpdir=$(mktemp -d)
echo 'export DIRENV_TEST_VAR=loaded' > "$tmpdir/.envrc"
( cd "$tmpdir" && direnv allow && zsh -i -c 'echo "var=$DIRENV_TEST_VAR"' )
rm -rf "$tmpdir"
```
Expected: `var=loaded`.

- [ ] **Step 5: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "feat(zsh): add direnv hook for per-project env vars"
```

---

### Task 8: eza — short aliases + Tokyo Night colors

**Files:**
- Modify: `zsh/zshrc` (extend the Aliases section, add `EZA_COLORS` env var)

- [ ] **Step 1: Confirm `l`, `lt`, `lg` aliases don't exist yet (failing test)**

Run:
```sh
zsh -i -c 'alias l 2>&1 || echo "no l"; alias lt 2>&1 || echo "no lt"; alias lg 2>&1 || echo "no lg"'
```
Expected: three "no …" lines.

- [ ] **Step 2: Extend the Aliases block in `zsh/zshrc`**

Locate the existing `# --- Aliases ---` section. Append *after the last existing alias line* (`alias gl=...`):

```sh

# eza (modern ls) — additive: `ls` stays plain `ls`. Short new aliases below.
if command -v eza >/dev/null 2>&1; then
  alias l='eza --icons --git'
  alias ll='eza -lah --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons --git'
  alias lg='eza -lah --icons --git --git-ignore'
  # Tokyo Night-ish file colors. Override default eza palette to harmonize.
  export EZA_COLORS="da=38;5;110:di=38;5;111:ex=38;5;150:ln=38;5;141:un=38;5;174"
fi
```

- [ ] **Step 3: Verify aliases and `EZA_COLORS` exist**

Run:
```sh
zsh -i -c 'alias l ll lt lg && echo "EZA=$EZA_COLORS"'
```
Expected: four alias lines printed and `EZA=da=38;5;110:...`.

- [ ] **Step 4: Smoke-test `ll` works**

Run:
```sh
zsh -i -c 'll /etc/hosts'
```
Expected: a single eza-formatted line for `/etc/hosts` with permissions, size, etc.

- [ ] **Step 5: Verify `ls` is still plain `ls` (additive invariant)**

Run:
```sh
zsh -i -c 'type ls'
```
Expected: `ls is an alias for ls -lahG` (the existing alias from `zshrc:28`).

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add zsh/zshrc
git commit -m "feat(zsh): add eza short aliases (l/ll/lt/lg) with Tokyo Night colors"
```

---

### Task 9: bat — vendored theme + config + symlinks + cache build + MANPAGER

**Files:**
- Create: `bat/config`
- Create: `bat/themes/tokyonight_night.tmTheme` (vendored)
- Modify: `bootstrap.sh` (symlink + `bat cache --build`)
- Modify: `zsh/zshrc` (set `MANPAGER`)

- [ ] **Step 1: Confirm bat doesn't know about `tokyonight_night` yet (failing test)**

Run:
```sh
bat --list-themes | grep -c tokyonight_night
```
Expected: `0`.

- [ ] **Step 2: Vendor the theme file**

Create `/Users/dinhduycuong/dotfiles/bat/themes/` and download the upstream Tokyo Night `.tmTheme` from folke/tokyonight.nvim:

Run:
```sh
mkdir -p /Users/dinhduycuong/dotfiles/bat/themes
curl -fsSL \
  https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/sublime/tokyonight_night.tmTheme \
  -o /Users/dinhduycuong/dotfiles/bat/themes/tokyonight_night.tmTheme
```

Verify:
```sh
head -5 /Users/dinhduycuong/dotfiles/bat/themes/tokyonight_night.tmTheme
```
Expected: starts with `<?xml version="1.0" encoding="UTF-8"?>` and contains `tokyonight_night` somewhere in the first ~10 lines.

- [ ] **Step 3: Create `bat/config`**

Create `/Users/dinhduycuong/dotfiles/bat/config` with:

```sh
# bat config — see `man bat` or https://github.com/sharkdp/bat
--theme="tokyonight_night"
--style="numbers,changes,header"
--paging=auto
```

- [ ] **Step 4: Add symlinks to `bootstrap.sh`**

In `/Users/dinhduycuong/dotfiles/bootstrap.sh`, locate the symlink block (the lines added in Task 6 for atuin). Insert *immediately after* the atuin link line:

```sh
link "$DOTFILES/bat/config"                           "$HOME/.config/bat/config"
link "$DOTFILES/bat/themes/tokyonight_night.tmTheme"  "$HOME/.config/bat/themes/tokyonight_night.tmTheme"
```

- [ ] **Step 4b: Add `bat cache --build` to `bootstrap.sh` (after symlinks, before nvm)**

`bat cache --build` reads theme files from `~/.config/bat/themes/`, so it must run *after* the symlink loop creates that directory. In `bootstrap.sh`, locate the comment line `# ---- 4. nvm (optional) ------------------------------------------------------`. Insert *immediately above it*:

```sh
# ---- 3b. bat theme cache ----------------------------------------------------
# Re-build bat's theme cache so our vendored Tokyo Night .tmTheme appears in
# `bat --list-themes`. Idempotent — safe to re-run.
if command -v bat >/dev/null 2>&1 && [[ -f "$HOME/.config/bat/themes/tokyonight_night.tmTheme" ]]; then
  log "Building bat theme cache…"
  bat cache --build >/dev/null
  ok "bat theme cache built."
fi



- [ ] **Step 5: Set `MANPAGER` to bat in `zsh/zshrc`**

Locate the `# --- PATH & env ---` section. Append at the end of that section (after `export PATH="$HOME/.local/bin:$PATH"`):

```sh
# Use bat as the man page pager (Tokyo Night-themed, syntax-highlighted).
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi
```

- [ ] **Step 6: Run bootstrap to apply symlinks + cache build**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && NONINTERACTIVE=1 ./bootstrap.sh 2>&1 | grep -E 'bat|backup'
```
Expected: `Linked config`, `Linked tokyonight_night.tmTheme`, `bat theme cache built.`

- [ ] **Step 7: Verify bat sees the theme and uses it**

Run:
```sh
bat --list-themes | grep -c tokyonight_night
```
Expected: `1` (or `2` if it appears under both light and dark sections).

Then:
```sh
echo 'def hi(): return 1' | bat -l py --color=always | head -3
```
Expected: ANSI-colored Python output (visual check — colors should match Tokyo Night).

- [ ] **Step 8: Verify `MANPAGER` works**

Run:
```sh
zsh -i -c 'echo "$MANPAGER"'
```
Expected: `sh -c 'col -bx | bat -l man -p'`.

- [ ] **Step 9: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add bat/ bootstrap.sh zsh/zshrc
git commit -m "feat(bat): vendor Tokyo Night theme, symlink config, set MANPAGER"
```

---

### Task 10: btop — vendored theme + symlink + post-install hint

**Files:**
- Create: `btop/tokyonight_night.theme` (vendored)
- Modify: `bootstrap.sh` (symlink + hint)

- [ ] **Step 1: Confirm btop's themes dir doesn't have tokyonight yet (failing test)**

Run:
```sh
ls "$HOME/.config/btop/themes/" 2>/dev/null | grep -c tokyonight_night || echo 0
```
Expected: `0`.

- [ ] **Step 2: Vendor the theme**

Run:
```sh
mkdir -p /Users/dinhduycuong/dotfiles/btop
curl -fsSL \
  https://raw.githubusercontent.com/folke/tokyonight.nvim/main/extras/btop/tokyonight_night.theme \
  -o /Users/dinhduycuong/dotfiles/btop/tokyonight_night.theme
```

Verify:
```sh
head -3 /Users/dinhduycuong/dotfiles/btop/tokyonight_night.theme
```
Expected: lines containing `theme[main_bg]` or similar btop theme keys.

- [ ] **Step 3: Add symlink + hint to `bootstrap.sh`**

In `/Users/dinhduycuong/dotfiles/bootstrap.sh`, locate the bat symlink lines (added in Task 9). Insert *immediately after them*:

```sh
link "$DOTFILES/btop/tokyonight_night.theme"          "$HOME/.config/btop/themes/tokyonight_night.theme"
```

Then locate the final `ok "Bootstrap complete."` line. Insert *immediately before it* (or after, doesn't matter — pick before to group with other hints):

```sh
# btop hint — we don't write to ~/.config/btop/btop.conf because btop rewrites
# it on every quit. The user picks the theme manually once via the options menu.
if command -v btop >/dev/null 2>&1; then
  if ! grep -q 'color_theme = "tokyonight_night"' "$HOME/.config/btop/btop.conf" 2>/dev/null; then
    warn "btop installed — open btop, press 'o' (options), and pick the 'tokyonight_night' theme."
  fi
fi
```

- [ ] **Step 4: Run bootstrap to symlink the theme**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && NONINTERACTIVE=1 ./bootstrap.sh 2>&1 | grep -E 'btop|backup'
```
Expected: `Linked tokyonight_night.theme` and the warn line about picking the theme.

- [ ] **Step 5: Verify btop sees the theme**

Run:
```sh
ls -la "$HOME/.config/btop/themes/tokyonight_night.theme"
```
Expected: a symlink resolving to `/Users/dinhduycuong/dotfiles/btop/tokyonight_night.theme`.

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add btop/ bootstrap.sh
git commit -m "feat(btop): vendor Tokyo Night theme + symlink (manual selection in btop's options menu)"
```

---

### Task 11: git-delta — vendored gitconfig snippet + post-install hint

**Files:**
- Create: `git/delta.gitconfig`
- Modify: `bootstrap.sh` (post-install hint only — `~/.gitconfig` is never managed)

- [ ] **Step 1: Confirm `~/.gitconfig` doesn't include our delta config yet (failing test)**

Run:
```sh
grep -c 'dotfiles/git/delta.gitconfig' "$HOME/.gitconfig" 2>/dev/null || echo 0
```
Expected: `0`.

- [ ] **Step 2: Create `git/delta.gitconfig`**

Create `/Users/dinhduycuong/dotfiles/git/delta.gitconfig` with:

```ini
# git-delta with Tokyo Night colors.
# Include from your ~/.gitconfig:
#   [include]
#       path = ~/dotfiles/git/delta.gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[merge]
    conflictStyle = zdiff3

[diff]
    colorMoved = default

[delta]
    features = tokyonight
    navigate = true            # n / N to move between diff sections
    side-by-side = true
    line-numbers = true
    syntax-theme = tokyonight_night

[delta "tokyonight"]
    minus-style                   = syntax "#3a273a"
    minus-non-emph-style          = syntax "#3a273a"
    minus-emph-style              = syntax "#6b2e3c"
    minus-empty-line-marker-style = syntax "#3a273a"
    line-numbers-minus-style      = "#f7768e"
    plus-style                    = syntax "#273849"
    plus-non-emph-style           = syntax "#273849"
    plus-emph-style               = syntax "#3d5a78"
    plus-empty-line-marker-style  = syntax "#273849"
    line-numbers-plus-style       = "#9ece6a"
    line-numbers-zero-style       = "#3b4261"
    line-numbers-left-style       = "#7aa2f7"
    line-numbers-right-style      = "#7aa2f7"
    file-style                    = "#7dcfff" bold
    hunk-header-style             = "#7aa2f7" bold
    hunk-header-decoration-style  = "#3b4261" box
    file-decoration-style         = "#3b4261" ul
```

- [ ] **Step 3: Add the post-install hint to `bootstrap.sh`**

In `/Users/dinhduycuong/dotfiles/bootstrap.sh`, locate the btop hint added in Task 10. Insert *immediately after that block*:

```sh
# git-delta hint — ~/.gitconfig holds your identity, we don't symlink it.
# Print a one-time include-snippet if it isn't already wired up.
if command -v delta >/dev/null 2>&1 \
   && ! grep -q 'dotfiles/git/delta.gitconfig' "$HOME/.gitconfig" 2>/dev/null; then
  warn "To enable Tokyo Night git diffs, add this to ~/.gitconfig:"
  warn "    [include]"
  warn "        path = $DOTFILES/git/delta.gitconfig"
fi
```

- [ ] **Step 4: Run bootstrap and verify the hint appears**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && NONINTERACTIVE=1 ./bootstrap.sh 2>&1 | grep -A2 'Tokyo Night git'
```
Expected: 3 lines printed (the warn header + two indented `path = …` lines).

- [ ] **Step 5: Verify the snippet is valid by include-testing it locally**

Run:
```sh
tmp_gitconfig=$(mktemp)
cat > "$tmp_gitconfig" <<EOF
[include]
    path = /Users/dinhduycuong/dotfiles/git/delta.gitconfig
EOF
GIT_CONFIG_GLOBAL="$tmp_gitconfig" git config --get core.pager
GIT_CONFIG_GLOBAL="$tmp_gitconfig" git config --get delta.side-by-side
rm "$tmp_gitconfig"
```
Expected:
```
delta
true
```

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add git/ bootstrap.sh
git commit -m "feat(git): vendor delta gitconfig with Tokyo Night palette + bootstrap hint"
```

---

### Task 12: Smoke test for the full `zshrc` + test runner

**Files:**
- Create: `tests/test_zshrc_smoke.sh`
- Create: `tests/run.sh`

- [ ] **Step 1: Confirm there's no smoke test yet (failing test)**

Run:
```sh
ls /Users/dinhduycuong/dotfiles/tests/test_zshrc_smoke.sh 2>&1 || echo "not yet"
```
Expected: `not yet`.

- [ ] **Step 2: Create `tests/test_zshrc_smoke.sh`**

Create `/Users/dinhduycuong/dotfiles/tests/test_zshrc_smoke.sh` with:

```sh
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

# --- Test 3: zoxide widget `z` is defined ---
test_zoxide_loaded() {
  if zsh -i -c 'type -w z' 2>/dev/null | grep -q 'z: function'; then
    pass_test "zoxide z function defined"
  else
    fail_test "zoxide z function missing"
  fi
}

# --- Test 4: atuin search widget bound to Ctrl-R ---
test_atuin_widget() {
  if zsh -i -c 'zle -l _atuin_search && bindkey "^R"' 2>/dev/null \
       | grep -q '_atuin_search'; then
    pass_test "atuin _atuin_search widget bound to Ctrl-R"
  else
    fail_test "atuin widget missing or not bound to Ctrl-R"
  fi
}

# --- Test 5: fzf widgets defined ---
test_fzf_widgets() {
  local out
  out=$(zsh -i -c 'zle -l fzf-cd-widget fzf-history-widget fzf-file-widget' 2>/dev/null)
  if [[ "$(echo "$out" | wc -l)" -eq 3 ]]; then
    pass_test "fzf widgets (cd / history / file) all defined"
  else
    fail_test "fzf widgets missing — got: $out"
  fi
}

# --- Test 6: direnv hook installed ---
test_direnv_hook() {
  if zsh -i -c 'typeset -f _direnv_hook >/dev/null && echo OK' 2>/dev/null \
       | grep -q OK; then
    pass_test "direnv _direnv_hook installed"
  else
    fail_test "direnv hook missing"
  fi
}

# --- Test 7: ls is still plain ls (additive invariant) ---
test_ls_unchanged() {
  if zsh -i -c 'type ls' 2>/dev/null | grep -q "alias for ls -lahG"; then
    pass_test "ls is still the plain ls alias (eza is additive)"
  else
    fail_test "ls alias was modified — should still be 'ls -lahG'"
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

echo
echo "=== $pass passed, $fail failed ==="
[[ $fail -eq 0 ]]
```

- [ ] **Step 3: Create `tests/run.sh`**

Create `/Users/dinhduycuong/dotfiles/tests/run.sh` with:

```sh
#!/usr/bin/env bash
# tests/run.sh — run all repo tests. Use this before pushing.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== test_migrate.sh ==="
"$DIR/test_migrate.sh"
echo
echo "=== test_zshrc_smoke.sh ==="
"$DIR/test_zshrc_smoke.sh"
```

- [ ] **Step 4: Make both scripts executable**

Run:
```sh
chmod +x /Users/dinhduycuong/dotfiles/tests/test_zshrc_smoke.sh /Users/dinhduycuong/dotfiles/tests/run.sh
```

- [ ] **Step 5: Run the full suite**

Run:
```sh
/Users/dinhduycuong/dotfiles/tests/run.sh
```
Expected: `test_migrate.sh` passes (7/7 from the existing test); `test_zshrc_smoke.sh` reports `7 passed, 0 failed`.

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add tests/
git commit -m "test: zshrc smoke test + tests/run.sh entry point"
```

---

### Task 13: Add startup-time benchmark to `bootstrap.sh`

**Files:**
- Modify: `bootstrap.sh` (insert benchmark just before the final heredoc)

- [ ] **Step 1: Confirm bootstrap doesn't measure startup time yet (failing test)**

Run:
```sh
grep -c 'cold-start time' /Users/dinhduycuong/dotfiles/bootstrap.sh
```
Expected: `0`.

- [ ] **Step 2: Insert the benchmark block in `bootstrap.sh`**

Locate the block:

```sh
cat <<'EOF'

Next steps:
  1. Quit and relaunch iTerm2 so the Tokyo Night dynamic profile loads.
  2. Run:  exec zsh    (to pick up the new shell config in your current session)

EOF
```

Insert *immediately before it*:

```sh
# Startup-time baseline. Re-run after adding plugins to catch regressions.
log "Measuring zsh cold-start time (3 runs)…"
for i in 1 2 3; do
  /usr/bin/time -p zsh -i -c exit 2>&1 \
    | awk -v i="$i" '/^real/ {printf "  run %d: %.3fs\n", i, $2}'
done
```

- [ ] **Step 3: Run bootstrap and verify the benchmark runs**

Run:
```sh
cd /Users/dinhduycuong/dotfiles && NONINTERACTIVE=1 ./bootstrap.sh 2>&1 | grep -A3 'cold-start time'
```
Expected: `==> Measuring zsh cold-start time (3 runs)…` followed by 3 `run N: 0.0XXs` lines.

- [ ] **Step 4: Verify median is under 100ms (the spec's perf budget)**

Pick the median value from Step 3's output. If > 100ms, investigate (could be cold caches; re-run; if still slow, profile with `zsh -ixc exit 2>&1 | head -50`).

- [ ] **Step 5: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add bootstrap.sh
git commit -m "feat(bootstrap): print zsh cold-start time at end of install"
```

---

### Task 14: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read the current README sections that need updating**

Run:
```sh
sed -n '55,82p' /Users/dinhduycuong/dotfiles/README.md
```
This shows the "What you get" section that documents the toolset.

- [ ] **Step 2: Replace the "What you get" section**

In `/Users/dinhduycuong/dotfiles/README.md`, replace the entire `## What you get` section (heading + Terminal + Shell + Aliases subsections, lines 55–82) with:

```markdown
## What you get

### Terminal
- **iTerm2** with Tokyo Night colors, dark window chrome locked (so SSH sessions look right even when macOS is in light mode).
- **JetBrainsMono Nerd Font** — ligatures + nerd-font glyphs for prompt icons.
- 140 × 40 default window, 5% transparency + blur.
- Unlimited scrollback, silent + visual bell.
- **Shell integration** — `⌘↑`/`⌘↓` jumps between prompts, command-status indicators, "alert when finished" (`⌥⌘A`), click-to-rerun, remote-dir forwarding over SSH.
- **Natural Text Editing keymap** — `⌥←/→` jumps words, `⌘←/→` jumps line start/end, `⌥⌫` deletes word, `⌘⌫` clears line.

### Shell
- **Zsh** with sane history (50k entries, deduped, shared between sessions), cached `compinit` (rebuild-once-a-day), and lazy-loaded `nvm` (cold start under 100ms).
- **Starship prompt** — fast, two-line, shows OS / user / dir / git status / detected language version / command duration.
- **zsh-autosuggestions** — fish-style ghost suggestions from history.
- **zsh-syntax-highlighting** — commands turn green/red as you type.
- UTF-8 locale + `COLORTERM=truecolor` exported, so SSH'd Linux apps render colors correctly.

### Modern toolbox
All additive — originals (`ls`, `cat`, `grep`, `find`, `cd`, `top`) keep working unchanged.

| New command | Replaces (still works) | What's better |
|---|---|---|
| `eza` / `l` / `ll` / `lt` / `lg` | `ls` | git-aware, icons, tree mode |
| `bat` | `cat` | syntax highlight, paged, used as `MANPAGER` |
| `rg` | `grep` | gitignore-aware, ~10× faster |
| `fd` | `find` | sane defaults, gitignore-aware |
| `z <pat>` / `zi` | `cd` | frecency-ranked jumping (zoxide) |
| `dust` | `du` | tree-style disk usage |
| `btop` | `top` / `htop` | Tokyo-Night-themed TUI |
| `delta` | git's pager | side-by-side, syntax-highlighted |
| `direnv` | — | per-project env vars from `.envrc` |

### New keybindings
- `Ctrl-R` — atuin's fzf-style history search (with stats, fuzzy match, per-session filter).
- `Up` after typing a prefix — zsh prefix history.
- `Ctrl-T` — fzf file picker.
- `Alt-C` — fzf cd to directory.
- `**<TAB>` — fzf completion trigger (e.g., `vim **<TAB>`, `cd **<TAB>`).

### Aliases
```
ls   = ls -lahG          (unchanged)
ll   = ls -lah           (unchanged)
gs   = git status
gd   = git diff
gl   = git log --oneline --graph --decorate -20
..   = cd ..
...  = cd ../..
l    = eza --icons --git
ll   = eza -lah --icons --git --group-directories-first   (eza version, only if eza installed)
lt   = eza --tree --level=2 --icons --git
lg   = eza -lah --icons --git --git-ignore
```
```

- [ ] **Step 3: Add a "Tests" subsection under "Daily workflow"**

Locate the existing `## Daily workflow` section. After its bullet list (the line ending `…no re-run of bootstrap needed.`), insert:

```markdown
- **Run tests before pushing** → `./tests/run.sh`. Covers the migration helper and a smoke test of the modern-tools wiring.
```

- [ ] **Step 4: Add a one-time `~/.gitconfig` step under "Quick start"**

Locate the existing `## Quick start (new Mac)` section. Append a new step after step 6:

```markdown
7. **(Optional) Enable Tokyo Night `git diff`:** add to `~/.gitconfig`:
   ```ini
   [include]
       path = ~/dotfiles/git/delta.gitconfig
   ```
```

- [ ] **Step 5: Verify the README still renders cleanly**

Run:
```sh
grep -c '^##' /Users/dinhduycuong/dotfiles/README.md
```
Expected: same number of `##` headings as before (the section count shouldn't change — we replaced contents, not structure).

Then visually skim:
```sh
sed -n '1,100p' /Users/dinhduycuong/dotfiles/README.md
```

- [ ] **Step 6: Commit**

```sh
cd /Users/dinhduycuong/dotfiles
git add README.md
git commit -m "docs: README updates for modern toolbox + perf changes + tests/run.sh"
```

---

## Done

After Task 14:
- `./tests/run.sh` passes (7+7 tests).
- `time zsh -i -c exit` reports under 100ms median on Apple Silicon.
- `bat`, `rg`, `fd`, `z`, `eza`, `btop`, `atuin`, `fzf`, `delta`, `direnv` all work and are themed Tokyo Night.
- Originals (`ls`, `cat`, `grep`, `find`, `cd`) are unchanged — scripts and pasted commands still behave identically.
- `bootstrap.sh` is idempotent and prints a startup-time benchmark.
