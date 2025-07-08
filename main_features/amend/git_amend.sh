#!/bin/bash

# -----------------------------------------------------------------------------
# Script: git_amend.sh
#
# Description:
# This script allows users to amend the last commit with two options:
# 1. Amend without changing the commit message (git commit --amend --no-edit)
# 2. Amend with a new commit message by regenerating it using the existing
#    commit functionality after temporarily removing the last commit
#
# The script checks if the commit has been pushed to remote and warns the user
# if it has been pushed.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMMIT_SCRIPT_DIR="$SCRIPT_DIR/../commit"

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

# --- Check if there are any commits ---
if ! git rev-parse HEAD > /dev/null 2>&1; then
    echo "❌ No commits found in this repository. Please make at least one commit first."
    exit 1
fi

# --- Get the last commit hash and check if it's been pushed ---
LAST_COMMIT_HASH=$(git rev-parse HEAD)
LAST_COMMIT_MSG=$(git log -1 --pretty=format:"%s")
BRANCH_NAME=$(git branch --show-current)

echo "🔄 Git Amend Tool"
echo "================="
echo ""
echo "📝 Last commit: $LAST_COMMIT_HASH"
echo "📄 Message: $LAST_COMMIT_MSG"
echo "🌿 Branch: $BRANCH_NAME"
echo ""

# --- Check if the commit has been pushed ---
if git branch -r | grep -q "origin/$BRANCH_NAME"; then
    # Remote branch exists, check if local is ahead
    LOCAL_COMMITS=$(git rev-list HEAD --not origin/$BRANCH_NAME --count)
    if [[ "$LOCAL_COMMITS" -eq 0 ]]; then
        echo "❌ Cannot amend: This commit has already been pushed to the remote repository."
        echo ""
        echo "🔄 Instead of amending, you should create a new commit:"
        echo "   1. Stage any additional changes: git add ."
        echo "   2. Create a new commit with the existing commit functionality"
        echo "   3. Push the new commit to remote"
        echo ""
        echo "💡 This approach is safer and won't rewrite history."
        echo ""
        read -r -p "🚀 Would you like to create a new commit instead? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo ""
            echo "🚀 Redirecting to commit functionality..."
            echo ""
            bash "$COMMIT_SCRIPT_DIR/git_export_staged.sh"
        else
            echo "❌ Operation cancelled."
        fi
        exit 0
    fi
fi

# --- Show amend options ---
echo "Choose an amend option:"
echo ""
echo "1) 🔄 Amend without changing commit message"
echo "2) ✏️  Amend with new commit message (regenerate)"
echo "3) ❌ Cancel"
echo ""

read -r -p "Enter your choice [1-3]: " choice

case "$choice" in
    1)
        echo ""
        echo "🔄 Amending commit without changing message..."
        echo "Command: git commit --amend --no-edit"
        echo ""
        read -r -p "👉 Do you want to proceed? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            git commit --amend --no-edit
            if [[ $? -eq 0 ]]; then
                echo "✅ Commit amended successfully!"
                echo ""
                echo "📝 New commit hash: $(git rev-parse HEAD)"
                echo "📄 Message: $(git log -1 --pretty=format:"%s")"
            else
                echo "❌ Failed to amend commit."
                exit 1
            fi
        else
            echo "❌ Amend cancelled."
        fi
        ;;
    2)
        echo ""
        echo "✏️  Amending with new commit message..."
        echo ""
        echo "This will:"
        echo "1. Temporarily remove the last commit (keeping changes staged)"
        echo "2. Use the existing commit functionality to generate a new message"
        echo "3. Create a new commit with the new message"
        echo ""
        read -r -p "👉 Do you want to proceed? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo ""
            echo "🔄 Temporarily removing last commit..."
            
            # Store the current staged changes
            git reset --soft HEAD~1
            
            if [[ $? -eq 0 ]]; then
                echo "✅ Last commit removed. Changes are now staged."
                echo ""
                echo "🚀 Now using the commit functionality to generate a new message..."
                echo ""
                
                # Call the existing commit functionality
                bash "$COMMIT_SCRIPT_DIR/git_export_staged.sh"
            else
                echo "❌ Failed to remove last commit."
                exit 1
            fi
        else
            echo "❌ Amend cancelled."
        fi
        ;;
    3)
        echo "❌ Amend cancelled."
        ;;
    *)
        echo "❌ Invalid choice. Please select 1, 2, or 3."
        exit 1
        ;;
esac 