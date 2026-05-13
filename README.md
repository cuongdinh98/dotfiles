# dotfiles

Personal macOS terminal setup — **iTerm2 + Zsh + Starship + Tokyo Night**, designed to look modern and stay consistent across machines (especially when SSH-ing into Linux servers, where light/dark mismatches usually make things ugly).

One command bootstraps a fresh Mac.

```bash
git clone https://github.com/cuongdinh98/dotfiles.git ~/dotfiles && ~/dotfiles/bootstrap.sh
```

---

## What's inside

| Path | What it is |
|---|---|
| `Brewfile` | All Homebrew packages (iTerm2, Starship, plugins, fonts, gh, plus the modern toolbox: eza/bat/rg/fd/zoxide/dust/btop/fzf/atuin/git-delta/direnv) |
| `bootstrap.sh` | Idempotent installer — installs Homebrew, runs `brew bundle`, symlinks configs |
| `zsh/zshrc` | Shell config: history, completion, aliases, plugin sourcing, Starship init |
| `zsh/zprofile` | Brew shellenv (login shell) |
| `starship/starship.toml` | Two-line Tokyo Night prompt with OS / user / dir / git / language segments |
| `iterm2/tokyo-night.json` | iTerm2 [Dynamic Profile](https://iterm2.com/documentation-dynamic-profiles.html) — auto-loaded on launch |
| `iterm2/tokyonight_night.itermcolors` | Standalone color preset (importable into any iTerm2 profile) |
| `bat/` | bat config + vendored Tokyo Night `.tmTheme` (symlinked into `~/.config/bat/`) |
| `atuin/config.toml` | atuin config: local-only, fuzzy Ctrl-R, no sync |
| `btop/tokyonight_night.theme` | btop Tokyo Night theme (pick it via btop's `o` menu) |
| `git/delta.gitconfig` | git-delta config — opt-in via `[include]` in your `~/.gitconfig` |
| `tests/` | `run.sh` runs the migration helper + zshrc smoke test |

---

## Quick start (new Mac)

1. **Install Xcode CLT** (one-off, gives you `git`):
   ```bash
   xcode-select --install
   ```
2. **Clone & bootstrap**:
   ```bash
   git clone https://github.com/cuongdinh98/dotfiles.git ~/dotfiles
   cd ~/dotfiles && ./bootstrap.sh
   ```
3. **Quit & relaunch iTerm2.**
4. In iTerm2: `⌘,` → **Profiles** → click **Tokyo Night** → **Other Actions… → Set as Default**.
5. `⌘,` → **Appearance → General → Theme** = `Minimal` (or `Dark`).
6. New shell: `exec zsh` — done.
7. **(Optional) Enable Tokyo Night `git diff`:** add to `~/.gitconfig`:
   ```ini
   [include]
       path = ~/dotfiles/git/delta.gitconfig
   ```

---

## Daily workflow

The configs live in this repo and are **symlinked** into their real locations. So:

- **Edit a config** → just edit the file in `~/dotfiles/…` (or via the symlink, same thing).
- **Sync to your other Mac** → `git add -A && git commit -m "tweak prompt" && git push`. On the other Mac, `cd ~/dotfiles && git pull`. Changes are live instantly — no re-run of bootstrap needed.
- **Re-run bootstrap.sh** is safe — it backs up anything it would overwrite, and on first install it tells you to migrate any aliases from your old zshrc into `~/.zshrc.local` (see "Personal customizations" below).
- **Run tests before pushing** → `./tests/run.sh`. Covers the migration helper and a smoke test of the modern-tools wiring.

---

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

---

## Customizing

### Change the prompt
Edit `starship/starship.toml`. Live preview: every new prompt re-reads the file.

### Change colors
Edit `iterm2/tokyo-night.json`. iTerm2 picks up Dynamic Profile changes within a few seconds. If you rename the profile, iTerm2 may keep the old one cached — easiest is to quit & relaunch.

### Change window size
In `iterm2/tokyo-night.json` set `"Columns"` and `"Rows"`. Some defaults:
- Compact: `120 × 35`
- Comfortable: `140 × 40` (current)
- Large: `160 × 50`

### Add brew packages
Append to `Brewfile`, then `brew bundle`.

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

If you already had a `~/.zshrc` with personal aliases when you ran `bootstrap.sh`, it was backed up to `~/.zshrc.backup.<timestamp>`. At the end of the install, **bootstrap will offer to run the migration helper for you** — answer `Y` and your aliases / exports / bindkeys are moved into `~/.zshrc.local` interactively.

You can also run the helper yourself any time:

```sh
~/dotfiles/bin/migrate-customizations.sh   # auto-detects newest backup
~/dotfiles/bin/migrate-customizations.sh ~/.zshrc.backup.20241015-143022   # explicit
```

(In `NONINTERACTIVE=1` installs the prompt is skipped — re-run the helper manually when you're ready.)

The helper:
- Extracts single-line `alias`, `export`, `bindkey`, and `name() { …; }` declarations.
- Filters out lines already present in the public `zshrc` (no duplicates).
- Flags multi-line function declarations (`name() {` bodies spanning multiple lines) as `# REVIEW: <path>:<line>` markers so you can migrate those by hand. Other multi-line constructs (`if`/`while` blocks, here-docs) are not auto-detected — check your backup manually for those.
- Asks before writing. Appends to `~/.zshrc.local` with a clear `# ─── Migrated from … on … ───` header.
- Is idempotent: running it twice on the same backup detects the existing migration block and skips.

---

## SSH to Linux looking right

The config is tuned to keep remote sessions readable:

- iTerm2 theme set to **Minimal/Dark** locks dark window chrome regardless of macOS appearance — the most common cause of "ugly SSH" is fixed.
- Profile background `#1a1b26` is dark, so any remote app that doesn't override its own background inherits a sane dark.
- `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG=en_US.UTF-8` are exported, so vim/htop/btop/tmux on the remote get full color and proper unicode.
- The Nerd Font is set as the non-ASCII fallback — prompt glyphs render even on servers without a Nerd Font installed.

To get the same Tokyo Night Starship prompt on the remote Linux box:
```bash
curl -sS https://starship.rs/install.sh | sh
mkdir -p ~/.config && curl -fsSL \
  https://raw.githubusercontent.com/cuongdinh98/dotfiles/main/starship/starship.toml \
  -o ~/.config/starship.toml
echo 'eval "$(starship init bash)"' >> ~/.bashrc   # or zsh, fish, etc.
```

---

## Troubleshooting

**iTerm2 opens a tiny window.** `bootstrap.sh` offers to disable macOS state restoration for iTerm2, which fixes this. If you skipped that prompt, run `defaults write com.googlecode.iterm2 NSQuitAlwaysKeepsWindows -bool false` and relaunch iTerm2.

**"Dynamic profile references unknown parent name."** Means `Dynamic Profile Parent Name` is set to a profile that doesn't exist. The profile in this repo doesn't use that field — if you've added it, just remove it.

**Fonts look like squares / question marks.** Nerd Font isn't installed or isn't selected. Check `~/Library/Fonts/JetBrainsMonoNerdFont-Regular.ttf` exists, then iTerm2 → Profile → Text → Font.

**Plugins not loading.** `brew list zsh-autosuggestions zsh-syntax-highlighting` should show both. If they're missing, run `~/dotfiles/bootstrap.sh` again.

---

## License

Use it however you like. No warranty.
