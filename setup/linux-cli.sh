#!/bin/bash

set -e

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo ""
  echo "❌ 'jq' is not installed."
  echo "📦 It is required to generate commit and merge messages using AI via API."
  echo ""
  read -p "👉 Do you want to install 'jq' now? [Y/n]: " installJq
  installJq=${installJq:-Y}

  if [[ "$installJq" =~ ^[Yy]$ ]]; then
    echo "🔧 Installing jq..."
    sudo apt update && sudo apt install -y jq
    echo "✅ 'jq' installed successfully."
  else
    echo "⚠️  Skipping 'jq' installation. AI-based commit and merge features will not work."
  fi
fi

# Install dev-tools.
echo ""
echo "🛠️  Installing Dev Tools (Linux CLI)"
echo "===================================="

# Step 1: Create target directory and clone Dev Tools
if [[ ! -d ~/tools/dev-tools/.git ]]; then
  echo "🔧 Cloning Dev Tools..."
  mkdir -p ~/tools/dev-tools
  cd ~/tools/dev-tools
  git clone https://github.com/Sokrates1989/dev-tools.git .
else
  echo "ℹ️  Dev Tools already cloned – skipping git clone."
  cd ~/tools/dev-tools
fi

# Step 2: Ensure script is executable
chmod +x ~/tools/dev-tools/start.sh

# Step 3: Create local bin directory if needed
mkdir -p ~/.local/bin

# Step 4: Create a global shortcut
ln -sf ~/tools/dev-tools/start.sh ~/.local/bin/dev-tools
echo "✅ Shortcut 'dev-tools' created in ~/.local/bin"

# Step 5: Add ~/.local/bin to PATH persistently and immediately
EXPORT_LINE='export PATH="$HOME/.local/bin:$PATH"'

# Function to append export line if not present
append_export_line() {
  local file="$1"
  if [ -f "$file" ]; then
    if ! grep -Fxq "$EXPORT_LINE" "$file"; then
      echo "$EXPORT_LINE" >> "$file"
      echo "✅ Added PATH update to $file"
    else
      echo "ℹ️  PATH already set in $file"
    fi
  fi
}

# Append to both .bashrc and .profile if available
append_export_line "$HOME/.bashrc"
append_export_line "$HOME/.profile"

# Export for current shell
export PATH="$HOME/.local/bin:$PATH"

# Detect if interactive shell (PS1 is usually set), otherwise forcefully reload
if [[ -z "$PS1" ]]; then
  # shell is non-interactive; let's try to simulate login shell load
  if [[ -f "$HOME/.bashrc" ]]; then
    source "$HOME/.bashrc"
  elif [[ -f "$HOME/.profile" ]]; then
    source "$HOME/.profile"
  fi
fi

# Step 6: Set up .env file
echo ""
echo "⚙️  Initial Configuration"
echo "=================================="
echo "Dev Tools uses a .env file to store settings."
echo ""
echo "👉 Please check the following values in your .env file:"
echo ""
echo "1. 🔄 AI_MODE        – Choose how AI-based features should work:"
echo "      • 'api'    → Uses your OpenAI or Azure API (recommended)"
echo "      • 'manual' → Prompts are printed for copy/paste into your favorite AI chat tool"
echo ""
echo "2. 🔑 API_KEY        – If using 'api' mode, you must provide your API key."
echo "3. 🌍 API_PROVIDER   – Choose between 'openai' or 'azure'."
echo "4. 💬 DEPLOYMENT     – Set your preferred model, e.g. 'gpt-4o-mini' or 'gpt-4o-2'."
echo ""

ENV_FILE=~/tools/dev-tools/.env
ENV_TEMPLATE=~/tools/dev-tools/.env.template

if [ ! -f "$ENV_FILE" ]; then
  cp "$ENV_TEMPLATE" "$ENV_FILE"
  echo "✅ Created '.env' from template."
else
  echo "ℹ️  '.env' already exists – skipping copy."
fi

# --- Interactive Editor Menu ---
echo ""
echo "📂 How would you like to open and edit your '.env' file now?"
echo ""
echo "1) ✏️  nano     – Easy terminal editor"
echo "2) 🧠 vi       – Power user terminal editor"
echo "3) 🔎 show     – Just print the full path to edit manually later"
echo "q) ⏭️  Skip for now – edit it manually later"
echo ""
read -p "Enter your choice [1-3, q]: " envChoice

case "$envChoice" in
  1)
    nano "$ENV_FILE"
    ;;
  2)
    vi "$ENV_FILE"
    ;;
  3)
    echo ""
    echo "📄 You can edit the file later using your preferred editor:"
    echo ""
    echo "   nano $ENV_FILE"
    echo "   vi $ENV_FILE"
    echo ""
    ;;
  q)
    echo "ℹ️  Skipping. Please edit '$ENV_FILE' later."
    ;;
  *)
    echo "❌ Invalid choice – skipping for now."
    ;;
esac

echo ""
echo "🚀 All set! You can now launch the Dev Tools from any terminal with:"
echo ""
echo "   dev-tools"
echo ""
echo "💡 Tip: Use 'dev-tools -c' to generate commit messages from Git changes using AI."

echo ""
echo "🧩 If 'dev-tools' is not recognized yet, you can try the following to make it work immediately:"
echo '   export PATH="$HOME/.local/bin:$PATH"; hash -r'
