#!/bin/bash

# -----------------------------------------------------------------------------
# Script: sync_check.sh
#
# Description:
# This utility script checks if the current branch is in sync with its remote
# counterpart before allowing operations like commits or merges. It helps prevent
# merge conflicts by ensuring the local branch is up-to-date.
#
# The script:
# 1. Checks if the current branch has a remote tracking branch
# 2. Fetches the latest remote information
# 3. Compares local and remote branch status
# 4. Provides options to sync if out of sync
# 5. Returns appropriate exit codes for integration with other tools
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment variables.
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

# --- Check if we're in a git repository ---
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository. Please navigate to a git repository and try again."
    exit 1
fi

BRANCH_TO_CHECK="${1:-}"
if [[ -n "$BRANCH_TO_CHECK" ]]; then
    ORIGINAL_BRANCH=$(git branch --show-current)
    if [[ -z "$ORIGINAL_BRANCH" ]]; then
        echo "❌ Could not detect current Git branch."
        exit 1
    fi

    if [[ "$BRANCH_TO_CHECK" != "$ORIGINAL_BRANCH" ]]; then
        if ! git diff --quiet || ! git diff --cached --quiet; then
            echo "❌ You have uncommitted changes. Please commit or stash them before checking another branch."
            exit 1
        fi

        echo "🔄 Switching to branch '$BRANCH_TO_CHECK' for sync check..."
        if ! git checkout "$BRANCH_TO_CHECK" > /dev/null 2>&1; then
            echo "❌ Failed to checkout branch '$BRANCH_TO_CHECK'."
            exit 1
        fi

        bash "$SCRIPT_PATH"
        RESULT=$?

        echo "🔄 Switching back to original branch '$ORIGINAL_BRANCH'..."
        if ! git checkout "$ORIGINAL_BRANCH" > /dev/null 2>&1; then
            echo "❌ Failed to switch back to original branch '$ORIGINAL_BRANCH'."
            exit 1
        fi

        exit $RESULT
    fi
fi

# --- Get current branch ---
CURRENT_BRANCH=$(git branch --show-current)
if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "❌ Could not detect current Git branch."
    exit 1
fi

# --- Check if current branch has a remote tracking branch ---
if ! git rev-parse --verify "origin/$CURRENT_BRANCH" > /dev/null 2>&1; then
    echo "⚠️  Current branch '$CURRENT_BRANCH' has no remote tracking branch."
    echo "   This is normal for new branches that haven't been pushed yet."
    echo "   Proceeding with operation..."
    exit 0
fi

# --- Fetch latest remote information ---
echo "📥 Fetching latest remote information..."
if ! git fetch origin "$CURRENT_BRANCH" > /dev/null 2>&1; then
    echo "❌ Failed to fetch remote information for branch '$CURRENT_BRANCH'."
    echo "   Please check your network connection and remote configuration."
    exit 1
fi

# --- Check branch status ---
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse "origin/$CURRENT_BRANCH")

if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
    echo "✅ Branch '$CURRENT_BRANCH' is up-to-date with remote."
    exit 0
fi

# --- Check if local is ahead, behind, or diverged ---
LOCAL_AHEAD=$(git rev-list --count "origin/$CURRENT_BRANCH"..HEAD 2>/dev/null || echo "0")
REMOTE_AHEAD=$(git rev-list --count HEAD.."origin/$CURRENT_BRANCH" 2>/dev/null || echo "0")

echo ""
echo "⚠️  Branch '$CURRENT_BRANCH' is not in sync with remote:"

if [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -eq 0 ]]; then
    echo "   📤 Local is $LOCAL_AHEAD commit(s) ahead of remote"
    echo "   💡 You can push your changes: git push"
elif [[ "$LOCAL_AHEAD" -eq 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
    echo "   📥 Local is $REMOTE_AHEAD commit(s) behind remote"
    echo "   💡 You should pull remote changes: git pull"
elif [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
    echo "   🔀 Local and remote have diverged"
    echo "   📤 Local is $LOCAL_AHEAD commit(s) ahead"
    echo "   📥 Remote is $REMOTE_AHEAD commit(s) ahead"
    echo "   💡 You need to merge or rebase: git pull --rebase"
fi

echo ""

# --- Show recent commits for context ---
if [[ "$REMOTE_AHEAD" -gt 0 ]]; then
    echo "📋 Recent remote commits you don't have:"
    git log --oneline HEAD.."origin/$CURRENT_BRANCH" | head -5
    if [[ "$REMOTE_AHEAD" -gt 5 ]]; then
        echo "   ... and $((REMOTE_AHEAD - 5)) more commits"
    fi
    echo ""
fi

if [[ "$LOCAL_AHEAD" -gt 0 ]]; then
    echo "📋 Your recent commits not on remote:"
    git log --oneline "origin/$CURRENT_BRANCH"..HEAD | head -5
    if [[ "$LOCAL_AHEAD" -gt 5 ]]; then
        echo "   ... and $((LOCAL_AHEAD - 5)) more commits"
    fi
    echo ""
fi

# --- Offer sync options ---
echo "🔄 Sync options:"
echo ""

if [[ "$REMOTE_AHEAD" -gt 0 ]]; then
    echo "1) 📥 Pull remote changes (git pull)"
    echo "2) 📥 Pull with rebase (git pull --rebase)"
fi

if [[ "$LOCAL_AHEAD" -gt 0 ]]; then
    echo "3) 📤 Push local changes (git push)"
fi

if [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
    echo "4) 🔄 Force push (git push --force-with-lease) - USE WITH CAUTION"
fi

echo "5) ❌ Skip sync and continue anyway"
echo "6) ❌ Cancel operation"

echo ""
read -r -p "🤔 Choose an option [1-6]: " choice

case "$choice" in
    1)
        if [[ "$REMOTE_AHEAD" -gt 0 ]]; then
            echo "📥 Pulling remote changes..."
            if git pull origin "$CURRENT_BRANCH"; then
                echo "✅ Successfully pulled remote changes."
                exit 0
            else
                echo "❌ Failed to pull remote changes."
                echo "   You may need to resolve conflicts manually."
                exit 1
            fi
        else
            echo "❌ Invalid option for current branch status."
            exit 1
        fi
        ;;
    2)
        if [[ "$REMOTE_AHEAD" -gt 0 ]]; then
            echo "📥 Pulling remote changes with rebase..."
            if git pull --rebase origin "$CURRENT_BRANCH"; then
                echo "✅ Successfully pulled remote changes with rebase."
                exit 0
            else
                echo "❌ Failed to pull remote changes with rebase."
                echo "   You may need to resolve conflicts manually."
                exit 1
            fi
        else
            echo "❌ Invalid option for current branch status."
            exit 1
        fi
        ;;
    3)
        if [[ "$LOCAL_AHEAD" -gt 0 ]]; then
            echo "📤 Pushing local changes..."
            if git push origin "$CURRENT_BRANCH"; then
                echo "✅ Successfully pushed local changes."
                exit 0
            else
                echo "❌ Failed to push local changes."
                exit 1
            fi
        else
            echo "❌ Invalid option for current branch status."
            exit 1
        fi
        ;;
    4)
        if [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
            echo "⚠️  WARNING: Force push will overwrite remote changes!"
            echo "   This can cause data loss if others have pushed changes."
            read -r -p "🤔 Are you absolutely sure? Type 'yes' to confirm: " confirm
            if [[ "$confirm" == "yes" ]]; then
                echo "🔄 Force pushing local changes..."
                if git push --force-with-lease origin "$CURRENT_BRANCH"; then
                    echo "✅ Successfully force pushed local changes."
                    exit 0
                else
                    echo "❌ Failed to force push local changes."
                    exit 1
                fi
            else
                echo "❌ Force push cancelled."
                exit 1
            fi
        else
            echo "❌ Invalid option for current branch status."
            exit 1
        fi
        ;;
    5)
        echo "⚠️  Proceeding without syncing. This may cause merge conflicts later."
        exit 0
        ;;
    6)
        echo "❌ Operation cancelled."
        exit 1
        ;;
    *)
        echo "❌ Invalid choice. Please select a valid option."
        exit 1
        ;;
esac 