#!/bin/bash

echo ""
echo "📦 Stash with Custom Message – Dev Tools"
echo "========================================"

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

# Check for untracked files
UNTRACKED_FILES=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED_FILES" ]; then
    echo "📄 Untracked files found:"
    echo "$UNTRACKED_FILES"
    echo ""
    
    read -p "📦 Include untracked files in stash? (yes/no): " include_untracked
    if [[ "$include_untracked" == "yes" ]]; then
        STASH_FLAGS="--include-untracked"
    else
        STASH_FLAGS=""
        echo "📄 Untracked files will NOT be stashed."
    fi
else
    STASH_FLAGS=""
fi

echo ""
read -p "💬 Enter a custom message for this stash: " custom_message

if [[ -z "$custom_message" ]]; then
    echo "❌ No message provided. Using default message."
    custom_message="Custom stash created on $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo ""
echo "📦 Stashing changes with message: '$custom_message'"

# Perform stash with custom message
if git stash push $STASH_FLAGS -m "$custom_message"; then
    echo "✅ Successfully stashed changes with custom message."
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
