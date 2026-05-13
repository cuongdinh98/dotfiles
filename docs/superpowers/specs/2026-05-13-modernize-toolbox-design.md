# Modernize the dotfiles toolbox

**Date:** 2026-05-13
**Status:** Approved (awaiting implementation plan)

## Summary

Layer a modern, Tokyo-Night-themed CLI toolbox onto the existing
iTerm2 + Zsh + Starship setup, and remove the slowest parts of the current
shell startup (eager `nvm`, uncached `compinit`).

The repo's structure stays familiar: configs in subdirectories, symlinked by
`bootstrap.sh`. No plugin manager, no rewrite of existing files beyond
`zshrc` and `bootstrap.sh`.

## Goals

- Daily UX upgrade: replace plain coreutils with faster, friendlier
  alternatives, available alongside the originals (additive aliases — never
  shadow `ls`/`cat`/`grep`).
- Sub-100ms cold zsh startup on Apple Silicon (currently ~250–400ms,
  dominated by eager `nvm`).
- Consistent Tokyo Night theme across every tool that supports theming.
- Keep the SSH-friendly invariants from the current setup (true-color env
  vars, dark window chrome, shell integration).
- Zero behavior change for scripts: pasted commands and `#!/usr/bin/env bash`
  scripts must keep working the same way.

## Non-goals

- Replacing `nvm` with `mise`/`asdf` — out of scope for this iteration.
- Adding `lazygit`, neovim config, tmux config, or window manager config.
- GitHub Actions / remote CI for the existing `tests/test_migrate.sh`.
- Auto-managing `~/.gitconfig` (user identity lives there; we provide an
  include-able snippet instead).
- A one-liner remote installer for SSH'd Linux boxes.

## User-visible changes

### New commands available after install

| Command | Replaces | Notes |
|---|---|---|
| `eza`, `l`, `ll`, `lt` | `ls` (still works) | git-aware, tree mode (`lt`) |
| `bat` | `cat` (still works) | syntax highlight, used for `MANPAGER` |
| `rg` | `grep` (still works) | gitignore-aware, ~10× faster |
| `fd` | `find` (still works) | sane defaults, gitignore-aware |
| `z <pat>`, `zi` | `cd` (still works) | frecency-ranked jumping (zoxide) |
| `dust` | `du` | tree-style disk usage |
| `btop` | `top`/`htop` | Tokyo-Night-themed TUI |
| `delta` | git's pager | side-by-side, syntax-highlighted diffs |
| `direnv` | — | per-project env vars |

### New keybindings

- `Ctrl-R` — atuin's fzf-style history search (replaces zsh's plain
  reverse-i-search).
- `Up` after typing a prefix — atuin prefix history.
- `Ctrl-T` — fzf file picker.
- `Alt-C` — fzf cd to directory.
- `**<TAB>` — fzf completion trigger.

### Unchanged from today

- Aliases `gs`, `gd`, `gl`, `..`, `...`, `la`, `ll` (the existing `ll`
  meaning of `ls -lah` becomes `eza -lah --git --icons`; same intent).
- Starship prompt, iTerm2 profile, colors, fonts.
- `~/.zshrc.local` personal-customization layer.
- `bin/migrate-customizations.sh` and its test suite.

## Architecture

### Repo layout

Additions in **bold**, everything else unchanged:

```
dotfiles/
├── Brewfile                           ← +11 brews
├── bootstrap.sh                       ← +bat cache, +new symlinks, +bench
├── README.md                          ← updated
├── bin/migrate-customizations.sh
├── docs/
├── iterm2/                            (unchanged)
├── starship/starship.toml             (unchanged)
├── tests/
│   ├── test_migrate.sh                (unchanged)
│   ├── **test_zshrc_smoke.sh**        ← new
│   └── **run.sh**                     ← new entry point
├── zsh/
│   ├── zshrc                          ← extended (~120 lines, sectioned)
│   └── zprofile                       (unchanged)
├── **bat/**
│   ├── config
│   └── themes/tokyonight_night.tmTheme
├── **atuin/**
│   └── config.toml
├── **btop/**
│   └── tokyonight.theme
└── **git/**
    └── delta.gitconfig
```

`zsh/zshrc` stays a single file with `# --- Section ---` headers. We will
revisit a modular `rc.d/` layout if it grows past ~200 lines.

### Brewfile additions

```ruby
# Modern CLI replacements
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

# Per-project env
brew "direnv"
```

### `zsh/zshrc` execution order (extended)

```
1.  PATH + locale + colors                    (unchanged)
2.  History opts                              (unchanged; atuin-compatible)
3.  QoL setopts + bindkey -e                  (unchanged)
4.  compinit — cached: rebuild dump only if older than 24h
5.  Aliases (additive: l/ll/lt/lg via eza, MANPAGER=bat)
6.  Tool inits, in this exact order:
      a. zoxide init zsh           →  defines `z`, `zi`
      b. fzf key-bindings + completion
      c. atuin init zsh            →  rebinds Ctrl-R + Up
      d. direnv hook zsh
7.  nvm — LAZY STUB
8.  zsh-autosuggestions
9.  zsh-syntax-highlighting           (must remain LAST plugin sourced)
10. starship init zsh
11. iTerm2 shell integration
12. ~/.zshrc.local
```

#### Ordering invariants (non-obvious)

- **atuin must initialize before zsh-syntax-highlighting** — both wrap ZLE
  widgets; the highlighter wraps every widget that exists at its load time,
  so plugins that *create* widgets (atuin's `atuin-search`) must come first
  or get clobbered.
- **zsh-syntax-highlighting must be the last plugin sourced** — well-known
  upstream constraint.
- **fzf can come anywhere before atuin** — they don't conflict; we keep the
  conventional order.

#### Lazy nvm stub (replaces eager source)

```sh
export NVM_DIR="$HOME/.nvm"
_nvm_lazy_load() {
  unset -f nvm node npm npx
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
nvm()  { _nvm_lazy_load; nvm  "$@"; }
node() { _nvm_lazy_load; node "$@"; }
npm()  { _nvm_lazy_load; npm  "$@"; }
npx()  { _nvm_lazy_load; npx  "$@"; }
```

First call to any of `nvm`/`node`/`npm`/`npx` pays the ~200ms one-time cost;
the stubs unset themselves so subsequent calls hit the real binaries.

#### compinit cache

```sh
autoload -Uz compinit
# Rebuild the dump only if it's missing or >24h old.
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C   # skip the security audit; ~100ms saved per shell
fi
```

The `(#qN.mh+24)` glob qualifier matches `.zcompdump` only if it exists and
is older than 24 hours.

### Theming

Single source of truth: Tokyo Night Night palette
(`#1a1b26` bg, `#7aa2f7` blue, `#9ece6a` green, `#7dcfff` cyan,
`#bb9af7` purple, `#e0af68` yellow, `#ff9e64` orange, `#f7768e` red,
`#c0caf5` fg). Already defined in `starship/starship.toml`.

| Tool | Theming method |
|---|---|
| starship, iTerm2 | unchanged (already themed) |
| bat | `bat/themes/tokyonight_night.tmTheme` (vendored from upstream Tokyo Night repo); built once via `bat cache --build` in bootstrap. `bat/config` selects it. |
| delta | `git/delta.gitconfig` defines a `tokyonight` feature with literal hex colors. User opts in by adding `[include] path = ~/dotfiles/git/delta.gitconfig` to their `~/.gitconfig`. |
| fzf | `FZF_DEFAULT_OPTS` env var in zshrc, single line embedding the palette. |
| atuin | `atuin/config.toml` uses `style = "compact"` and `inline_height = 20`. Atuin inherits terminal colors — no theme file needed. |
| btop | symlinked theme; bootstrap prints a one-time hint to pick `tokyonight` from btop's options menu (`o` in btop). We deliberately do not write to `~/.config/btop/btop.conf` — btop rewrites it on every quit, so any value we set would be overwritten by the user's next session. |
| eza | `EZA_COLORS` env var in zshrc, single line. |

### `bootstrap.sh` changes

Additions, in order, after the existing symlink loop and before the nvm
section:

```sh
# Build bat's theme cache so our vendored .tmTheme appears in `bat --list-themes`.
if command -v bat >/dev/null 2>&1; then
  log "Building bat theme cache…"
  bat cache --build >/dev/null
fi

# New symlinks (use existing link() — gets backup-on-overwrite for free).
link "$DOTFILES/bat/config"                "$HOME/.config/bat/config"
link "$DOTFILES/bat/themes/tokyonight_night.tmTheme" \
                                           "$HOME/.config/bat/themes/tokyonight_night.tmTheme"
link "$DOTFILES/atuin/config.toml"         "$HOME/.config/atuin/config.toml"
link "$DOTFILES/btop/tokyonight.theme"     "$HOME/.config/btop/themes/tokyonight.theme"

# One-time hint about delta + ~/.gitconfig.
if ! grep -q "dotfiles/git/delta.gitconfig" "$HOME/.gitconfig" 2>/dev/null; then
  warn "To enable Tokyo Night git diffs, add this to ~/.gitconfig:"
  warn "    [include]"
  warn "        path = $DOTFILES/git/delta.gitconfig"
fi
```

Final step, just before the existing `Next steps:` heredoc:

```sh
log "Measuring zsh cold-start time (3 runs)…"
for i in 1 2 3; do
  /usr/bin/time -p zsh -i -c exit 2>&1 \
    | awk -v i="$i" '/^real/ {printf "  run %d: %.3fs\n", i, $2}'
done
```

Existing migration prompt and backup reporting stay exactly as they are.

### Tests

`tests/run.sh` (new entry point):

```sh
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/test_migrate.sh"
"$DIR/test_zshrc_smoke.sh"
```

`tests/test_zshrc_smoke.sh` (new):

- Sources `zsh/zshrc` in a clean subshell with a sandbox `HOME`.
- Asserts:
  1. Exit code 0.
  2. No `command not found` or `no such file` on stderr.
  3. `nvm` is defined as a function (lazy stub), not as a binary call.
  4. `z` (zoxide), `_atuin_search` (atuin's ZLE widget), and `fzf-cd-widget`
     are all defined as ZLE widgets / functions. Test uses `(( $+functions[NAME] ))`
     and `zle -l NAME` checks; if atuin renames the widget upstream, the test
     fails loudly rather than silently passing.
- Skips with `SKIP` (exit 0) if any of the optional brews aren't installed,
  so a fresh checkout passes before `bootstrap.sh` has run.

`README.md` documents `./tests/run.sh` as the pre-push check.

## Performance budget

| Metric | Today | Target | Mechanism |
|---|---|---|---|
| Cold zsh startup (M-series) | 250–400ms | < 100ms | Lazy nvm + cached compinit |
| Brewfile install (cold) | ~2 min | ~3 min | +11 small Rust/Go binaries |
| Disk footprint added | — | ~30 MB | All single-binary tools |

## Risks and mitigations

- **Lazy nvm stub breaks tools that read `which node` at shell start.** Mitigation: stubs return the real path on first call; `which node` post-stub-fire works. Any tool that runs `node` inside a non-interactive shell triggers the stub anyway.
- **atuin captures keystrokes that scripts paste into `Up`/`Ctrl-R`.** Mitigation: atuin only binds in interactive shells; scripts and SSH-piped commands are unaffected.
- **bat theme cache is per-user state** — running `bootstrap.sh` on a machine where the user has hand-built bat themes will see ours added, not replace theirs.
- **`btop` theme symlink may conflict with btop's own auto-generated config**. Mitigation: bootstrap creates the parent dir and uses the existing `link()` helper, which backs up any pre-existing file.
- **Vendoring an upstream `.tmTheme`** ties us to that file's license. Tokyo Night themes are MIT — fine to vendor with attribution in a `bat/themes/README` if desired.

## Open questions / deferred decisions

- Should `~/.zshrc.local` be sourced *before* the lazy-nvm stubs so users
  can override them? Current spec sources it last, matching today's behavior;
  this means a user who wants eager nvm has to remove the stubs by hand. We
  can add a `LAZY_NVM=0` env-var escape hatch in a follow-up if it ever
  comes up.
- A future iteration could swap nvm for `mise` and ship `mise.toml` defaults;
  explicitly out of scope here.
- A future iteration could add a remote one-liner that installs starship +
  the same Tokyo Night theme on Linux SSH targets; out of scope here.

## Implementation order (high-level — full plan to follow)

1. Brewfile additions + bootstrap symlinks + `bat cache --build`.
2. Vendor theme files (`bat/themes/`, `btop/`, `git/delta.gitconfig`).
3. Author `atuin/config.toml`, `bat/config`.
4. Extend `zsh/zshrc` in the order above; verify each section in isolation.
5. `tests/test_zshrc_smoke.sh` + `tests/run.sh`.
6. Bootstrap startup-time benchmark.
7. README rewrite of "What you get" + "Daily workflow" + cheatsheet table.
