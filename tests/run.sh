#!/usr/bin/env bash
# tests/run.sh — run all repo tests. Use this before pushing.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== test_migrate.sh ==="
"$DIR/test_migrate.sh"
echo
echo "=== test_zshrc_smoke.sh ==="
"$DIR/test_zshrc_smoke.sh"
