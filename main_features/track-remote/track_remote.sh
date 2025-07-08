#!/bin/bash

# -----------------------------------------------------------------------------
# Script: track_remote.sh
#
# Description:
# This script lists all remote branches that are not yet tracked locally
# and allows the user to choose which ones to track by creating local
# branches with the same names.
#
# The script:
# 1. Fetches all remote branches to ensure up-to-date information
# 2. Identifies all remote branches
# 3. Compares with local branches to find untracked remote branches
# 4. Presents a list of untracked remote branches for selection
# 5. Creates local tracking branches for selected remote branches
# 6. Provides detailed feedback on the tracking process
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

echo "📡 Track Remote Branch Tool"
echo "==========================="
echo ""
echo "This tool will help you track remote branches locally by creating"
echo "local branches that track the selected remote branches."
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

echo ""

# --- Step 2: Get all remote branches ---
echo "📋 Step 2: Analyzing remote branches..."
echo ""

# Get all remote branches (excluding HEAD)
REMOTE_BRANCHES=$(git branch -r --format='%(refname:short)' | grep -v 'HEAD' | sed 's/^origin\///')

if [[ -z "$REMOTE_BRANCHES" ]]; then
    echo "❌ No remote branches found."
    echo "   Make sure you have a remote configured and remote branches exist."
    exit 1
fi

echo "Found remote branches:"
echo "$REMOTE_BRANCHES" | while IFS= read -r branch; do
    if [[ -n "$branch" ]]; then
        echo "   🌐 $branch"
    fi
done
echo ""

# --- Step 3: Get all local branches ---
echo "📋 Step 3: Analyzing local branches..."
echo ""

LOCAL_BRANCHES=$(git branch --format='%(refname:short)')

echo "Found local branches:"
echo "$LOCAL_BRANCHES" | while IFS= read -r branch; do
    if [[ -n "$branch" ]]; then
        echo "   📁 $branch"
    fi
done
echo ""

# --- Step 4: Find untracked remote branches ---
echo "🔍 Step 4: Finding untracked remote branches..."
echo ""

UNTRACKED_REMOTE_BRANCHES=()
TRACKED_BRANCHES=()

for remote_branch in $REMOTE_BRANCHES; do
    # Check if a local branch with the same name exists
    if echo "$LOCAL_BRANCHES" | grep -q "^$remote_branch$"; then
        TRACKED_BRANCHES+=("$remote_branch")
    else
        UNTRACKED_REMOTE_BRANCHES+=("$remote_branch")
    fi
done

# --- Step 5: Display results ---
if [[ ${#TRACKED_BRANCHES[@]} -gt 0 ]]; then
    echo "✅ Already tracked locally (${#TRACKED_BRANCHES[@]}):"
    for branch in "${TRACKED_BRANCHES[@]}"; do
        echo "   📁 $branch"
    done
    echo ""
fi

if [[ ${#UNTRACKED_REMOTE_BRANCHES[@]} -eq 0 ]]; then
    echo "🎉 All remote branches are already tracked locally!"
    exit 0
fi

echo "🌐 Untracked remote branches (${#UNTRACKED_REMOTE_BRANCHES[@]}):"
for i in "${!UNTRACKED_REMOTE_BRANCHES[@]}"; do
    echo "   $((i+1))) ${UNTRACKED_REMOTE_BRANCHES[$i]}"
done
echo ""

# --- Step 6: Offer to track branches ---
echo "🔄 You can track these remote branches locally."
echo ""

read -r -p "🤔 Do you want to track any of these branches? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled."
    exit 0
fi

echo ""

# --- Step 7: Select branches to track ---
TRACKED_BRANCHES_NEW=()
FAILED_TRACKS=()

echo "📋 Select branches to track (enter numbers or branch names separated by spaces, or 'all' for all):"
echo ""

read -r -p "Enter your selection: " selection

# Parse the selection
SELECTED_INDICES=()

if [[ "$selection" == "all" || "$selection" == "ALL" ]]; then
    # Select all branches
    for i in "${!UNTRACKED_REMOTE_BRANCHES[@]}"; do
        SELECTED_INDICES+=("$i")
    done
else
    # Parse individual selections (numbers or branch names)
    for item in $selection; do
        if [[ "$item" =~ ^[0-9]+$ ]]; then
            # Handle numeric selection
            index=$((item-1))
            if [[ $index -ge 0 && $index -lt ${#UNTRACKED_REMOTE_BRANCHES[@]} ]]; then
                SELECTED_INDICES+=("$index")
            else
                echo "⚠️  Invalid selection: $item (out of range)"
            fi
        else
            # Handle branch name selection
            found=false
            for i in "${!UNTRACKED_REMOTE_BRANCHES[@]}"; do
                if [[ "${UNTRACKED_REMOTE_BRANCHES[$i]}" == "$item" ]]; then
                    SELECTED_INDICES+=("$i")
                    found=true
                    break
                fi
            done
            if [[ "$found" == "false" ]]; then
                echo "⚠️  Invalid selection: $item (branch not found in untracked list)"
            fi
        fi
    done
fi

if [[ ${#SELECTED_INDICES[@]} -eq 0 ]]; then
    echo "❌ No valid branches selected."
    exit 0
fi

echo ""
echo "🔄 Selected branches to track:"
for index in "${SELECTED_INDICES[@]}"; do
    echo "   🌐 ${UNTRACKED_REMOTE_BRANCHES[$index]}"
done
echo ""

read -r -p "👉 Confirm tracking these branches? [y/N]: " confirm_track
if [[ ! "$confirm_track" =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled."
    exit 0
fi

echo ""

# --- Step 8: Track selected branches ---
echo "🔄 Step 5: Tracking selected branches..."
echo ""

for index in "${SELECTED_INDICES[@]}"; do
    remote_branch="${UNTRACKED_REMOTE_BRANCHES[$index]}"
    
    echo "📋 Processing: $remote_branch"
    
    # Create local branch tracking the remote branch
    if git checkout -b "$remote_branch" "origin/$remote_branch"; then
        echo "   ✅ Successfully created local branch '$remote_branch' tracking 'origin/$remote_branch'"
        TRACKED_BRANCHES_NEW+=("$remote_branch")
    else
        echo "   ❌ Failed to create local branch '$remote_branch'"
        FAILED_TRACKS+=("$remote_branch")
    fi
    
    echo ""
done

# --- Step 9: Switch back to original branch ---
if [[ "$CURRENT_BRANCH" != "$(git branch --show-current)" ]]; then
    echo "🔄 Switching back to original branch..."
    if git checkout "$CURRENT_BRANCH"; then
        echo "✅ Switched back to $CURRENT_BRANCH"
    else
        echo "⚠️  Warning: Failed to switch back to $CURRENT_BRANCH"
    fi
    echo ""
fi

# --- Step 10: Final summary ---
echo "🎉 Remote branch tracking completed!"
echo ""

if [[ ${#TRACKED_BRANCHES_NEW[@]} -gt 0 ]]; then
    echo "✅ Successfully tracked branches:"
    for branch in "${TRACKED_BRANCHES_NEW[@]}"; do
        echo "   📁 $branch"
    done
    echo ""
fi

if [[ ${#FAILED_TRACKS[@]} -gt 0 ]]; then
    echo "❌ Failed to track branches:"
    for branch in "${FAILED_TRACKS[@]}"; do
        echo "   ⚠️  $branch"
    done
    echo ""
fi

if [[ ${#TRACKED_BRANCHES_NEW[@]} -gt 0 ]]; then
    echo "💡 Tip: You can now switch to these branches using:"
    for branch in "${TRACKED_BRANCHES_NEW[@]}"; do
        echo "   git checkout $branch"
    done
    echo ""
fi

if [[ ${#UNTRACKED_REMOTE_BRANCHES[@]} -gt ${#SELECTED_INDICES[@]} ]]; then
    remaining=$(( ${#UNTRACKED_REMOTE_BRANCHES[@]} - ${#SELECTED_INDICES[@]} ))
    echo "💡 Tip: You still have $remaining untracked remote branch(es)."
    echo "   Run this tool again to track the remaining branches."
    echo ""
fi

echo "🔄 Your local repository now has access to the tracked remote branches!" 