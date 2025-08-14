#!/bin/bash

echo ""
echo "🔍 Show Specific Stash Content – Dev Tools"
echo "=========================================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to show."
    echo ""
    echo "💡 Tip: Create a stash first using one of the stash operations."
    exit 0
fi

# Show all available stashes
echo ""
echo "📦 Available stashes:"
echo ""
git stash list --format="%C(yellow)%gd%C(reset) %C(green)(%cr)%C(reset) %C(blue)%s%C(reset)" | nl -w3 -s') '

echo ""
echo "💡 You can specify stash by:"
echo "  • Index number (e.g., 1, 2, 3)"
echo "  • Stash reference (e.g., stash@{0}, stash@{1})"
echo ""

read -p "🔍 Enter stash index or reference to show: " stash_input

# Validate and convert input
if [[ "$stash_input" =~ ^[0-9]+$ ]]; then
    # User entered a number, convert to stash reference
    stash_index=$((stash_input - 1))
    if [[ $stash_index -lt 0 || $stash_index -ge $STASH_COUNT ]]; then
        echo "❌ Invalid stash index. Please enter a number between 1 and $STASH_COUNT."
        exit 1
    fi
    stash_ref="stash@{$stash_index}"
elif [[ "$stash_input" =~ ^stash@\{[0-9]+\}$ ]]; then
    # User entered a stash reference
    stash_ref="$stash_input"
    # Extract index to validate
    stash_index=$(echo "$stash_input" | sed 's/stash@{\([0-9]*\)}/\1/')
    if [[ $stash_index -ge $STASH_COUNT ]]; then
        echo "❌ Invalid stash reference. Stash $stash_input does not exist."
        exit 1
    fi
else
    echo "❌ Invalid input. Please enter a number or stash reference like 'stash@{0}'."
    exit 1
fi

# Show the selected stash info
echo ""
echo "📦 Selected stash:"
SELECTED_STASH=$(git stash list | grep "^$stash_ref:")
echo "  $SELECTED_STASH"
echo ""

echo "📋 Stash content:"
echo "=================="
echo ""

# Show the stash content with diff
git stash show -p "$stash_ref"

echo ""
echo "💡 Tips:"
echo "  • Use 'Apply specific stash' to apply this stash to your working directory"
echo "  • Use 'Pop specific stash' to apply and remove this stash"
echo "  • Use 'Drop specific stash' to remove this stash without applying"
