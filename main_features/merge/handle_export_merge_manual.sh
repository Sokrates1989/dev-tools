#!/bin/bash

# -----------------------------------------------------------------------------
# Script: handle_export_merge_manual.sh
#
# Description:
# Manual helper for merge commit message generation — lets the user copy the
# generated AI prompt into a tool like ChatGPT or DeepSeek.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARENT_DIR="$SCRIPT_DIR/git_export_merge"
AI_MESSAGE_FILE="$1"
TARGET_BRANCH="$2"

# --- Check if message file exists ---
if [[ ! -f "$AI_MESSAGE_FILE" ]]; then
  echo "❌ Cannot find AI message file:"
  echo "   $AI_MESSAGE_FILE"
  exit 1
fi

# --- OS Detection ---
OS="$(uname -s)"

# --- Platform-specific export handling ---
if [[ "$OS" == "Darwin" ]]; then
    echo ""
    echo "🖼️  macOS environment detected. Preparing export view..."
    echo ""
    echo "🤖 Copy the content of the opened file to your preferred AI tool (e.g., ChatGPT, DeepSeek, Gemini)"
    echo "📝 Then, include the related Project Task ID (or write: \"no task ID\")"
    echo ""

    # --- Git update check ---
    bash "$ROOT_DIR/global_functions/check_for_updates.sh"

    read -p "🚀 Press Enter to open the file now..." _
    open "$AI_MESSAGE_FILE" 2>/dev/null || echo "⚠️ Could not open the file. Please open it manually: $AI_MESSAGE_FILE"

elif [[ "$OS" == "Linux" ]]; then
    echo ""
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        echo "🖼️  Graphical environment detected. Preparing export view..."
        echo ""
        echo "🤖 Copy the content of the opened file to your preferred AI tool (e.g., ChatGPT, DeepSeek, Gemini)"
        echo "📝 Then, include the related Project Task ID (or write: \"no task ID\")"
        echo ""

        # --- Git update check ---
        bash "$ROOT_DIR/global_functions/check_for_updates.sh"

        read -p "🚀 Press Enter to open the file now..." _
        xdg-open "$AI_MESSAGE_FILE" >/dev/null 2>&1 || echo "⚠️ Could not open the file. Please open it manually: $AI_MESSAGE_FILE"
    else
        echo "🖥️ CLI-only Linux detected."
        SNAPSHOT_FILE="$PARENT_DIR/merge_manual_snapshot.txt"

        echo "🧩 Creating text snapshot: $SNAPSHOT_FILE"
        cp "$AI_MESSAGE_FILE" "$SNAPSHOT_FILE"

        echo ""
        echo "📄 Snapshot saved to: $SNAPSHOT_FILE"
        echo ""
        echo "📋 To copy this content to clipboard, install one of the following:"
        echo ""
        echo "🧰 Ubuntu/Debian (X11):"
        echo "    sudo apt install xclip"
        echo ""
        echo "🧰 Wayland (GNOME/KDE):"
        echo "    sudo apt install wl-clipboard"
        echo ""
        echo "🧠 After installing, copy with:"
        echo "    xclip -selection clipboard < \"$SNAPSHOT_FILE\""
        echo "    # or"
        echo "    wl-copy < \"$SNAPSHOT_FILE\""
        echo ""
    fi
else
    echo "⚠️ Unknown OS. Please open the file manually:"
    echo "   $AI_MESSAGE_FILE"
fi

exit 0
