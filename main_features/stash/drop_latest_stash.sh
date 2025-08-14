#!/bin/bash

echo ""
echo "🗑️  Drop Latest Stash – Dev Tools"
echo "================================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to drop."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show the latest stash
echo ""
echo "📦 Latest stash to drop:"
LATEST_STASH=$(git stash list | head -n 1)
echo "  $LATEST_STASH"
echo ""

echo "⚠️  Warning: This will permanently delete the stash without applying it."
echo ""
read -p "🗑️  Drop the latest stash permanently? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Drop operation cancelled."
    exit 1
fi

# Drop the latest stash
echo ""
echo "🗑️  Dropping latest stash..."
if git stash drop stash@{0}; then
    echo "✅ Successfully dropped latest stash."
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
    echo "❌ Failed to drop stash."
    exit 1
fi
