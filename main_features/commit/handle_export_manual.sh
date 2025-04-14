
# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARENT_DIR="$SCRIPT_DIR/git_export_staged"
DEST_DIR="$SCRIPT_DIR/git_export_staged/changed_files"
DIFF_FILE="$SCRIPT_DIR/git_export_staged/last_staged_commit_diff.txt"
ALL_IN_ONE_DIR="$SCRIPT_DIR/git_export_staged/all_in_one"
ALL_IN_ONE_AI_MESSAGE_FILE="$ALL_IN_ONE_DIR/ai_message.txt"
COMMIT_MSG_FILE="$SCRIPT_DIR/commit_message_prompt.txt"

# Load environment variables.
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi


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
    echo "🤖 Copy the content of the opened folder to your preferred AI tool,"
    echo "   or alternatively just paste the file:"
    echo "   → $ALL_IN_ONE_AI_MESSAGE_FILE"
    echo ""
    echo "📝 Then, add the related Project Task ID (if available), or write: \"no task ID\""
    echo ""
}



# Platform-specific: macOS or Linux open dest folder.
OS=$(uname)

# ---- Platform-specific export handling ----
if [[ "$OS" == "Darwin" ]]; then
    echo ""
    echo "🖼️  macOS environment detected. Preparing export view..."
    print_export_instructions

    # --- Git update check ---
    bash "$ROOT_DIR/global_functions/check_for_updates.sh"

    read -p "🚀 Press Enter to open the folder now..."
    open "$PARENT_DIR"

elif [[ "$OS" == "Linux" ]]; then
    echo ""
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        echo ""
        echo "🖼️  Graphical environment detected. Preparing export view..."
        print_export_instructions

        # --- Git update check ---
        bash "$ROOT_DIR/global_functions/check_for_updates.sh"

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
bash "$ROOT_DIR/global_functions/check_for_updates.sh"