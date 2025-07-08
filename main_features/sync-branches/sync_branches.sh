#!/bin/bash

# -----------------------------------------------------------------------------
# Script: sync_branches.sh
#
# Description:
# This script fully fetches all remote branches and offers to pull changes
# for each local branch. It provides a comprehensive way to keep your local
# repository in sync with the remote repository.
#
# The script:
# 1. Fetches all remote branches and updates remote tracking
# 2. Identifies all local branches
# 3. Shows the status of each local branch (ahead, behind, up-to-date)
# 4. Offers to pull changes for each branch individually
# 5. Provides detailed feedback on the sync process
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

# --- Check if there are any commits ---
if ! git rev-parse HEAD > /dev/null 2>&1; then
    echo "❌ No commits found in this repository. Please make at least one commit first."
    exit 1
fi

echo "🔄 Branch Sync Tool"
echo "=================="
echo ""
echo "This tool will fetch all remote branches and help you sync your local branches."
echo ""

# --- Get current branch ---
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"
echo ""

# --- Step 1: Fetch all remote branches ---
echo "📥 Step 1: Fetching all remote branches..."
echo ""

# Fetch all branches from all remotes
if git fetch --all --prune; then
    echo "✅ Successfully fetched all remote branches."
else
    echo "❌ Failed to fetch remote branches."
    exit 1
fi

# Update remote tracking branches
if git remote update --prune; then
    echo "✅ Successfully updated remote tracking branches."
else
    echo "⚠️  Warning: Failed to update some remote tracking branches."
fi

echo ""

# --- Step 2: Get all local branches ---
echo "📋 Step 2: Analyzing local branches..."
echo ""

LOCAL_BRANCHES=$(git branch --format='%(refname:short)')
BRANCH_COUNT=$(echo "$LOCAL_BRANCHES" | wc -l)

echo "Found $BRANCH_COUNT local branch(es):"
echo ""

# --- Step 3: Analyze each branch ---
BRANCHES_TO_SYNC=()
BRANCHES_UP_TO_DATE=()
BRANCHES_AHEAD=()
BRANCHES_BEHIND=()
BRANCHES_DIVERGED=()
BRANCHES_NO_REMOTE=()

for branch in $LOCAL_BRANCHES; do
    echo "🔍 Analyzing: $branch"
    
    # Check if branch has a remote tracking branch
    REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" 2>/dev/null || echo "")
    
    if [[ -z "$REMOTE_BRANCH" ]]; then
        echo "   ⚠️  No remote tracking branch found"
        BRANCHES_NO_REMOTE+=("$branch")
        echo ""
        continue
    fi
    
    # Get the status of the branch relative to its remote
    LOCAL_COMMIT=$(git rev-parse "$branch")
    REMOTE_COMMIT=$(git rev-parse "$REMOTE_BRANCH")
    
    if [[ "$LOCAL_COMMIT" == "$REMOTE_COMMIT" ]]; then
        echo "   ✅ Up to date"
        BRANCHES_UP_TO_DATE+=("$branch")
    else
        # Check if ahead, behind, or diverged
        LOCAL_AHEAD=$(git rev-list --count "$REMOTE_BRANCH..$branch" 2>/dev/null || echo "0")
        REMOTE_AHEAD=$(git rev-list --count "$branch..$REMOTE_BRANCH" 2>/dev/null || echo "0")
        
        if [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -eq 0 ]]; then
            echo "   🟡 Ahead by $LOCAL_AHEAD commit(s)"
            BRANCHES_AHEAD+=("$branch")
        elif [[ "$LOCAL_AHEAD" -eq 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
            echo "   🔴 Behind by $REMOTE_AHEAD commit(s)"
            BRANCHES_BEHIND+=("$branch")
            BRANCHES_TO_SYNC+=("$branch")
        elif [[ "$LOCAL_AHEAD" -gt 0 && "$REMOTE_AHEAD" -gt 0 ]]; then
            echo "   🟠 Diverged (local: +$LOCAL_AHEAD, remote: +$REMOTE_AHEAD)"
            BRANCHES_DIVERGED+=("$branch")
            BRANCHES_TO_SYNC+=("$branch")
        else
            echo "   ✅ Up to date"
            BRANCHES_UP_TO_DATE+=("$branch")
        fi
    fi
    
    echo ""
done

# --- Step 4: Display summary ---
echo "📊 Branch Status Summary:"
echo ""

if [[ ${#BRANCHES_UP_TO_DATE[@]} -gt 0 ]]; then
    echo "✅ Up to date (${#BRANCHES_UP_TO_DATE[@]}):"
    for branch in "${BRANCHES_UP_TO_DATE[@]}"; do
        echo "   $branch"
    done
    echo ""
fi

if [[ ${#BRANCHES_AHEAD[@]} -gt 0 ]]; then
    echo "🟡 Ahead of remote (${#BRANCHES_AHEAD[@]}):"
    for branch in "${BRANCHES_AHEAD[@]}"; do
        echo "   $branch"
    done
    echo ""
fi

if [[ ${#BRANCHES_BEHIND[@]} -gt 0 ]]; then
    echo "🔴 Behind remote (${#BRANCHES_BEHIND[@]}):"
    for branch in "${BRANCHES_BEHIND[@]}"; do
        echo "   $branch"
    done
    echo ""
fi

if [[ ${#BRANCHES_DIVERGED[@]} -gt 0 ]]; then
    echo "🟠 Diverged from remote (${#BRANCHES_DIVERGED[@]}):"
    for branch in "${BRANCHES_DIVERGED[@]}"; do
        echo "   $branch"
    done
    echo ""
fi

if [[ ${#BRANCHES_NO_REMOTE[@]} -gt 0 ]]; then
    echo "⚠️  No remote tracking (${#BRANCHES_NO_REMOTE[@]}):"
    for branch in "${BRANCHES_NO_REMOTE[@]}"; do
        echo "   $branch"
    done
    echo ""
fi

# --- Step 5: Offer to sync branches ---
if [[ ${#BRANCHES_TO_SYNC[@]} -eq 0 ]]; then
    echo "🎉 All branches are up to date!"
    exit 0
fi

echo "🔄 Branches that can be synced: ${#BRANCHES_TO_SYNC[@]}"
echo ""

read -r -p "🤔 Do you want to sync these branches? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Sync cancelled."
    exit 0
fi

echo ""

# --- Step 6: Sync each branch ---
SYNCED_BRANCHES=()
FAILED_SYNCS=()

for branch in "${BRANCHES_TO_SYNC[@]}"; do
    echo "📋 Processing: $branch"
    
    # Check if this is the current branch
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        echo "   📍 This is your current branch"
        read -r -p "   🔄 Pull changes for current branch '$branch'? [y/N]: " confirm_pull
    else
        read -r -p "   🔄 Pull changes for branch '$branch'? [y/N]: " confirm_pull
    fi
    
    if [[ "$confirm_pull" =~ ^[Yy]$ ]]; then
        echo "   🔄 Pulling changes..."
        
        # Switch to the branch if it's not the current one
        if [[ "$branch" != "$CURRENT_BRANCH" ]]; then
            if git checkout "$branch"; then
                echo "   ✅ Switched to $branch"
            else
                echo "   ❌ Failed to switch to $branch"
                FAILED_SYNCS+=("$branch (switch failed)")
                echo ""
                continue
            fi
        fi
        
        # Pull the changes
        if git pull; then
            echo "   ✅ Successfully pulled changes for $branch"
            SYNCED_BRANCHES+=("$branch")
        else
            echo "   ❌ Failed to pull changes for $branch"
            FAILED_SYNCS+=("$branch (pull failed)")
        fi
        
        # Switch back to original branch if needed
        if [[ "$branch" != "$CURRENT_BRANCH" ]]; then
            if git checkout "$CURRENT_BRANCH"; then
                echo "   ✅ Switched back to $CURRENT_BRANCH"
            else
                echo "   ⚠️  Warning: Failed to switch back to $CURRENT_BRANCH"
            fi
        fi
    else
        echo "   ⏭️  Skipped $branch"
    fi
    
    echo ""
done

# --- Step 7: Final summary ---
echo "🎉 Branch sync completed!"
echo ""

if [[ ${#SYNCED_BRANCHES[@]} -gt 0 ]]; then
    echo "✅ Successfully synced branches:"
    for branch in "${SYNCED_BRANCHES[@]}"; do
        echo "   🔄 $branch"
    done
    echo ""
fi

if [[ ${#FAILED_SYNCS[@]} -gt 0 ]]; then
    echo "❌ Failed syncs:"
    for failure in "${FAILED_SYNCS[@]}"; do
        echo "   ⚠️  $failure"
    done
    echo ""
fi

if [[ ${#BRANCHES_AHEAD[@]} -gt 0 ]]; then
    echo "💡 Tip: You have ${#BRANCHES_AHEAD[@]} branch(es) ahead of remote."
    echo "   Consider pushing these changes when ready."
    echo ""
fi

if [[ ${#BRANCHES_NO_REMOTE[@]} -gt 0 ]]; then
    echo "💡 Tip: You have ${#BRANCHES_NO_REMOTE[@]} branch(es) without remote tracking."
    echo "   Consider setting up remote tracking with: git branch --set-upstream-to=origin/<branch> <branch>"
    echo ""
fi

echo "🔄 Your repository is now up to date!" 