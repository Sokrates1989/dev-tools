#!/bin/bash

# -----------------------------------------------------------------------------
# Script: stash_utils.sh
#
# Description:
# Common utility functions for stash operations.
# These functions can be reused across different stash scripts.
# -----------------------------------------------------------------------------

# Function to check if we're in a git repository
check_git_repository() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: Not in a Git repository."
        echo "Please navigate to a Git repository and try again."
        return 1
    fi
    return 0
}

# Function to get stash count
get_stash_count() {
    git stash list | wc -l | tr -d ' '
}

# Function to display repository status
show_repository_status() {
    echo "📋 Current Repository Status:"
    echo "Repository: $(basename "$(git rev-parse --show-toplevel)")"
    echo "Branch: $(git branch --show-current)"
    echo ""
}

# Function to display stash count and latest stash
show_stash_summary() {
    local stash_count=$(get_stash_count)
    echo "📦 Current Stash Count: $stash_count"
    if [[ $stash_count -gt 0 ]]; then
        echo "Latest stash: $(git stash list | head -n 1)"
    fi
    echo ""
}

# Function to list all stashes with numbered format
list_stashes_numbered() {
    local stash_list=$(git stash list)
    if [[ -z "$stash_list" ]]; then
        return 1
    fi
    
    echo "$stash_list" | nl -w3 -s') '
    return 0
}

# Function to validate stash input and convert to reference
validate_stash_input() {
    local input="$1"
    local stash_count="$2"
    
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # User entered a number, convert to stash reference
        local stash_index=$((input - 1))
        if [[ $stash_index -lt 0 || $stash_index -ge $stash_count ]]; then
            echo "❌ Invalid stash index. Please enter a number between 1 and $stash_count."
            return 1
        fi
        echo "stash@{$stash_index}"
        return 0
    elif [[ "$input" =~ ^stash@\{[0-9]+\}$ ]]; then
        # User entered a stash reference
        local stash_index=$(echo "$input" | sed 's/stash@{\([0-9]*\)}/\1/')
        if [[ $stash_index -ge $stash_count ]]; then
            echo "❌ Invalid stash reference. Stash $input does not exist."
            return 1
        fi
        echo "$input"
        return 0
    else
        echo "❌ Invalid input. Please enter a number or stash reference like 'stash@{0}'."
        return 1
    fi
}

# Function to get stash info by reference
get_stash_info() {
    local stash_ref="$1"
    git stash list | grep "^$stash_ref:"
}

# Function to show working directory status
show_working_directory_status() {
    echo "📋 Current working directory status:"
    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo "✅ Working directory is clean."
    else
        echo "⚠️  Working directory has uncommitted changes:"
        git status --porcelain
        echo ""
        echo "⚠️  Warning: Stash operations may conflict with current changes."
    fi
}

# Function to wait for user to continue
wait_for_continue() {
    echo ""
    read -p "🔁 Press Enter to continue..."
}

# Function to confirm destructive action
confirm_destructive_action() {
    local message="$1"
    echo ""
    read -p "$message (yes/no): " confirm
    [[ "$confirm" == "yes" ]]
}
