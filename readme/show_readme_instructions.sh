#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTRUCTIONS_DIR="$SCRIPT_DIR/readme/instructions"

# --- Git update check ---
bash "$SCRIPT_DIR/check_for_updates.sh"

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
bash "$SCRIPT_DIR/check_for_updates.sh"

# Open the instructions folder
if [[ "$OS" == "Darwin" ]]; then
    echo "🖼️  macOS detected."
    read -p "📂 Press Enter to open the README instructions folder in Finder..." 
    open "$INSTRUCTIONS_DIR"

elif [[ "$OS" == "Linux" ]]; then
    if [[ -n "$DISPLAY" || -n "$WAYLAND_DISPLAY" ]]; then
        echo "🖼️  Linux graphical environment detected."
        read -p "📂 Press Enter to open the README instructions folder..." 
        xdg-open "$INSTRUCTIONS_DIR" >/dev/null 2>&1 &
    else
        echo "🖥️ CLI-only Linux detected."
        echo "📎 Manually open and copy:"
        echo "    $INSTRUCTIONS_DIR/template.md"
        echo "    $INSTRUCTIONS_DIR/ai_instructions.txt"
    fi
else
    echo "⚠️ Unknown OS. Please open this folder manually:"
    echo "   $INSTRUCTIONS_DIR"
fi

echo ""
echo "✅ Once the folder is opened, copy and paste the contents into your AI chat to begin."
