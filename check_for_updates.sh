#!/bin/bash

# -----------------------------------------------------------------------------
# Script: check_for_updates.sh
# Description: Checks for updates in the Dev Tools Git repo
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_DIR="$(pwd)"

cd "$SCRIPT_DIR"

if git fetch --quiet && ! git diff --quiet HEAD..origin/HEAD; then
  echo ""
  echo "📦 Updates available in Dev Tools repository!"
  echo "💡 To update, run:"
  echo "   cd \"$SCRIPT_DIR\" && git pull && cd -"
  echo ""
fi

cd "$ORIGINAL_DIR"
