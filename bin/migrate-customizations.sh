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
if [[ -z "$backup" ]]; then
  echo "no backup file found (looked for ~/.zshrc.backup.*)" >&2
  exit 1
elif [[ ! -f "$backup" ]]; then
  echo "backup file not found: $backup" >&2
  exit 1
fi

echo "Scanning $backup ..."
# Further logic added in subsequent tasks.
