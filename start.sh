#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# --- Argument-based quick start (must be FIRST!) ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|-c)
            bash "$SCRIPT_DIR/commit/git_export_staged.sh"
            exit 0
            ;;
        --log|-l)
            bash "$SCRIPT_DIR/git/git_log_explorer.sh"
            exit 0
            ;;
        --readme|-r)
            bash "$SCRIPT_DIR/readme/show_readme_instructions.sh"
            exit 0
            ;;
        *)
            echo "❌ Unknown argument: $1"
            echo ""
            echo "Usage:"
            echo "  --commit | -c   → Run git_export_staged"
            echo "  --log    | -l   → Run git_log_explorer"
            echo "  --readme | -r   → Show README creation instructions"
            exit 1
            ;;
    esac
fi



# --- Git update check ---
bash "$SCRIPT_DIR/check_for_updates.sh"

# --- Interactive Menu ---
echo ""
echo "🛠️  Dev Tools Launcher"
echo "======================"
echo "Choose a tool to run (you can also use these flags directly):"
echo ""
echo "1) Export staged Git changes         [--commit | -c]"
echo "2) Git log explorer                  [--log    | -l]"
echo "3) Show README creation instructions [--readme | -r]"
echo "q) Exit"
echo ""

# --- Git update check ---
bash "$SCRIPT_DIR/check_for_updates.sh"

read -p "Enter your choice [1-3 or q]: " choice

case "$choice" in
  1)
    bash "$SCRIPT_DIR/commit/git_export_staged.sh"
    ;;
  2)
    bash "$SCRIPT_DIR/git/git_log_explorer.sh"
    ;;
  3)
    bash "$SCRIPT_DIR/readme/show_readme_instructions.sh"
    ;;
  q|Q)
    echo "👋 Bye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice."
    ;;
esac
