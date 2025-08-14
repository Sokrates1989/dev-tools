#!/bin/bash

echo ""
echo "📦 Stash Tracked Changes Only – Dev Tools"
echo "========================================="

# Check if there are any tracked changes to stash
if git diff --quiet && git diff --cached --quiet; then
    echo "✅ No tracked changes to stash."
    
    # Check if there are untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        echo ""
        echo "📄 Untracked files found (will NOT be stashed):"
        git ls-files --others --exclude-standard
        echo ""
        echo "💡 Tip: Use 'Stash all changes (including untracked)' to include untracked files."
    fi
    exit 0
fi

# Show what will be stashed
echo ""
echo "📋 Tracked changes that will be stashed:"
echo ""
echo "🔄 Modified files:"
git diff --name-only
echo ""
echo "📁 Staged files:"
git diff --cached --name-only

# Show untracked files that won't be stashed
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo ""
    echo "📄 Untracked files (will NOT be stashed):"
    git ls-files --others --exclude-standard
fi
echo ""

# Confirm action
read -p "💾 Stash tracked changes only? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Stash operation cancelled."
    exit 1
fi

# Perform stash of tracked files only
echo ""
echo "📦 Stashing tracked changes..."
if git stash push -m "Tracked changes stash created on $(date '+%Y-%m-%d %H:%M:%S')"; then
    echo "✅ Successfully stashed tracked changes."
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
