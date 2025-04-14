# Step 1: Create target directory and clone Dev Tools.
if [[ ! -d ~/tools/dev-tools/.git ]]; then
  mkdir -p ~/tools/dev-tools
  cd ~/tools/dev-tools
  git clone https://github.com/Sokrates1989/dev-tools.git .
else
  echo "ℹ️ Dev Tools already cloned – skipping git clone."
  cd ~/tools/dev-tools
fi

# Step 2: Ensure script is executable.
chmod +x ~/tools/dev-tools/start.sh

# Step 3: Create a local bin directory if needed.
mkdir -p ~/.local/bin

# Step 4: Create a global shortcut called 'dev-tools'.
ln -sf ~/tools/dev-tools/start.sh ~/.local/bin/dev-tools

# Step 5: Add ~/.local/bin to PATH (only if not already set).
CURRENT_SHELL=$(basename "$SHELL")
EXPORT_LINE='export PATH="$HOME/.local/bin:$PATH"'

if [[ "$CURRENT_SHELL" == "zsh" ]]; then
  SHELL_RC="$HOME/.zshrc"
elif [[ "$CURRENT_SHELL" == "bash" ]]; then
  SHELL_RC="$HOME/.bashrc"
else
  echo "⚠️ Unknown shell: $CURRENT_SHELL – please add ~/.local/bin to your PATH manually."
  SHELL_RC=""
fi

if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
  if ! grep -Fxq "$EXPORT_LINE" "$SHELL_RC"; then
    echo "$EXPORT_LINE" >> "$SHELL_RC"
    echo "✅ Added PATH update to $SHELL_RC"
    source "$SHELL_RC"
  else
    echo "ℹ️ PATH already set in $SHELL_RC"
  fi
fi

# Step 6: Set up .env file.
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
echo "💡 You can also edit the temperature and max token settings in 'api' mode."
echo ""

# Use full paths
ENV_FILE=~/tools/dev-tools/.env
ENV_TEMPLATE=~/tools/dev-tools/.env.template

# Copy .env.template to .env if not already present
cp -n "$ENV_TEMPLATE" "$ENV_FILE" && echo "✅ Created '.env' from template." || echo "ℹ️  '.env' already exists – skipping copy."

# --- Interactive Editor Menu ---
echo ""
echo "📂 How would you like to open and edit your '.env' file now?"
echo ""
echo "1) ✏️  nano     – Easy terminal editor"
echo "2) 🧠 vi       – Power user terminal editor"
echo "3) 📁 open     – Open folder in file explorer"
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
    open ~/tools/dev-tools 2>/dev/null || xdg-open ~/tools/dev-tools 2>/dev/null || echo "⚠️  Could not open file explorer – open the folder manually."
    ;;
  q)
    echo "ℹ️  Skipping. Please edit '~/tools/dev-tools/.env' later."
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