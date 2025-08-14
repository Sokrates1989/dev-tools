#!/bin/bash

echo ""
echo "🔄 Pop Latest Stash – Dev Tools"
echo "==============================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to pop."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show the latest stash
echo ""
echo "📦 Latest stash to pop:"
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
    echo "⚠️  Warning: Popping stash may conflict with current changes."
fi

echo ""
read -p "🔄 Pop the latest stash? (This applies and removes the stash) (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Pop operation cancelled."
    exit 1
fi

# Pop the latest stash
echo ""
echo "🔄 Popping latest stash..."
if git stash pop; then
    echo "✅ Successfully popped latest stash."
    echo ""
    REMAINING_STASHES=$(git stash list | wc -l | tr -d ' ')
    if [[ $REMAINING_STASHES -gt 0 ]]; then
        echo "📦 Remaining stashes: $REMAINING_STASHES"
        git stash list | head -n 3
        if [[ $REMAINING_STASHES -gt 3 ]]; then
            echo "... and $((REMAINING_STASHES - 3)) more stashes"
        fi
    else
        echo "📦 No more stashes remaining."
    fi
else
    echo "❌ Failed to pop stash. There may be conflicts."
    echo ""
    echo "💡 Tips for resolving conflicts:"
    echo "  • Check 'git status' for conflicted files"
    echo "  • Resolve conflicts manually and commit"
    echo "  • The stash remains in the stash list until conflicts are resolved"
    exit 1
fi
