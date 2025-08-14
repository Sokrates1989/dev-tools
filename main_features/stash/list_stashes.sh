#!/bin/bash

echo ""
echo "📜 List All Stashes – Dev Tools"
echo "==============================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found."
    echo ""
    echo "💡 Tip: Create a stash using one of the stash operations."
    exit 0
fi

echo ""
echo "📦 Found $STASH_COUNT stash(es):"
echo ""

# List all stashes with enhanced formatting
git stash list --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %C(blue)%s%C(reset)" | while IFS= read -r line; do
    echo "  $line"
done

echo ""
echo "💡 Tips:"
echo "  • Use 'Show content of specific stash' to view stash details"
echo "  • Use 'Apply specific stash' to apply a stash by its index (e.g., stash@{0})"
echo "  • Use 'Drop specific stash' to remove a stash by its index"
