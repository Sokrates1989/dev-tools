#!/bin/bash

# -----------------------------------------------------------------------------
# Script: check_for_updates.sh
# Description: Checks for updates in the Dev Tools Git repo
# -----------------------------------------------------------------------------

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_DIR="$(pwd)"

cd "$ROOT_DIR"

if git fetch --quiet && ! git diff --quiet HEAD..origin/HEAD; then
  echo ""
  echo "📦 Updates available in Dev Tools repository!"
  echo "💡 To update, run:"
  echo "   cd \"$ROOT_DIR\" && git pull && cd -"
  echo ""
fi

cd "$ORIGINAL_DIR"
