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

if [[ ! -f "$ZSHRC_PUBLIC" ]]; then
  echo "public zshrc not found: $ZSHRC_PUBLIC" >&2
  echo "(set DOTFILES to your dotfiles repo path)" >&2
  exit 1
fi

# 1. Resolve backup file
backup="${1:-}"
if [[ -z "$backup" ]]; then
  backup=$(ls -t "$HOME"/.zshrc.backup.* 2>/dev/null | head -1 || true)
fi
if [[ -z "$backup" ]]; then
  echo "no backup file found (looked for ~/.zshrc.backup.*)" >&2
  exit 1
elif [[ ! -f "$backup" ]]; then
  echo "backup file not found: $backup" >&2
  exit 1
fi

echo "Scanning $backup ..."

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
printf '%s' "$filtered" | sed 's/^[0-9]*://'

# 5. Prompt
echo
read -r -p "Append the candidates above to $ZSHRC_LOCAL? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  echo "No changes made."
  exit 0
fi

echo "(append logic comes in next task)"
