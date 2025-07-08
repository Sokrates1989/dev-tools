#!/bin/bash

echo "🗑️  Dev Tools Uninstaller"
echo "=========================="
echo "This will completely remove Dev Tools and all its components."
echo ""

# Confirm uninstallation
read -p "Are you sure you want to uninstall Dev Tools? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Uninstallation cancelled."
    exit 0
fi

echo ""
echo "🧹 Removing Dev Tools components..."

# Step 1: Remove the global shortcut
if [[ -L ~/.local/bin/dev-tools ]]; then
    rm ~/.local/bin/dev-tools
    echo "✅ Removed global shortcut: ~/.local/bin/dev-tools"
else
    echo "ℹ️  Global shortcut not found"
fi

# Step 2: Remove the dev-tools directory
if [[ -d ~/tools/dev-tools ]]; then
    rm -rf ~/tools/dev-tools
    echo "✅ Removed dev-tools directory: ~/tools/dev-tools"
else
    echo "ℹ️  Dev-tools directory not found"
fi

# Step 3: Remove ~/.local/bin from PATH if it was added by the setup script
CURRENT_SHELL=$(basename "$SHELL")
EXPORT_LINE='export PATH="$HOME/.local/bin:$PATH"'

if [[ "$CURRENT_SHELL" == "zsh" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$CURRENT_SHELL" == "bash" ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    echo "⚠️  Unknown shell: $CURRENT_SHELL – please check your shell config manually"
    SHELL_RC=""
fi

if [[ -n "$SHELL_RC" && -f "$SHELL_RC" ]]; then
    # Check if the PATH line was added by our setup script
    if grep -Fxq "$EXPORT_LINE" "$SHELL_RC"; then
        # Remove the line
        sed -i.bak "/^export PATH=\"\$HOME\/\.local\/bin:\$PATH\"$/d" "$SHELL_RC"
        echo "✅ Removed PATH update from $SHELL_RC"
        echo "ℹ️  Backup created as $SHELL_RC.bak"
    else
        echo "ℹ️  PATH line not found in $SHELL_RC (may have been added manually)"
    fi
fi

# Step 4: Remove ~/.local/bin directory if it's empty
if [[ -d ~/.local/bin ]] && [[ -z "$(ls -A ~/.local/bin)" ]]; then
    rmdir ~/.local/bin
    echo "✅ Removed empty ~/.local/bin directory"
else
    echo "ℹ️  ~/.local/bin directory not empty or not found - keeping it"
fi

# Step 5: Remove ~/tools directory if it's empty
if [[ -d ~/tools ]] && [[ -z "$(ls -A ~/tools)" ]]; then
    rmdir ~/tools
    echo "✅ Removed empty ~/tools directory"
else
    echo "ℹ️  ~/tools directory not empty or not found - keeping it"
fi

echo ""
echo "🎉 Dev Tools has been completely uninstalled!"
echo ""
echo "To reinstall, run:"
echo "  bash ~/path/to/dev-tools/setup/macos.sh"
echo ""
echo "Note: You may need to restart your terminal or run 'source ~/.zshrc' (or ~/.bashrc) for PATH changes to take effect." 