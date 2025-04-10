#!/bin/bash

# -----------------------------------------------------------------------------
# Script: check_for_updates.sh
#
# Description:
#   Checks for updates in the Git repository where this script resides.
#   Always uses the path of this script (no parameters allowed).
# -----------------------------------------------------------------------------

check_for_updates() {
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local original_dir="$(pwd)"

  cd "$script_dir"
  if git fetch --quiet && ! git diff --quiet HEAD..origin/HEAD; then
    echo ""
    echo "📦 Updates available in Dev Tools repository!"
    echo "💡 To update, run:"
    echo "   cd \"$script_dir\" && git pull && cd -"
  fi
  cd "$original_dir"
}

# Always run the check
check_for_updates
