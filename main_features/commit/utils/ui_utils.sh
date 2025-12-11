#!/bin/bash
# -----------------------------------------------------------------------------
# Script: ui_utils.sh
# Description: Utility functions for UI operations in commit scripts
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# Function to show commit message options menu
show_commit_options() {
  local commit_message="$1"
  
  echo ""
  echo "✅ AI suggested commit command:"
  echo "$commit_message"
  echo ""
  echo "Options:"
  echo "[Enter] Accept as is"
  echo "[E] Edit manually"
  echo "[R] Regenerate message"
  echo "[C] Chat with AI"
  echo ""
}

# Function to edit commit message using available editors
edit_commit_message() {
  local commit_line="$1"
  
  if [[ -n "$BASH_VERSION" && "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    # Prompt goes to stderr so it is not captured in command substitution
    read -e -i "$commit_line" -p "📝 Press Enter to accept or edit the command: " final_commit >&2
    # Only the final command is printed to stdout
    echo "$final_commit"
  elif command -v zsh >/dev/null 2>&1; then
    # macOS specific handling - manual file edit approach
    echo "" >&2
    
    # Extract just the message content
    COMMIT_MSG=$(echo "$commit_line" | sed -n 's/git commit -m "\(.*\)"/\1/p')
    
    # Use predictable temp file location
    TEMP_DIR="/tmp/dev-tools"
    TEMP_FILE="$TEMP_DIR/commit_msg.txt"
    mkdir -p "$TEMP_DIR"
    echo "$COMMIT_MSG" > "$TEMP_FILE"
    
    echo "📝 Commit message saved to: $TEMP_FILE" >&2
    echo "" >&2
    echo "Please edit the commit message in your preferred editor:" >&2
    echo "  ➤ Open the file: $TEMP_FILE" >&2
    echo "  ➤ Edit the commit message" >&2
    echo "  ➤ Save the file" >&2
    echo "  ➤ Close the editor" >&2
    echo "" >&2
    
    # Try to open the file with default editor
    if command -v open >/dev/null 2>&1; then
      echo "🔧 Opening file with default editor..." >&2
      open "$TEMP_FILE"
    else
      echo "📂 Please open this file manually: $TEMP_FILE" >&2
    fi
    
    echo "" >&2
    read -p "🔁 Press [Enter] once you've edited the file and saved it..." _ >&2
    
    # Check if file still exists
    if [[ ! -f "$TEMP_FILE" ]]; then
      echo "❌ File was deleted. Aborting commit." >&2
      return 1
    fi
    
    # Read back the edited message
    EDITED_MSG=$(cat "$TEMP_FILE")
    rm "$TEMP_FILE"
    
    if [[ -z "$EDITED_MSG" ]]; then
      echo "⚠️  Empty commit message. Aborting." >&2
      return 1
    fi
    
    # Reconstruct the full git command
    echo "git commit -m \"$EDITED_MSG\""
  else
    echo "" >&2
    echo "📝 You can copy/paste and edit the following:" >&2
    echo "$commit_line" >&2
    if command -v pbcopy >/dev/null 2>&1; then
      echo "$commit_line" | pbcopy
      echo "📋 Commit command copied to clipboard!" >&2
    fi
    read -r -p "Enter your edited commit command: " final_commit >&2
    # Only the final edited command is printed to stdout
    echo "$final_commit"
  fi
}

# Function to validate commit message format
validate_commit_message() {
  local commit_message="$1"
  
  if [[ -z "$commit_message" ]]; then
    echo "❌ Commit message is empty. Please rerun the script or commit manually."
    return 1
  fi
  
  # Basic validation - should contain git commit -m
  if [[ ! "$commit_message" =~ git[[:space:]]commit[[:space:]]-m ]]; then
    echo "❌ Invalid commit command format!"
    echo "The command should follow this structure:"
    echo 'git commit -m "Your message here"'
    return 1
  fi
  
  return 0
}

# Function to check if output indicates git corruption
check_for_git_corruption() {
  local output="$1"
  if echo "$output" | grep -qE "(far too short to be a packfile|invalid object|Error building trees|broken link|missing blob|missing tree|fatal: unable to read tree)"; then
    return 0  # Corruption detected
  fi
  return 1  # No corruption
}

# Function to offer git repair
offer_git_repair() {
  echo ""
  echo "⚠️  Git repository corruption detected!"
  echo ""
  echo "This error typically occurs when pack files in your .git directory are corrupted."
  echo ""
  
  # Check if dev-tools repair is available
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local repair_script="$script_dir/../../git-repair/git_repair.sh"
  
  if [[ -f "$repair_script" ]]; then
    read -r -p "🔧 Would you like to attempt automatic repair? [Y/n]: " repair_confirm
    if [[ ! "$repair_confirm" =~ ^[Nn]$ ]]; then
      echo ""
      source "$repair_script"
      repair_git_repo "."
      return $?
    fi
  else
    echo "To repair this repository, you can run:"
    echo "  dev-tools --repair"
    echo ""
    echo "Or manually:"
    echo "  1. Backup your uncommitted changes"
    echo "  2. Remove corrupted pack files from .git/objects/pack/"
    echo "  3. Run: git fetch --all"
    echo "  4. Run: git gc --prune=now"
  fi
  return 1
}

# Function to handle commit execution
execute_commit() {
  local commit_command="$1"
  
  echo ""
  echo "🚀 Final commit command:"
  echo "$commit_command"
  read -r -p "👉 Do you want to run this commit command now? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    # Capture both stdout and stderr, and the exit code
    local commit_output
    local commit_exit_code
    commit_output=$(eval "$commit_command" 2>&1)
    commit_exit_code=$?
    
    # Display the output
    echo "$commit_output"
    
    # Check if commit failed
    if [[ $commit_exit_code -ne 0 ]]; then
      echo ""
      echo "❌ Commit failed (exit code: $commit_exit_code)"
      
      # Check if it's a corruption error
      if check_for_git_corruption "$commit_output"; then
        offer_git_repair
        local repair_result=$?
        if [[ $repair_result -eq 0 ]]; then
          echo ""
          echo "📦 Staging all changes before retrying the commit (git add -A)..."
          if ! git add -A; then
            echo "⚠️  'git add -A' reported errors. Please check 'git status' before retrying."
          fi
          echo ""

          # Check for any remaining repaired/broken repos next to this repo
          local repo_dir parent_dir repo_name
          repo_dir="$(pwd)"
          parent_dir="$(cd .. && pwd)"
          repo_name="$(basename "$repo_dir")"
          local leftover_dirs=()

          for d in "$parent_dir"/"${repo_name}"-broken-* "$parent_dir"/"${repo_name}"-repaired-*; do
            if [[ -d "$d" ]]; then
              leftover_dirs+=("$d")
            fi
          done

          if [[ ${#leftover_dirs[@]} -gt 0 ]]; then
            echo "The following repaired/broken repositories are still present:" 
            for d in "${leftover_dirs[@]}"; do
              echo "  - $d"
            done
            echo ""
            echo "You can remove them manually later with:" 
            for d in "${leftover_dirs[@]}"; do
              echo "  rm -rf \"$d\""
            done
            echo ""
            read -r -p "Type 'remove' to delete ALL of these repair/broken directories now. Otherwise press Enter to keep them: " cleanup_confirm
            if [[ "$cleanup_confirm" == "remove" ]]; then
              echo "Removing repair/broken directories..."
              for d in "${leftover_dirs[@]}"; do
                rm -rf "$d"
              done
              echo "✅ Cleanup completed."
            fi
            echo ""
          fi

          read -r -p "🔄 Retry the commit now? [Y/n]: " retry_confirm
          if [[ ! "$retry_confirm" =~ ^[Nn]$ ]]; then
            execute_commit "$commit_command"
          fi
        fi
      else
        echo "Please check the error message above and resolve the issue."
      fi
      return 1
    fi
    
    echo "✅ Commit executed."

    # Ask user to push commits immediately to the remote.
    echo ""
    read -r -p "🚀 Do you want to push the commit to the remote now? [y/N]: " push_confirm
    if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
      echo "📡 Pushing changes to remote..."
      local push_output
      push_output=$(git push 2>&1)
      local push_exit_code=$?
      echo "$push_output"
      
      if [[ $push_exit_code -eq 0 ]]; then
        echo "✅ Push successful!"
      else
        echo "❌ Push failed. Please check your Git configuration or network."
        
        # Check for corruption in push output too
        if check_for_git_corruption "$push_output"; then
          offer_git_repair
        fi
      fi
    else
      echo "ℹ️ Push skipped. You can run 'git push' later manually."
    fi
  else
    echo "ℹ️ Commit not executed. You can run it manually:"
    echo "$commit_command"
  fi
}

# Function to get user choice for commit options
get_user_choice() {
  read -r -p "Choose an option: " choice
  echo "$choice"
}

# Function to get chat instructions from user
get_chat_instructions() {
  echo ""
  echo "💬 Enter your message to chat with the AI about the commit message:"
  echo "Example: 'Make it more concise' or 'Add more technical details' or any other instruction."
  echo ""
  
  read -r -p "Chat message to AI: " chat_prompt
  echo "$chat_prompt"
}

# Function to get improvement instructions from user
get_improvement_instructions() {
  echo ""
  echo "💡 Enter your improvement instructions for the commit message:"
  echo "Example: 'Make it more concise' or 'Add more technical details'"
  echo ""
  
  read -r -p "Improvement instructions: " improvement_prompt
  echo "$improvement_prompt"
}

# Function to show error message for invalid options
show_invalid_option() {
  echo "Invalid option. Please choose [Enter], [E], [R], or [C]."
}

# Function to show success message for regeneration
show_regeneration_success() {
  echo "✅ New commit message generated."
}

# Function to show success message for improvement
show_improvement_success() {
  echo "✅ Commit message improved."
}

# Function to show error message for failed API operations
show_api_error() {
  local operation="$1"
  echo "❌ Failed to $operation commit message. Please try again."
} 