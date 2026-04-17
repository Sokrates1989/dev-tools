#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
INSTRUCTIONS_DIR="$ROOT_DIR/main_features/readme/instructions"

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

OS=$(uname)

echo ""
echo "📘 README Creation Instructions"
echo "==============================="
echo ""
echo "🧠 Step 1: Open your preferred AI assistant:"
echo "   → ChatGPT, DeepSeek, Gemini, Claude, etc."
echo ""
echo "💬 Step 2: Tell the AI what this README should be about."
echo "   Example:"
echo "     'Create a professional README for a backend service that handles user registration and login.'"
echo ""
echo "📎 Step 3: Copy the contents of the folder that will be opened next:"
echo "   → This includes two useful files:"
echo "     • ai_instructions.txt – contains formatting guidance"
echo "     • template.md – a customizable README scaffold"
echo ""
echo "🗂️ Step 4: Paste both files into your AI chat."
echo ""
echo "📄 Step 5: Optionally, upload or paste any relevant files the AI should consider:"
echo "   • source code files"
echo "   • configuration files (e.g. .env, Dockerfile)"
echo "   • architecture diagrams"
echo ""
echo "✏️ Step 6: After receiving the generated README:"
echo "   → Replace all occurrences of ';;;' with '\`\`\`' (triple backticks)"
echo "     This ensures correct markdown formatting."
echo ""
echo "💡 The more context and examples you provide, the better the resulting README."
echo ""

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

# Read instruction files content for clipboard/terminal options
ai_instructions_file="$INSTRUCTIONS_DIR/ai_instructions.txt"
template_file="$INSTRUCTIONS_DIR/template.md"
combined_content=""

if [[ -f "$ai_instructions_file" && -f "$template_file" ]]; then
    ai_instructions=$(cat "$ai_instructions_file" 2>/dev/null || echo "")
    template=$(cat "$template_file" 2>/dev/null || echo "")
    combined_content="=== AI INSTRUCTIONS ===

$ai_instructions

=== README TEMPLATE ===

$template"
else
    echo "Warning: Could not read instruction files" >&2
fi

echo ""
echo "I will now attempt all 4 methods to make the README instructions accessible:"
echo ""

# Method 1: Open instructions folder in file manager
echo "1) Opening instructions folder in file manager..."
explorer_success=false
if [[ "$OS" == "Darwin" ]]; then
    if command -v open >/dev/null 2>&1; then
        if open "$INSTRUCTIONS_DIR" 2>/dev/null; then
            echo "   Instructions folder opened in Finder." && explorer_success=true
        else
            echo "   Failed to open in Finder."
        fi
    else
        echo "   open command not available. Folder path: $INSTRUCTIONS_DIR"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        if command -v nautilus >/dev/null 2>&1; then
            if nautilus "$INSTRUCTIONS_DIR" 2>/dev/null; then
                echo "   Instructions folder opened in Nautilus." && explorer_success=true
            else
                echo "   Failed to open in Nautilus."
            fi
        elif command -v dolphin >/dev/null 2>&1; then
            if dolphin "$INSTRUCTIONS_DIR" 2>/dev/null; then
                echo "   Instructions folder opened in Dolphin." && explorer_success=true
            else
                echo "   Failed to open in Dolphin."
            fi
        elif command -v thunar >/dev/null 2>&1; then
            if thunar "$INSTRUCTIONS_DIR" 2>/dev/null; then
                echo "   Instructions folder opened in Thunar." && explorer_success=true
            else
                echo "   Failed to open in Thunar."
            fi
        elif command -v xdg-open >/dev/null 2>&1; then
            if xdg-open "$INSTRUCTIONS_DIR" 2>/dev/null; then
                echo "   Opened instructions folder." && explorer_success=true
            else
                echo "   Failed to open folder."
            fi
        else
            echo "   No suitable file manager found. Folder path: $INSTRUCTIONS_DIR"
        fi
    else
        echo "   CLI-only Linux detected. Folder path: $INSTRUCTIONS_DIR"
    fi
else
    echo "   Unknown OS. Folder path: $INSTRUCTIONS_DIR"
fi

# Method 2: Open ai_instructions.txt with default editor
echo "2) Opening ai_instructions.txt with default editor..."
editor_success=false
if [[ "$OS" == "Darwin" ]]; then
    if command -v open >/dev/null 2>&1; then
        if open "$ai_instructions_file" 2>/dev/null; then
            echo "   AI instructions file opened with default editor." && editor_success=true
        else
            echo "   Failed to open with default editor."
        fi
    else
        echo "   open command not available. File path: $ai_instructions_file"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v xdg-open >/dev/null 2>&1; then
        if xdg-open "$ai_instructions_file" 2>/dev/null; then
            echo "   AI instructions file opened with default editor." && editor_success=true
        else
            echo "   Failed to open with default editor."
        fi
    else
        echo "   xdg-open not available. File path: $ai_instructions_file"
    fi
else
    echo "   Unknown OS. File path: $ai_instructions_file"
fi

# Method 3: Copy all instructions to clipboard with verification
echo "3) Copying instructions to clipboard..."
clipboard_success=false
clipboard_method=""
if [[ "$OS" == "Darwin" ]]; then
    if command -v pbcopy >/dev/null 2>&1; then
        if echo "$combined_content" | pbcopy 2>/dev/null; then
            clipboard_method="pbcopy"
            # Try to verify clipboard on macOS
            sleep 0.1
            if command -v pbpaste >/dev/null 2>&1; then
                clipboard_test=$(pbpaste 2>/dev/null || echo "")
                if [[ "$clipboard_test" == "$combined_content" ]]; then
                    echo "   Instructions successfully copied to clipboard ($clipboard_method) - VERIFIED!" && clipboard_success=true
                else
                    echo "   Clipboard copy attempted but verification failed."
                fi
            else
                echo "   Instructions copied to clipboard ($clipboard_method) - verification not available." && clipboard_success=true
            fi
        else
            echo "   Failed to copy to clipboard."
        fi
    else
        echo "   pbcopy not available."
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v xclip >/dev/null 2>&1; then
        if echo "$combined_content" | xclip -selection clipboard 2>/dev/null; then
            clipboard_method="xclip"
            # Try to verify clipboard on Linux with xclip
            sleep 0.1
            clipboard_test=$(xclip -selection clipboard -o 2>/dev/null || echo "")
            if [[ "$clipboard_test" == "$combined_content" ]]; then
                echo "   Instructions successfully copied to clipboard ($clipboard_method) - VERIFIED!" && clipboard_success=true
            else
                echo "   Clipboard copy attempted but verification failed."
            fi
        else
            echo "   Failed to copy to clipboard."
        fi
    elif command -v wl-copy >/dev/null 2>&1; then
        if echo "$combined_content" | wl-copy 2>/dev/null; then
            clipboard_method="wl-copy"
            # Try to verify clipboard on Linux with wl-copy
            sleep 0.1
            if command -v wl-paste >/dev/null 2>&1; then
                clipboard_test=$(wl-paste 2>/dev/null || echo "")
                if [[ "$clipboard_test" == "$combined_content" ]]; then
                    echo "   Instructions successfully copied to clipboard ($clipboard_method) - VERIFIED!" && clipboard_success=true
                else
                    echo "   Clipboard copy attempted but verification failed."
                fi
            else
                echo "   Instructions copied to clipboard ($clipboard_method) - verification not available." && clipboard_success=true
            fi
        else
            echo "   Failed to copy to clipboard."
        fi
    else
        echo "   No clipboard tool available (install xclip or wl-copy)."
    fi
else
    echo "   Unknown OS."
fi

# Method 4: Display all instructions in terminal
echo "4) Displaying all instructions in terminal..."
terminal_success=false
if [[ -n "$combined_content" ]]; then
    echo "   Instructions displayed in terminal below:" && terminal_success=true
    echo ""
    echo "=== README INSTRUCTIONS ==="
    echo "$combined_content"
    echo "=== END OF INSTRUCTIONS ==="
else
    echo "   Could not read instruction files content."
    echo "   Folder path: $INSTRUCTIONS_DIR"
fi

# Summary
echo ""
echo "=== ATTEMPT SUMMARY ==="
echo "Folder open:    $(if [[ "$explorer_success" == true ]]; then echo "SUCCESS"; else echo "FAILED"; fi)"
echo "Editor open:    $(if [[ "$editor_success" == true ]]; then echo "SUCCESS"; else echo "FAILED"; fi)"
echo "Clipboard copy: $(if [[ "$clipboard_success" == true ]]; then echo "SUCCESS - VERIFIED"; else echo "FAILED"; fi)"
echo "Terminal display: $(if [[ "$terminal_success" == true ]]; then echo "SUCCESS"; else echo "FAILED"; fi)"

if [[ "$clipboard_success" == true ]]; then
    echo ""
    echo "EXCELLENT! The README instructions are now in your clipboard."
    echo "You can paste them directly into your external AI chat."
else
    echo ""
    echo "Clipboard copy failed, but you can:"
    echo "- Copy the content from the terminal display above"
    echo "- Use the folder path to open manually: $INSTRUCTIONS_DIR"
fi

echo ""
echo "Done! Use the README instructions with your external AI."
