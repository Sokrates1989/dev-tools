#!/bin/bash
# -----------------------------------------------------------------------------
# Script: git_corruption_check.sh
# Description: Shared utilities for detecting and handling git corruption
# Usage: Source this file in other scripts to get corruption detection
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# Function to check if output indicates git corruption
# Usage: if check_git_corruption_in_output "$output"; then ...
check_git_corruption_in_output() {
    local output="$1"
    if echo "$output" | grep -qE "(far too short to be a packfile|invalid object|Error building trees|broken link|missing blob|missing tree|fatal: unable to read tree|unable to read)"; then
        return 0  # Corruption detected
    fi
    return 1  # No corruption
}

# Function to show git corruption error message and repair instructions
# Usage: show_git_corruption_message
show_git_corruption_message() {
    echo ""
    echo "⚠️  Git repository corruption detected!"
    echo ""
    echo "This error typically occurs when pack files in your .git directory are corrupted."
    echo ""
    echo "To repair this repository, you can run:"
    echo "  dev-tools --repair"
    echo "  or: dev-tools -f"
    echo ""
    echo "Or manually:"
    echo "  1. Backup your uncommitted changes"
    echo "  2. Remove corrupted pack files from .git/objects/pack/"
    echo "  3. Run: git fetch --all"
    echo "  4. Run: git gc --prune=now"
    echo ""
}

# Function to offer to run dev-tools repair
# Usage: offer_devtools_repair
# Returns: 0 if repair was run successfully, 1 otherwise
offer_devtools_repair() {
    echo ""
    read -r -p "🔧 Would you like to attempt automatic repair using dev-tools? [Y/n]: " repair_confirm
    if [[ ! "$repair_confirm" =~ ^[Nn]$ ]]; then
        # Try to find dev-tools
        if command -v dev-tools >/dev/null 2>&1; then
            echo ""
            echo "Running: dev-tools --repair"
            dev-tools --repair
            return $?
        else
            echo ""
            echo "❌ dev-tools command not found in PATH."
            echo "Please install dev-tools or run the repair manually."
            show_git_corruption_message
            return 1
        fi
    fi
    return 1
}

# Function to check git command output and handle corruption
# Usage: handle_git_command_result "$exit_code" "$output" "$operation_name"
# Returns: 0 if no error, 1 if error (with corruption handling if applicable)
handle_git_command_result() {
    local exit_code="$1"
    local output="$2"
    local operation_name="${3:-Git operation}"
    
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "❌ $operation_name failed (exit code: $exit_code)"
        
        if check_git_corruption_in_output "$output"; then
            show_git_corruption_message
            offer_devtools_repair
            return 1
        fi
        
        return 1
    fi
    
    return 0
}

# Function to run a git command with corruption detection
# Usage: run_git_with_corruption_check "git command" "operation name"
# Returns: exit code of the command (after potential repair)
run_git_with_corruption_check() {
    local git_command="$1"
    local operation_name="${2:-Git operation}"
    
    local output
    local exit_code
    
    output=$(eval "$git_command" 2>&1)
    exit_code=$?
    
    echo "$output"
    
    if ! handle_git_command_result "$exit_code" "$output" "$operation_name"; then
        return 1
    fi
    
    return 0
}
