#!/bin/bash

echo ""
echo "🔍 Show Latest Stash Content – Dev Tools"
echo "========================================"

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to show."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show the latest stash info
echo ""
echo "📦 Latest stash:"
LATEST_STASH=$(git stash list | head -n 1)
echo "  $LATEST_STASH"
echo ""

echo "📋 Stash content:"
echo "=================="
echo ""

# Show the stash content with diff
git stash show -p stash@{0}

echo ""
echo "💡 Tips:"
echo "  • Use 'Apply latest stash' to apply this stash to your working directory"
echo "  • Use 'Pop latest stash' to apply and remove this stash"
echo "  • Use 'Drop latest stash' to remove this stash without applying"
