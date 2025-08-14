#!/bin/bash

echo ""
echo "🔄 Apply Specific Stash – Dev Tools"
echo "==================================="

# Check if there are any stashes
STASH_COUNT=$(git stash list | wc -l | tr -d ' ')
if [[ $STASH_COUNT -eq 0 ]]; then
    echo "📦 No stashes found to apply."
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

read -p "🔍 Enter stash index or reference to apply: " stash_input

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

# Show the selected stash
echo ""
echo "📦 Selected stash to apply:"
SELECTED_STASH=$(git stash list | grep "^$stash_ref:")
echo "  $SELECTED_STASH"
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
read -p "🔄 Apply stash $stash_ref? (This keeps the stash in the stash list) (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "❌ Apply operation cancelled."
    exit 1
fi

# Apply the specified stash
echo ""
echo "🔄 Applying stash $stash_ref..."
if git stash apply "$stash_ref"; then
    echo "✅ Successfully applied stash $stash_ref."
    echo ""
    echo "📦 Stash remains in the stash list:"
    echo "  $SELECTED_STASH"
    echo ""
    echo "💡 Tip: Use 'Drop specific stash' to remove the stash if no longer needed."
else
    echo "❌ Failed to apply stash. There may be conflicts."
    echo ""
    echo "💡 Tips for resolving conflicts:"
    echo "  • Check 'git status' for conflicted files"
    echo "  • Resolve conflicts manually and commit"
    echo "  • Use 'git stash drop $stash_ref' to remove the stash if no longer needed"
    exit 1
fi
