#!/bin/bash

# -----------------------------------------------------------------------------
# Script: check_for_updates.sh
# Description: Checks for updates in the Dev Tools Git repo
# -----------------------------------------------------------------------------

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ORIGINAL_DIR="$(pwd)"

if [[ -f "$SCRIPT_DIR/git_credential_check.sh" ]]; then
  # shellcheck source=/dev/null
  GIT_CRED_CHECK_SCRIPT="$SCRIPT_DIR/git_credential_check.sh"
fi

cd "$ROOT_DIR"

if [[ -n "$GIT_CRED_CHECK_SCRIPT" ]]; then
  # shellcheck source=/dev/null
  source "$GIT_CRED_CHECK_SCRIPT"
fi

if git fetch --quiet && ! git diff --quiet HEAD..origin/HEAD; then
  echo ""
  echo "📦 Updates available in Dev Tools repository! (run 'dev-tools -u' to update)"
  echo ""
fi

cd "$ORIGINAL_DIR"
