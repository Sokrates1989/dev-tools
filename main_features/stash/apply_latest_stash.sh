#!/bin/bash

echo ""
echo "🔄 Apply Latest Stash – Dev Tools"
echo "================================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to apply."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show the latest stash
echo ""
echo "📦 Latest stash to apply:"
LATEST_STASH=$(git stash list | head -n 1)
echo "  $LATEST_STASH"
echo ""

# Show current working directory status
echo "📋 Current working directory status:"
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "✅ Working directory is clean."
else
    echo "⚠️  Working directory has uncommitted changes:"
    git status --porcelain
    echo ""
    echo "⚠️  Warning: Applying stash may conflict with current changes."
fi

echo ""
read -p "🔄 Apply the latest stash? (This keeps the stash in the stash list) (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Apply operation cancelled."
    exit 1
fi

# Apply the latest stash
echo ""
echo "🔄 Applying latest stash..."
if git stash apply; then
    echo "✅ Successfully applied latest stash."
    echo ""
    echo "📦 Stash remains in the stash list:"
    echo "  $(git stash list | head -n 1)"
    echo ""
    echo "💡 Tip: Use 'Pop latest stash' to apply and remove the stash in one operation."
else
    echo "❌ Failed to apply stash. There may be conflicts."
    echo ""
    echo "💡 Tips for resolving conflicts:"
    echo "  • Check 'git status' for conflicted files"
    echo "  • Resolve conflicts manually and commit"
    echo "  • Use 'git stash drop' to remove the stash if no longer needed"
    exit 1
fi
