#!/bin/bash

# -----------------------------------------------------------------------------
# Script: branch_cleanup.sh
#
# Description:
# This script identifies local branches (other than main and dev) that are
# fully merged with either main or dev, and offers to remove them both
# locally and remotely with user confirmation for each branch.
#
# The script:
# 1. Checks if we're in a git repository
# 2. Identifies local branches other than main and dev
# 3. Checks which branches are fully merged with main or dev
# 4. Asks for confirmation to remove each branch locally and remotely
# 5. Performs the removal with detailed feedback
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

echo "🧹 Branch Cleanup Tool"
echo "====================="
echo ""
echo "This tool will identify and remove local branches that are fully merged"
echo "with either main or dev branches (excluding main and dev themselves)."
echo ""

# --- Get current branch ---
CURRENT_BRANCH=$(git branch --show-current)
echo "📍 Current branch: $CURRENT_BRANCH"
echo ""

# --- Check if main and dev branches exist ---
MAIN_EXISTS=false
DEV_EXISTS=false

if git show-ref --verify --quiet refs/heads/main; then
    MAIN_EXISTS=true
fi

if git show-ref --verify --quiet refs/heads/dev; then
    DEV_EXISTS=true
fi

if [[ "$MAIN_EXISTS" == "false" && "$DEV_EXISTS" == "false" ]]; then
    echo "❌ Neither 'main' nor 'dev' branches exist in this repository."
    echo "   This tool requires at least one of these branches to exist."
    exit 1
fi

echo "📋 Available merge targets:"
if [[ "$MAIN_EXISTS" == "true" ]]; then
    echo "   ✅ main"
fi
if [[ "$DEV_EXISTS" == "true" ]]; then
    echo "   ✅ dev"
fi
echo ""

# --- Get all local branches ---
LOCAL_BRANCHES=$(git branch --format='%(refname:short)')

# --- Filter out main and dev branches ---
CANDIDATE_BRANCHES=()
while IFS= read -r branch; do
    if [[ "$branch" != "main" && "$branch" != "dev" ]]; then
        CANDIDATE_BRANCHES+=("$branch")
    fi
done <<< "$LOCAL_BRANCHES"

if [[ ${#CANDIDATE_BRANCHES[@]} -eq 0 ]]; then
    echo "✅ No branches to check (only main and dev exist)."
    exit 0
fi

echo "🔍 Checking ${#CANDIDATE_BRANCHES[@]} local branches for merge status..."
echo ""

# --- Check merge status for each branch ---
MERGED_BRANCHES=()
UNMERGED_BRANCHES=()

for branch in "${CANDIDATE_BRANCHES[@]}"; do
    IS_MERGED=false
    MERGED_INTO=""
    
    # Check if merged into main
    if [[ "$MAIN_EXISTS" == "true" ]]; then
        if git branch --merged main | grep -q "^[[:space:]]*$branch$"; then
            IS_MERGED=true
            MERGED_INTO="main"
        fi
    fi
    
    # Check if merged into dev (if not already found merged into main)
    if [[ "$IS_MERGED" == "false" && "$DEV_EXISTS" == "true" ]]; then
        if git branch --merged dev | grep -q "^[[:space:]]*$branch$"; then
            IS_MERGED=true
            MERGED_INTO="dev"
        fi
    fi
    
    if [[ "$IS_MERGED" == "true" ]]; then
        MERGED_BRANCHES+=("$branch|$MERGED_INTO")
    else
        UNMERGED_BRANCHES+=("$branch")
    fi
done

# --- Display results ---
if [[ ${#MERGED_BRANCHES[@]} -eq 0 ]]; then
    echo "✅ No fully merged branches found."
    echo ""
    if [[ ${#UNMERGED_BRANCHES[@]} -gt 0 ]]; then
        echo "📋 Unmerged branches:"
        for branch in "${UNMERGED_BRANCHES[@]}"; do
            echo "   ⚠️  $branch"
        done
        echo ""
        echo "💡 These branches still have unmerged changes."
    fi
    exit 0
fi

echo "✅ Found ${#MERGED_BRANCHES[@]} fully merged branch(es):"
for branch_info in "${MERGED_BRANCHES[@]}"; do
    IFS='|' read -r branch merged_into <<< "$branch_info"
    echo "   🟢 $branch (merged into $merged_into)"
done
echo ""

if [[ ${#UNMERGED_BRANCHES[@]} -gt 0 ]]; then
    echo "⚠️  Unmerged branches (will be preserved):"
    for branch in "${UNMERGED_BRANCHES[@]}"; do
        echo "   🔴 $branch"
    done
    echo ""
fi

# --- Check if current branch is in the merged list ---
CURRENT_BRANCH_MERGED=false
for branch_info in "${MERGED_BRANCHES[@]}"; do
    IFS='|' read -r branch merged_into <<< "$branch_info"
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        CURRENT_BRANCH_MERGED=true
        break
    fi
done

if [[ "$CURRENT_BRANCH_MERGED" == "true" ]]; then
    echo "⚠️  WARNING: You are currently on a merged branch ($CURRENT_BRANCH)."
    echo "   You should switch to main or dev before removing branches."
    echo ""
    read -r -p "🤔 Do you want to switch to main first? [Y/n]: " confirm
    if [[ "$confirm" != "n" && "$confirm" != "N" ]]; then
        if [[ "$MAIN_EXISTS" == "true" ]]; then
            echo "🔄 Switching to main branch..."
            git checkout main
            if [[ $? -ne 0 ]]; then
                echo "❌ Failed to switch to main branch."
                exit 1
            fi
            echo "✅ Switched to main branch."
        elif [[ "$DEV_EXISTS" == "true" ]]; then
            echo "🔄 Switching to dev branch..."
            git checkout dev
            if [[ $? -ne 0 ]]; then
                echo "❌ Failed to switch to dev branch."
                exit 1
            fi
            echo "✅ Switched to dev branch."
        fi
        echo ""
    else
        echo "❌ Operation cancelled. Please switch branches manually and try again."
        exit 0
    fi
fi

# --- Process each merged branch ---
echo "🗑️  Ready to remove merged branches..."
echo ""

REMOVED_LOCAL=()
REMOVED_REMOTE=()
FAILED_REMOVALS=()

for branch_info in "${MERGED_BRANCHES[@]}"; do
    IFS='|' read -r branch merged_into <<< "$branch_info"
    
    echo "📋 Processing: $branch (merged into $merged_into)"
    echo ""
    
    # Check if branch exists remotely
    REMOTE_EXISTS=false
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        REMOTE_EXISTS=true
    fi
    
    # Ask for local removal
    read -r -p "🗑️  Remove '$branch' locally? [y/N]: " confirm_local
    if [[ "$confirm_local" =~ ^[Yy]$ ]]; then
        echo "🔄 Removing local branch '$branch'..."
        if git branch -d "$branch"; then
            echo "✅ Successfully removed local branch '$branch'."
            REMOVED_LOCAL+=("$branch")
        else
            echo "❌ Failed to remove local branch '$branch'."
            FAILED_REMOVALS+=("local:$branch")
        fi
    else
        echo "⏭️  Skipped local removal of '$branch'."
    fi
    
    # Ask for remote removal (if branch exists remotely)
    if [[ "$REMOTE_EXISTS" == "true" ]]; then
        read -r -p "🌐 Remove '$branch' from remote (origin)? [y/N]: " confirm_remote
        if [[ "$confirm_remote" =~ ^[Yy]$ ]]; then
            echo "🔄 Removing remote branch '$branch'..."
            if git push origin --delete "$branch"; then
                echo "✅ Successfully removed remote branch '$branch'."
                REMOVED_REMOTE+=("$branch")
            else
                echo "❌ Failed to remove remote branch '$branch'."
                FAILED_REMOVALS+=("remote:$branch")
            fi
        else
            echo "⏭️  Skipped remote removal of '$branch'."
        fi
    else
        echo "ℹ️  Branch '$branch' doesn't exist on remote."
    fi
    
    echo ""
done

# --- Function to detect stale remote references ---
get_stale_remote_branches() {
    local remote_name="${1:-origin}"
    local stale_branches=()
    
    # Run git fetch with prune dry-run to detect stale references
    local fetch_output
    if fetch_output=$(git fetch "$remote_name" --prune --dry-run 2>&1); then
        # Parse output to find what would be pruned
        while IFS= read -r line; do
            if [[ "$line" =~ \[would\ prune\].*$remote_name/(.+) ]]; then
                stale_branches+=("$remote_name/${BASH_REMATCH[1]}")
            elif [[ "$line" =~ ^\ -\ \[would\ prune\].*$remote_name/(.+) ]]; then
                stale_branches+=("$remote_name/${BASH_REMATCH[1]}")
            fi
        done <<< "$fetch_output"
    fi
    
    printf '%s\n' "${stale_branches[@]}"
}

# --- Summary ---
echo "🎉 Branch cleanup completed!"
echo ""

if [[ ${#REMOVED_LOCAL[@]} -gt 0 ]]; then
    echo "✅ Successfully removed local branches:"
    for branch in "${REMOVED_LOCAL[@]}"; do
        echo "   🗑️  $branch"
    done
    echo ""
fi

if [[ ${#REMOVED_REMOTE[@]} -gt 0 ]]; then
    echo "✅ Successfully removed remote branches:"
    for branch in "${REMOVED_REMOTE[@]}"; do
        echo "   🌐 $branch"
    done
    echo ""
fi

if [[ ${#FAILED_REMOVALS[@]} -gt 0 ]]; then
    echo "❌ Failed removals:"
    for failure in "${FAILED_REMOVALS[@]}"; do
        echo "   ⚠️  $failure"
    done
    echo ""
fi

if [[ ${#REMOVED_LOCAL[@]} -eq 0 && ${#REMOVED_REMOTE[@]} -eq 0 ]]; then
    echo "ℹ️  No branches were removed."
fi

# --- Check for stale remote-tracking branches ---
echo "🔎 Checking for stale remote-tracking references..."

# Get stale remote branches
mapfile -t STALE_REFS < <(get_stale_remote_branches)

if [[ ${#STALE_REFS[@]} -gt 0 ]]; then
    echo ""
    echo "🔎 Found stale remote-tracking references:"
    for ref in "${STALE_REFS[@]}"; do
        echo "   - $ref"
    done
    echo ""
    echo "💡 These are local cached references to remote branches that"
    echo "   have been deleted. They can be safely cleaned up with:"
    echo "   'git remote prune origin'"
    echo ""
    
    # Ask user if they want to prune
    read -r -p "🗑️  Clean up stale remote references now? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        echo "🔄 Running 'git remote prune origin'..."
        if git remote prune origin; then
            echo "✅ Stale references cleaned up."
        else
            echo "❌ Failed to prune remote references."
        fi
    else
        echo "ℹ️  Skipped. Run 'git remote prune origin' manually when needed."
    fi
else
    echo "✅ Your remote-tracking references are already clean!"
fi 