#!/bin/bash

# -----------------------------------------------------------------------------
# Script: perform_auto_update.sh
# Description: Pulls latest version of Dev Tools from origin.
# -----------------------------------------------------------------------------

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "🔄 Performing Dev Tools update..."
eval "cd \"$ROOT_DIR\" && git pull && cd -"
echo ""
echo "✅ Update complete."
echo ""
