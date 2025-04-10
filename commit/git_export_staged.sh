#!/bin/bash

# -----------------------------------------------------------------------------
# Script: git_export_staged.sh
#
# Description:
# This script does two things:
# 1. Exports the current staged diff using `git diff --staged` into a file
#    named `last_staged_commit_diff.txt`.
# 2. Copies all staged files into a flat folder named `changedFiles/`,
#    stripping away any directory structure.
#
# Useful for code review, CI pipelines, pre-commit backups, or patch creation.
# -----------------------------------------------------------------------------

# Resolve script location (so paths work anywhere).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="$SCRIPT_DIR/git_export_staged/changed_files"
DIFF_FILE="$SCRIPT_DIR/git_export_staged/last_staged_commit_diff.txt"

# --- Git update check ---
bash "$ROOT_DIR/check_for_updates.sh"

# ✅ Define the function early
print_export_instructions() {
    echo ""
    if [[ "$OS" == "Darwin" ]]; then
        echo "📂 Export folder will open in Finder."
        echo "🔍 To see all files (e.g., .gitignore): Press ⌘ + Shift + ."
    elif [[ "$OS" == "Linux" ]]; then
        echo "📂 Export folder will open in your file manager."
        echo "🔍 To see all files (e.g., .gitignore): Press Ctrl + H"
    fi
    echo ""
    echo "🤖 Copy the content of the opened folder to your preferred AI tool."
    echo ""
    echo "📝 Add the related Project Task ID (if available) in the chat, or just write: \"no task ID\""
    echo ""
}


# Clean up previous outputs.
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
rm -f "$DIFF_FILE"

# Export staged diff to file.
git diff --staged > "$DIFF_FILE"

# Get list of staged files.
FILES=$(git diff --name-only --cached)

# Exit early if no staged files.
if [[ -z "$FILES" ]]; then
    echo "⚠️  No staged files found. Please stage some changes with 'git add' before running this script."
    exit 0
fi

# Copy staged files to the flat destination directory.
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        cp "$file" "$DEST_DIR/$(basename "$file")"
    fi
done <<< "$FILES"

# Summary output.
echo "✅ Copied staged files to $DEST_DIR:"
ls -1 "$DEST_DIR"
echo ""
echo "📝 Staged diff saved to $DIFF_FILE"


# Copy commit_message_prompt.txt if available
COMMIT_MSG_FILE="$SCRIPT_DIR/commit_message_prompt.txt"
if [[ -f "$COMMIT_MSG_FILE" ]]; then
    cp "$COMMIT_MSG_FILE" "$SCRIPT_DIR/git_export_staged/"
    echo "📝 Copied commit_message_prompt.txt to export folder."
fi


# Platform-specific: macOS or Linux open dest folder.
OS=$(uname)
PARENT_DIR="$SCRIPT_DIR/git_export_staged"

# ---- Platform-specific export handling ----
if [[ "$OS" == "Darwin" ]]; then
    echo ""
    echo "🖼️  macOS environment detected. Preparing export view..."
    print_export_instructions
    read -p "🚀 Press Enter to open the folder now..."
    open "$PARENT_DIR"

elif [[ "$OS" == "Linux" ]]; then
    echo ""
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        echo ""
        echo "🖼️  Graphical environment detected. Preparing export view..."
        print_export_instructions
        read -p "🚀 Press Enter to open the folder now..."
        xdg-open "$PARENT_DIR" >/dev/null 2>&1 &
    else
        echo "🖥️ CLI-only Linux detected."
        SNAPSHOT_FILE="$PARENT_DIR/combined_staged_snapshot.txt"

        echo "🧩 Creating combined snapshot: $SNAPSHOT_FILE"

        {
            echo "===== 📝 COMMIT MESSAGE PROMPT ====="
            if [[ -f "$SCRIPT_DIR/commit_message_prompt.txt" ]]; then
                cat "$SCRIPT_DIR/commit_message_prompt.txt"
            else
                echo "(no commit_message_prompt.txt found)"
            fi
            echo ""
            echo "===== 🔍 STAGED DIFF ====="
            cat "$DIFF_FILE"
            echo ""
            echo "===== 📁 STAGED FILE CONTENTS ====="
            for file in $FILES; do
                if [[ -f "$file" ]]; then
                    echo "--- $(basename "$file") ---"
                    cat "$file"
                    echo ""
                fi
            done
        } > "$SNAPSHOT_FILE"

        echo ""
        echo "📄 Snapshot saved to: $SNAPSHOT_FILE"
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
    echo "⚠️ Unknown OS. Please open the folder manually: $PARENT_DIR"
fi

# --- Git update check ---
bash "$ROOT_DIR/check_for_updates.sh"

exit 0