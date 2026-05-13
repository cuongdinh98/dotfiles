#!/usr/bin/env bash
#
# bootstrap.sh — set up a fresh Mac with this dotfiles repo.
# Idempotent: safe to run multiple times.
#
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUPS=()  # entries: "<backup-path>|<source-symlink-target>"

log()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!! \033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }

# ---- 1. Homebrew ------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Make brew available in this shell (Apple Silicon vs Intel)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
ok "Homebrew ready: $(brew --version | head -1)"

# ---- 2. Brew packages -------------------------------------------------------
log "Installing packages from Brewfile…"
brew bundle --file="$DOTFILES/Brewfile"
ok "Packages installed."

# ---- 3. Symlinks ------------------------------------------------------------
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup="${dst}.backup.${TIMESTAMP}"
    mv "$dst" "$backup"
    warn "Existing $dst backed up to $backup"
    BACKUPS+=("${backup}|${src}")
  fi
  ln -s "$src" "$dst"
  ok "Linked $(basename "$dst")"
}

log "Symlinking configs…"
link "$DOTFILES/zsh/zshrc"                            "$HOME/.zshrc"
link "$DOTFILES/zsh/zprofile"                         "$HOME/.zprofile"
link "$DOTFILES/starship/starship.toml"               "$HOME/.config/starship.toml"
link "$DOTFILES/iterm2/tokyonight_night.itermcolors"  "$HOME/.config/iterm2-themes/tokyonight_night.itermcolors"
link "$DOTFILES/iterm2/tokyo-night.json"              "$HOME/Library/Application Support/iTerm2/DynamicProfiles/tokyo-night.json"
link "$DOTFILES/atuin/config.toml"                    "$HOME/.config/atuin/config.toml"
link "$DOTFILES/bat/config"                           "$HOME/.config/bat/config"
link "$DOTFILES/bat/themes/tokyonight_night.tmTheme"  "$HOME/.config/bat/themes/tokyonight_night.tmTheme"
link "$DOTFILES/btop/tokyonight_night.theme"          "$HOME/.config/btop/themes/tokyonight_night.theme"

# ---- 3b. bat theme cache ----------------------------------------------------
# Re-build bat's theme cache so our vendored Tokyo Night .tmTheme appears in
# `bat --list-themes`. Idempotent — safe to re-run.
if command -v bat >/dev/null 2>&1 && [[ -f "$HOME/.config/bat/themes/tokyonight_night.tmTheme" ]]; then
  log "Building bat theme cache…"
  bat cache --build >/dev/null
  ok "bat theme cache built."
fi

# ---- 4. nvm (optional) ------------------------------------------------------
if [[ ! -d "$HOME/.nvm" ]]; then
  log "Installing nvm…"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash
  ok "nvm installed (loaded by .zshrc on next shell)."
else
  ok "nvm already present."
fi

# ---- 4b. iTerm2 shell integration ------------------------------------------
# Enables prompt marks (⌘↑/⌘↓), command status, alert-on-finish, click-to-rerun,
# and remote-dir forwarding over SSH. zshrc sources it if present.
log "Installing iTerm2 shell integration…"
curl -fsSL https://iterm2.com/shell_integration/zsh \
  -o "$HOME/.iterm2_shell_integration.zsh"
ok "iTerm2 shell integration ready."

# ---- 5. iTerm2 preferences (optional, interactive) --------------------------
# Note: iTerm2 owns its plist while running and writes its in-memory state on
# quit. If iTerm2 is open when these run, the changes may be overwritten when
# you quit. Cleanest scenario: run bootstrap before launching iTerm2 the first
# time on a new Mac. Otherwise, fully quit iTerm2 right after this script and
# relaunch.
ask() {
  local prompt="$1" default="${2:-Y}" reply
  if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then reply="$default"; else
    read -r -p "$prompt [$([[ $default == Y ]] && echo Y/n || echo y/N)] " reply || reply=""
    reply="${reply:-$default}"
  fi
  [[ "$reply" =~ ^[Yy]$ ]]
}

if ask "Set Tokyo Night as default iTerm2 profile?"; then
  defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "TOKYO-NIGHT-DEFAULT-PROFILE"
  ok "Tokyo Night set as default profile."
fi

if ask "Lock iTerm2 to dark window chrome (Minimal theme)?"; then
  # 0=Light 1=Dark 2=LightHC 3=DarkHC 4=Auto 5=Minimal 6=Compact
  defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 5
  ok "iTerm2 theme set to Minimal (dark window chrome locked)."
fi

if ask "Disable macOS window state restoration for iTerm2 (fixes tiny-window-on-launch)?"; then
  # Stops macOS from restoring last session's window size, so the profile's
  # Columns/Rows (140x40) are honored on every launch.
  defaults write com.googlecode.iterm2 NSQuitAlwaysKeepsWindows -bool false
  ok "Window state restoration disabled — windows will use profile size."
fi

if pgrep -x iTerm2 >/dev/null 2>&1; then
  warn "iTerm2 is currently running — fully quit it (⌘Q) and relaunch so these settings stick."
fi

echo
# btop hint — we don't write to ~/.config/btop/btop.conf because btop rewrites
# it on every quit. The user picks the theme manually once via the options menu.
if command -v btop >/dev/null 2>&1; then
  if ! grep -q 'color_theme = "tokyonight_night"' "$HOME/.config/btop/btop.conf" 2>/dev/null; then
    warn "btop installed — open btop, press 'o' (options), and pick the 'tokyonight_night' theme."
  fi
fi

ok "Bootstrap complete."

if [[ ${#BACKUPS[@]} -gt 0 ]]; then
  echo
  warn "Pre-existing config files were backed up. Personal customizations"
  warn "are NOT in your active shell."

  # Pick the zshrc backup, if any — only zshrc is migration-helper compatible.
  zshrc_backup=""
  for entry in "${BACKUPS[@]}"; do
    case "${entry%%|*}" in
      *.zshrc.backup.*) zshrc_backup="${entry%%|*}" ;;
    esac
  done

  if [[ -n "$zshrc_backup" ]]; then
    warn "Use the migration helper to move aliases / exports / bindkeys"
    warn "from your old zshrc into ~/.zshrc.local (auto-sourced):"
    printf "    %s/bin/migrate-customizations.sh %q\n" "$DOTFILES" "$zshrc_backup"
    echo
    if [[ "${NONINTERACTIVE:-0}" != "1" ]] && ask "Run the migration helper now?"; then
      "$DOTFILES/bin/migrate-customizations.sh" "$zshrc_backup" || \
        warn "Migration helper exited non-zero; you can re-run it later by hand."
    fi
  fi

  warn "All backups (compare manually):"
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
