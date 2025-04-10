#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Argument-based quick start (must be FIRST!) ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|-c)
            bash "$SCRIPT_DIR/commit/git_export_staged.sh"
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo "Use without arguments for menu, or use:"
            echo "  --commit | -c   → Run git_export_staged"
            exit 1
            ;;
    esac
fi

# --- Interactive Menu ---
echo ""
echo "🛠️  Dev Tools Launcher"
echo "======================"
echo "Choose a tool to run:"
echo ""
echo "1) Export staged Git changes (git_export_staged)"
echo "2) Exit"
echo ""

read -p "Enter your choice [1-2]: " choice

case "$choice" in
  1)
    bash "$SCRIPT_DIR/commit/git_export_staged.sh"
    ;;
  2)
    echo "👋 Bye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice."
    ;;
esac
