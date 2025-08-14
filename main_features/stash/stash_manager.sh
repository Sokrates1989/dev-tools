#!/bin/bash

# -----------------------------------------------------------------------------
# Script: stash_manager.sh
#
# Description:
# Interactive stash management tool for Git repositories.
# Provides a persistent menu-driven interface for common stash operations.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load utility functions
source "$SCRIPT_DIR/stash_utils.sh"

# Load environment variables if available
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

# Check if we're in a git repository
if ! check_git_repository; then
    exit 1
fi

# Function to perform stash operation
perform_stash_operation() {
    local operation="$1"
    
    case "$operation" in
        "stash_all")
            echo ""
            echo "📦 Stash All Changes (Including Untracked)"
            echo "=========================================="
            
            # Check if there are changes
            if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
                echo "✅ No changes to stash. Working directory is clean."
                return
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
            echo "📄 Untracked files:"
            git ls-files --others --exclude-standard
            
            if confirm_destructive_action "💾 Stash all changes including untracked files?"; then
                echo ""
                echo "📦 Stashing changes..."
                if git stash push --include-untracked -m "Stash created on $(date '+%Y-%m-%d %H:%M:%S')"; then
                    echo "✅ Successfully stashed all changes including untracked files."
                else
                    echo "❌ Failed to stash changes."
                fi
            else
                echo "❌ Stash operation cancelled."
            fi
            ;;
        "stash_tracked")
            echo ""
            echo "📦 Stash Tracked Changes Only"
            echo "============================="
            
            # Check if there are tracked changes
            if git diff --quiet && git diff --cached --quiet; then
                echo "✅ No tracked changes to stash."
                local untracked=$(git ls-files --others --exclude-standard)
                if [[ -n "$untracked" ]]; then
                    echo ""
                    echo "📄 Untracked files found (will NOT be stashed):"
                    echo "$untracked"
                    echo ""
                    echo "💡 Tip: Use 'Stash all changes' to include untracked files."
                fi
                return
            fi
            
            # Show what will be stashed
            echo ""
            echo "📋 Tracked changes that will be stashed:"
            echo ""
            echo "🔄 Modified files:"
            git diff --name-only
            echo ""
            echo "📁 Staged files:"
            git diff --cached --name-only
            
            if confirm_destructive_action "💾 Stash tracked changes only?"; then
                echo ""
                echo "📦 Stashing tracked changes..."
                if git stash push -m "Tracked changes stash created on $(date '+%Y-%m-%d %H:%M:%S')"; then
                    echo "✅ Successfully stashed tracked changes."
                else
                    echo "❌ Failed to stash changes."
                fi
            else
                echo "❌ Stash operation cancelled."
            fi
            ;;
        "stash_custom")
            echo ""
            echo "📦 Stash with Custom Message"
            echo "============================"
            
            # Check if there are changes
            if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
                echo "✅ No changes to stash. Working directory is clean."
                return
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
            
            # Check for untracked files
            local untracked=$(git ls-files --others --exclude-standard)
            local stash_flags=""
            if [[ -n "$untracked" ]]; then
                echo ""
                echo "📄 Untracked files found:"
                echo "$untracked"
                echo ""
                read -p "📦 Include untracked files in stash? (yes/no): " include_untracked
                if [[ "$include_untracked" == "yes" ]]; then
                    stash_flags="--include-untracked"
                else
                    echo "📄 Untracked files will NOT be stashed."
                fi
            fi
            
            echo ""
            read -p "💬 Enter a custom message for this stash: " custom_message
            
            if [[ -z "$custom_message" ]]; then
                echo "❌ No message provided. Using default message."
                custom_message="Custom stash created on $(date '+%Y-%m-%d %H:%M:%S')"
            fi
            
            echo ""
            echo "📦 Stashing changes with message: '$custom_message'"
            
            if git stash push $stash_flags -m "$custom_message"; then
                echo "✅ Successfully stashed changes with custom message."
            else
                echo "❌ Failed to stash changes."
            fi
            ;;
    esac
}

# Function to show interactive stash list and operations
show_stash_list_interactive() {
    local stash_count=$(get_stash_count)
    
    if [[ $stash_count -eq 0 ]]; then
        echo ""
        echo "📦 No stashes found."
        echo ""
        echo "💡 Tip: Create a stash using one of the stash operations."
        return
    fi
    
    while true; do
        echo ""
        echo "📜 Interactive Stash List – Dev Tools"
        echo "====================================="
        echo ""
        echo "📦 Found $stash_count stash(es):"
        echo ""
        
        if ! list_stashes_numbered; then
            echo "📦 No stashes found."
            return
        fi
        
        echo ""
        echo "Choose an action:"
        echo ""
        echo "📋 View Operations:"
        echo "v) 🔍 View content of a specific stash"
        echo "s) 📊 Show stash summary"
        echo ""
        echo "📤 Apply/Pop Operations:"
        echo "a) 🔄 Apply a specific stash (keep in stash)"
        echo "p) 🔄 Pop a specific stash (remove from stash)"
        echo ""
        echo "🗑️  Cleanup Operations:"
        echo "d) 🗑️  Drop a specific stash"
        echo "c) 🗑️  Clear all stashes"
        echo ""
        echo "b) 🔙 Back to main stash menu"
        echo "q) ❌ Exit stash manager"
        echo ""
        
        read -p "Enter your choice [v, s, a, p, d, c, b, q]: " choice
        
        case "$choice" in
            "v")
                echo ""
                read -p "🔍 Enter stash number or reference to view: " stash_input
                local stash_ref=$(validate_stash_input "$stash_input" "$stash_count")
                if [[ $? -eq 0 ]]; then
                    echo ""
                    echo "📦 Selected stash:"
                    get_stash_info "$stash_ref"
                    echo ""
                    echo "📋 Stash content:"
                    echo "=================="
                    git stash show -p "$stash_ref"
                fi
                wait_for_continue
                ;;
            "s")
                echo ""
                show_stash_summary
                wait_for_continue
                ;;
            "a")
                echo ""
                read -p "🔄 Enter stash number or reference to apply: " stash_input
                local stash_ref=$(validate_stash_input "$stash_input" "$stash_count")
                if [[ $? -eq 0 ]]; then
                    echo ""
                    echo "📦 Selected stash:"
                    get_stash_info "$stash_ref"
                    echo ""
                    show_working_directory_status
                    
                    if confirm_destructive_action "🔄 Apply stash $stash_ref? (This keeps the stash in the stash list)"; then
                        echo ""
                        echo "🔄 Applying stash $stash_ref..."
                        if git stash apply "$stash_ref"; then
                            echo "✅ Successfully applied stash $stash_ref."
                            echo ""
                            echo "📦 Stash remains in the stash list."
                        else
                            echo "❌ Failed to apply stash. There may be conflicts."
                            echo ""
                            echo "💡 Tips for resolving conflicts:"
                            echo "  • Check 'git status' for conflicted files"
                            echo "  • Resolve conflicts manually and commit"
                        fi
                    else
                        echo "❌ Apply operation cancelled."
                    fi
                fi
                wait_for_continue
                ;;
            "p")
                echo ""
                read -p "🔄 Enter stash number or reference to pop: " stash_input
                local stash_ref=$(validate_stash_input "$stash_input" "$stash_count")
                if [[ $? -eq 0 ]]; then
                    echo ""
                    echo "📦 Selected stash:"
                    get_stash_info "$stash_ref"
                    echo ""
                    show_working_directory_status
                    
                    if confirm_destructive_action "🔄 Pop stash $stash_ref? (This applies and removes the stash)"; then
                        echo ""
                        echo "🔄 Popping stash $stash_ref..."
                        if git stash pop "$stash_ref"; then
                            echo "✅ Successfully popped stash $stash_ref."
                            # Update stash count after popping
                            stash_count=$(get_stash_count)
                            if [[ $stash_count -eq 0 ]]; then
                                echo "📦 No more stashes remaining."
                                wait_for_continue
                                return
                            fi
                        else
                            echo "❌ Failed to pop stash. There may be conflicts."
                            echo ""
                            echo "💡 Tips for resolving conflicts:"
                            echo "  • Check 'git status' for conflicted files"
                            echo "  • Resolve conflicts manually and commit"
                        fi
                    else
                        echo "❌ Pop operation cancelled."
                    fi
                fi
                wait_for_continue
                ;;
            "d")
                echo ""
                read -p "🗑️  Enter stash number or reference to drop: " stash_input
                local stash_ref=$(validate_stash_input "$stash_input" "$stash_count")
                if [[ $? -eq 0 ]]; then
                    echo ""
                    echo "📦 Selected stash:"
                    get_stash_info "$stash_ref"
                    echo ""
                    echo "⚠️  Warning: This will permanently delete the stash without applying it."
                    
                    if confirm_destructive_action "🗑️  Drop stash $stash_ref permanently?"; then
                        echo ""
                        echo "🗑️  Dropping stash $stash_ref..."
                        if git stash drop "$stash_ref"; then
                            echo "✅ Successfully dropped stash $stash_ref."
                            # Update stash count after dropping
                            stash_count=$(get_stash_count)
                            if [[ $stash_count -eq 0 ]]; then
                                echo "📦 No more stashes remaining."
                                wait_for_continue
                                return
                            fi
                        else
                            echo "❌ Failed to drop stash."
                        fi
                    else
                        echo "❌ Drop operation cancelled."
                    fi
                fi
                wait_for_continue
                ;;
            "c")
                if [[ $stash_count -eq 0 ]]; then
                    echo "📦 No stashes to clear."
                    wait_for_continue
                    continue
                fi
                
                echo ""
                echo "📦 All stashes that will be permanently deleted:"
                echo ""
                list_stashes_numbered
                echo ""
                echo "⚠️  WARNING: This will permanently delete ALL $stash_count stashes without applying them."
                echo "⚠️  This action cannot be undone!"
                echo ""
                read -p "🗑️  Clear all stashes permanently? Type 'DELETE ALL' to confirm: " confirm
                
                if [[ "$confirm" == "DELETE ALL" ]]; then
                    echo ""
                    echo "🗑️  Clearing all stashes..."
                    if git stash clear; then
                        echo "✅ Successfully cleared all stashes."
                        echo "📦 No stashes remaining."
                        wait_for_continue
                        return
                    else
                        echo "❌ Failed to clear stashes."
                    fi
                else
                    echo "❌ Clear operation cancelled."
                    echo "💡 You must type 'DELETE ALL' exactly to confirm this destructive operation."
                fi
                wait_for_continue
                ;;
            "b"|"B")
                return
                ;;
            "q"|"Q"|"quit"|"exit")
                echo "👋 Exiting stash manager."
                exit 0
                ;;
            *)
                echo "❌ Invalid choice. Try again."
                wait_for_continue
                ;;
        esac
    done
}

# Main interactive loop
while true; do
    echo ""
    echo "📦 Git Stash Manager – Dev Tools"
    echo "================================="
    echo ""
    
    show_repository_status
    show_stash_summary
    
    echo "Choose a stash operation:"
    echo ""
    echo "📥 Stash Operations:"
    echo "1) 📦 Stash all changes (including untracked)"
    echo "2) 📦 Stash only tracked changes"
    echo "3) 📦 Stash with custom message"
    echo ""
    echo "📋 Interactive Operations:"
    echo "4) 📜 Interactive stash list (view, apply, pop, drop)"
    echo ""
    echo "🔄 Quick Operations:"
    echo "5) 🔄 Apply latest stash (keep in stash)"
    echo "6) 🔄 Pop latest stash (remove from stash)"
    echo "7) 🔍 Show content of latest stash"
    echo ""
    echo "b) 🔙 Back to main menu"
    echo "q) ❌ Exit"
    echo ""
    
    read -p "Enter your choice [1-7, b, q]: " choice
    
    case "$choice" in
        1)
            perform_stash_operation "stash_all"
            ;;
        2)
            perform_stash_operation "stash_tracked"
            ;;
        3)
            perform_stash_operation "stash_custom"
            ;;
        4)
            show_stash_list_interactive
            ;;
        5)
            local stash_count=$(get_stash_count)
            if [[ $stash_count -eq 0 ]]; then
                echo ""
                echo "📦 No stashes found to apply."
            else
                echo ""
                echo "📦 Latest stash to apply:"
                git stash list | head -n 1
                echo ""
                show_working_directory_status
                
                if confirm_destructive_action "🔄 Apply the latest stash? (This keeps the stash in the stash list)"; then
                    echo ""
                    echo "🔄 Applying latest stash..."
                    if git stash apply; then
                        echo "✅ Successfully applied latest stash."
                    else
                        echo "❌ Failed to apply stash. There may be conflicts."
                    fi
                else
                    echo "❌ Apply operation cancelled."
                fi
            fi
            ;;
        6)
            local stash_count=$(get_stash_count)
            if [[ $stash_count -eq 0 ]]; then
                echo ""
                echo "📦 No stashes found to pop."
            else
                echo ""
                echo "📦 Latest stash to pop:"
                git stash list | head -n 1
                echo ""
                show_working_directory_status
                
                if confirm_destructive_action "🔄 Pop the latest stash? (This applies and removes the stash)"; then
                    echo ""
                    echo "🔄 Popping latest stash..."
                    if git stash pop; then
                        echo "✅ Successfully popped latest stash."
                    else
                        echo "❌ Failed to pop stash. There may be conflicts."
                    fi
                else
                    echo "❌ Pop operation cancelled."
                fi
            fi
            ;;
        7)
            local stash_count=$(get_stash_count)
            if [[ $stash_count -eq 0 ]]; then
                echo ""
                echo "📦 No stashes found to show."
            else
                echo ""
                echo "📦 Latest stash:"
                git stash list | head -n 1
                echo ""
                echo "📋 Stash content:"
                echo "=================="
                git stash show -p stash@{0}
            fi
            ;;
        "b"|"B")
            bash "$ROOT_DIR/start.sh"
            break
            ;;
        "q"|"Q"|"quit"|"exit")
            echo "👋 Exiting stash manager."
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Try again."
            ;;
    esac
    
    echo ""
    read -p "🔁 Press Enter to return to the stash menu..."
done
