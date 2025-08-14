#!/bin/bash

echo ""
echo "🗑️  Clear All Stashes – Dev Tools"
echo "================================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to clear."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show all stashes that will be cleared
echo ""
echo "📦 All stashes that will be permanently deleted:"
echo ""
git stash list --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %C(blue)%s%C(reset)" | nl -w3 -s') '

echo ""
echo "⚠️  WARNING: This will permanently delete ALL $STASH_COUNT stashes without applying them."
echo "⚠️  This action cannot be undone!"
echo ""
read -p "🗑️  Clear all stashes permanently? Type 'DELETE ALL' to confirm: " confirm

if [[ "$confirm" != "DELETE ALL" ]]; then
    echo "❌ Clear operation cancelled."
    echo "💡 You must type 'DELETE ALL' exactly to confirm this destructive operation."
    exit 1
fi

# Clear all stashes
echo ""
echo "🗑️  Clearing all stashes..."
if git stash clear; then
    echo "✅ Successfully cleared all stashes."
    echo "📦 No stashes remaining."
else
    echo "❌ Failed to clear stashes."
    exit 1
fi
