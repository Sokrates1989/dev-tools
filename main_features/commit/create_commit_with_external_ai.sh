#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROMPT_FILE="$SCRIPT_DIR/commit_message_prompt.txt"
OS=$(uname)

if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "❌ Commit style guide not found: $PROMPT_FILE"
    exit 1
fi

echo ""
echo "Commit Style Guide for External AI"
echo "=================================="
echo "Create styled commit message with external AI!"
echo "=================================="
echo ""
echo "1) Open your AI (ChatGPT, Claude, etc.)"
echo ""
echo "2) (optional) Tell the AI what Jira Task ID or code version should be added to the commit message, if desired."
echo "   (use these exact words. JIRA_ID_PLACEHOLDER , VERSION_PLACEHOLDER)"
echo ""
echo "3) I will now attempt to copy the instructions to your clipboard."
echo ""
echo "Press Enter to begin, or Ctrl+C to cancel..."
read -r
echo ""
echo ""

# Read the prompt content once for multiple uses
prompt_content=""
if [[ -f "$PROMPT_FILE" ]]; then
    prompt_content=$(cat "$PROMPT_FILE" 2>/dev/null || echo "")
fi

# Try clipboard copy with better error handling
clipboard_success=false
echo "Attempting to copy instructions to clipboard..."

# Get key content markers for verification
original_length=${#prompt_content}
key_phrases=(
    "STYLE INSTRUCTION - HIGH PRIORITY"
    "PLACEHOLDER HANDLING - CRITICAL"
    "OUTPUT FORMAT"
    "git commit -m"
    "PLACEHOLDER DECISION RULES"
    "EXAMPLES"
    "New Feature"
)

if [[ "$OS" == "Darwin" ]]; then
    if command -v pbcopy >/dev/null 2>&1; then
        if echo "$prompt_content" | pbcopy 2>/dev/null; then
            sleep 1
            
            if command -v pbpaste >/dev/null 2>&1; then
                clipboard_test=$(pbpaste 2>/dev/null || echo "")
                clipboard_length=${#clipboard_test}
                
                # More lenient length check
                if [[ $clipboard_length -gt 100 && $clipboard_length -gt $((original_length * 7 / 10)) ]]; then
                    found_phrases=0
                    for phrase in "${key_phrases[@]}"; do
                        if [[ "$clipboard_test" == *"$phrase"* ]]; then
                            ((found_phrases++))
                        fi
                    done
                    
                    # More lenient check - if we find most key phrases, consider it successful
                    if [[ $found_phrases -ge $((${#key_phrases[@]} * 5 / 10)) ]]; then
                        echo "SUCCESS! Instructions copied to clipboard." && clipboard_success=true
                    else
                        echo "Clipboard copy may have succeeded but verification unclear." && clipboard_success=true
                    fi
                else
                    echo "Clipboard content seems incomplete."
                fi
            else
                echo "SUCCESS! Instructions copied to clipboard." && clipboard_success=true
            fi
        else
            echo "Failed to copy with pbcopy."
        fi
    else
        echo "pbcopy not available."
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v xclip >/dev/null 2>&1; then
        if echo "$prompt_content" | xclip -selection clipboard 2>/dev/null; then
            sleep 1
            
            clipboard_test=$(xclip -selection clipboard -o 2>/dev/null || echo "")
            clipboard_length=${#clipboard_test}
            
            if [[ $clipboard_length -gt 100 && $clipboard_length -gt $((original_length * 7 / 10)) ]]; then
                found_phrases=0
                for phrase in "${key_phrases[@]}"; do
                    if [[ "$clipboard_test" == *"$phrase"* ]]; then
                        ((found_phrases++))
                    fi
                done
                
                if [[ $found_phrases -ge $((${#key_phrases[@]} * 5 / 10)) ]]; then
                    echo "SUCCESS! Instructions copied to clipboard." && clipboard_success=true
                else
                    echo "Clipboard copy may have succeeded but verification unclear." && clipboard_success=true
                fi
            else
                echo "Clipboard content seems incomplete."
            fi
        else
            echo "Failed to copy with xclip."
        fi
    elif command -v wl-copy >/dev/null 2>&1; then
        if echo "$prompt_content" | wl-copy 2>/dev/null; then
            sleep 1
            
            if command -v wl-paste >/dev/null 2>&1; then
                clipboard_test=$(wl-paste 2>/dev/null || echo "")
                clipboard_length=${#clipboard_test}
                
                if [[ $clipboard_length -gt 100 && $clipboard_length -gt $((original_length * 7 / 10)) ]]; then
                    found_phrases=0
                    for phrase in "${key_phrases[@]}"; do
                        if [[ "$clipboard_test" == *"$phrase"* ]]; then
                            ((found_phrases++))
                        fi
                    done
                    
                    if [[ $found_phrases -ge $((${#key_phrases[@]} * 5 / 10)) ]]; then
                        echo "SUCCESS! Instructions copied to clipboard." && clipboard_success=true
                    else
                        echo "Clipboard copy may have succeeded but verification unclear." && clipboard_success=true
                    fi
                else
                    echo "Clipboard content seems incomplete."
                fi
            else
                echo "SUCCESS! Instructions copied to clipboard." && clipboard_success=true
            fi
        else
            echo "Failed to copy with wl-copy."
        fi
    else
        echo "No clipboard tool available (install xclip or wl-copy)."
    fi
else
    echo "Unknown OS."
fi

# If clipboard succeeded, we're done
if [[ "$clipboard_success" == true ]]; then
    echo ""
    echo "Paste into your external AI and ask for a commit message!"
    exit 0
fi

# If clipboard failed, offer file access methods
echo ""
echo "Clipboard failed. Opening file access methods..."
echo ""

# Method 1: Reveal file in file manager
echo "1) Revealing file in file manager..."
if [[ "$OS" == "Darwin" ]]; then
    if command -v open >/dev/null 2>&1; then
        if open -R "$PROMPT_FILE" 2>/dev/null; then
            echo "   File revealed in Finder."
        else
            echo "   Failed to reveal in Finder."
        fi
    else
        echo "   open command not available. File path: $PROMPT_FILE"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        if command -v nautilus >/dev/null 2>&1; then
            if nautilus --select "$PROMPT_FILE" 2>/dev/null; then
                echo "   File revealed in Nautilus."
            else
                echo "   Failed to reveal in Nautilus."
            fi
        elif command -v dolphin >/dev/null 2>&1; then
            if dolphin --select "$PROMPT_FILE" 2>/dev/null; then
                echo "   File revealed in Dolphin."
            else
                echo "   Failed to reveal in Dolphin."
            fi
        elif command -v thunar >/dev/null 2>&1; then
            if thunar "$PROMPT_FILE" 2>/dev/null; then
                echo "   File opened in Thunar."
            else
                echo "   Failed to open in Thunar."
            fi
        elif command -v xdg-open >/dev/null 2>&1; then
            if xdg-open "$SCRIPT_DIR" 2>/dev/null; then
                echo "   Opened containing directory."
            else
                echo "   Failed to open directory."
            fi
        else
            echo "   No suitable file manager found. File path: $PROMPT_FILE"
        fi
    else
        echo "   CLI-only Linux detected. File path: $PROMPT_FILE"
    fi
else
    echo "   Unknown OS. File path: $PROMPT_FILE"
fi

# Method 2: Auto-open with default editor
echo "2) Opening with default editor..."
if [[ "$OS" == "Darwin" ]]; then
    if command -v open >/dev/null 2>&1; then
        if open "$PROMPT_FILE" 2>/dev/null; then
            echo "   File opened with default editor."
        else
            echo "   Failed to open with default editor."
        fi
    else
        echo "   open command not available. File path: $PROMPT_FILE"
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v xdg-open >/dev/null 2>&1; then
        if xdg-open "$PROMPT_FILE" 2>/dev/null; then
            echo "   File opened with default editor."
        else
            echo "   Failed to open with default editor."
        fi
    else
        echo "   xdg-open not available. File path: $PROMPT_FILE"
    fi
else
    echo "   Unknown OS. File path: $PROMPT_FILE"
fi

# Method 3: Display in terminal
echo "3) Displaying in terminal..."
if [[ -n "$prompt_content" ]]; then
    echo "   Content displayed in terminal below:"
    echo ""
    echo "=== COMMIT STYLE GUIDE ==="
    echo "$prompt_content"
    echo "=== END OF GUIDE ==="
else
    echo "   Could not read the prompt file content."
    echo "   File path: $PROMPT_FILE"
fi

echo ""
echo "Copy the content manually and paste into your external AI."
