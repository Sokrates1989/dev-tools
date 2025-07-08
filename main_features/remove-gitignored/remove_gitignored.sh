#!/bin/bash

# -----------------------------------------------------------------------------
# Script: remove_gitignored.sh
#
# Description:
# This script removes files from Git's index (cache) that are now covered by
# .gitignore rules. This is useful for cleaning up accidentally tracked files
# that should be ignored.
#
# The script performs the following operations:
# 1. Removes all files from Git's index: git rm -r --cached .
# 2. Re-adds files respecting .gitignore: git add .
# 3. Creates a commit with the changes
#
# This effectively removes any files that are now ignored by .gitignore
# from being tracked by Git, while keeping them in the working directory.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load environment variables.
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

# --- Check if we're in a git repository ---
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository. Please navigate to a git repository and try again."
    exit 1
fi

# --- Check if .gitignore exists ---
if [[ ! -f ".gitignore" ]]; then
    echo "⚠️  No .gitignore file found in the current directory."
    echo "   This operation is most effective when you have a .gitignore file."
    echo ""
    read -r -p "🤔 Do you want to continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Operation cancelled."
        exit 0
    fi
    echo ""
fi

echo "🧹 Remove Gitignored Files Tool"
echo "==============================="
echo ""
echo "This will remove files from Git's index that are now covered by .gitignore."
echo ""
echo "📋 What this does:"
echo "   1. Removes all files from Git's index (git rm -r --cached .)"
echo "   2. Re-adds files respecting .gitignore rules (git add .)"
echo "   3. Creates a commit with the changes"
echo ""
echo "⚠️  Important notes:"
echo "   - Files will remain in your working directory"
echo "   - Only files that are now ignored will be removed from tracking"
echo "   - This will create a new commit"
echo ""

# --- Show current status ---
echo "📊 Current Git status:"
git status --porcelain | head -10
if [[ $(git status --porcelain | wc -l) -gt 10 ]]; then
    echo "   ... and $(($(git status --porcelain | wc -l) - 10)) more files"
fi
echo ""

# --- Check for uncommitted changes ---
if [[ -n "$(git status --porcelain)" ]]; then
    echo "⚠️  You have uncommitted changes in your working directory."
    echo "   It's recommended to commit or stash these changes first."
    echo ""
    read -r -p "🤔 Do you want to continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Operation cancelled."
        exit 0
    fi
    echo ""
fi

# --- Show what will be removed ---
echo "🔍 Analyzing what will be removed..."
echo ""

# Get list of currently tracked files that would be ignored
TRACKED_IGNORED_FILES=$(git ls-files | git check-ignore --stdin 2>/dev/null || true)

if [[ -n "$TRACKED_IGNORED_FILES" ]]; then
    echo "📋 Files that will be removed from tracking:"
    echo "$TRACKED_IGNORED_FILES" | head -10
    if [[ $(echo "$TRACKED_IGNORED_FILES" | wc -l) -gt 10 ]]; then
        echo "   ... and $(($(echo "$TRACKED_IGNORED_FILES" | wc -l) - 10)) more files"
    fi
    echo ""
else
    echo "✅ No tracked files are currently ignored by .gitignore."
    echo "   This operation won't make any changes."
    echo ""
    read -r -p "🤔 Do you want to continue anyway? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "❌ Operation cancelled."
        exit 0
    fi
    echo ""
fi

# --- Confirmation ---
read -r -p "🚀 Do you want to proceed with removing ignored files? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled."
    exit 0
fi

echo ""
echo "🔄 Starting removal process..."

# --- Step 1: Remove all files from index ---
echo "📤 Step 1: Removing all files from Git's index..."
if git rm -r --cached .; then
    echo "✅ Successfully removed all files from index."
else
    echo "❌ Failed to remove files from index."
    exit 1
fi

# --- Step 2: Re-add files respecting .gitignore ---
echo "📥 Step 2: Re-adding files respecting .gitignore..."
if git add .; then
    echo "✅ Successfully re-added files respecting .gitignore."
else
    echo "❌ Failed to re-add files."
    exit 1
fi

# --- Check what changed ---
echo ""
echo "📊 Changes made:"
git status --porcelain
echo ""

# --- Step 3: Commit changes ---
if [[ -n "$(git status --porcelain)" ]]; then
    echo "💾 Step 3: Creating commit..."
    
    # Generate commit message
    REMOVED_COUNT=$(git status --porcelain | grep "^D" | wc -l)
    ADDED_COUNT=$(git status --porcelain | grep "^A" | wc -l)
    MODIFIED_COUNT=$(git status --porcelain | grep "^M" | wc -l)
    
    COMMIT_MSG="Remove ignored files from Git tracking"
    if [[ $REMOVED_COUNT -gt 0 ]]; then
        COMMIT_MSG="$COMMIT_MSG (removed $REMOVED_COUNT files)"
    fi
    if [[ $ADDED_COUNT -gt 0 ]]; then
        COMMIT_MSG="$COMMIT_MSG, re-added $ADDED_COUNT files"
    fi
    if [[ $MODIFIED_COUNT -gt 0 ]]; then
        COMMIT_MSG="$COMMIT_MSG, modified $MODIFIED_COUNT files"
    fi
    
    echo "📝 Commit message: $COMMIT_MSG"
    echo ""
    
    read -r -p "👉 Do you want to commit these changes? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        if git commit -m "$COMMIT_MSG"; then
            echo "✅ Successfully committed changes."
            echo ""
            echo "🎉 Operation completed successfully!"
            echo "📋 Summary:"
            echo "   - Removed ignored files from Git tracking"
            echo "   - Files remain in your working directory"
            echo "   - Changes committed to repository"
        else
            echo "❌ Failed to commit changes."
            exit 1
        fi
    else
        echo "ℹ️  Changes staged but not committed."
        echo "   You can review the changes with 'git status' and commit manually."
    fi
else
    echo "✅ No changes to commit - all files are already properly ignored."
fi

echo ""
echo "💡 Tip: You can now push these changes to share the cleanup with your team." 