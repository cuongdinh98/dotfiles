#!/usr/bin/env bash
#
# bootstrap.sh — set up a fresh Mac with this dotfiles repo.
# Idempotent: safe to run multiple times.
#
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

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

# ---- 4. nvm (optional) ------------------------------------------------------
if [[ ! -d "$HOME/.nvm" ]]; then
  log "Installing nvm…"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash
  ok "nvm installed (loaded by .zshrc on next shell)."
else
  ok "nvm already present."
fi

echo
ok "Bootstrap complete."
cat <<'EOF'

Next steps:
  1. Quit and relaunch iTerm2 so the Tokyo Night dynamic profile loads.
  2. iTerm2 → Settings (⌘,) → Profiles → "Tokyo Night" → Other Actions… → Set as Default.
  3. Settings → Appearance → General → Theme: Minimal (or Dark).
  4. Run:  exec zsh    (to pick up the new shell config in your current session)

EOF
