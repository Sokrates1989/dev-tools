#!/bin/bash

echo ""
echo "📦 Stash All Changes (Including Untracked) – Dev Tools"
echo "====================================================="

# Check if there are any changes to stash
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "✅ No changes to stash. Working directory is clean."
    exit 0
fi

# Show what will be stashed
echo ""
echo "📋 Changes that will be stashed:"
echo ""
echo "🔄 Modified files:"
git diff --name-only
echo ""
echo "📁 Staged files:"
git diff --cached --name-only
echo ""
echo "📄 Untracked files:"
git ls-files --others --exclude-standard
echo ""

# Confirm action
read -p "💾 Stash all changes including untracked files? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Stash operation cancelled."
    exit 1
fi

# Perform stash with untracked files
echo ""
echo "📦 Stashing changes..."
if git stash push --include-untracked -m "Stash created on $(date '+%Y-%m-%d %H:%M:%S')"; then
    echo "✅ Successfully stashed all changes including untracked files."
    echo ""
    echo "📦 Current stash list:"
    git stash list | head -n 3
    if [[ $(git stash list | wc -l) -gt 3 ]]; then
        echo "... and $(($(git stash list | wc -l) - 3)) more stashes"
    fi
else
    echo "❌ Failed to stash changes."
    exit 1
fi
