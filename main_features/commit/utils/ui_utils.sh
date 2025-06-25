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
    read -e -i "$commit_line" -p "📝 Press Enter to accept or edit the command: " final_commit
    echo "$final_commit"
  elif command -v zsh >/dev/null 2>&1; then
    # macOS specific handling
    echo ""
    read -r -p "📝 Press Enter to accept, type 'n' for [N]ano, 'v' for [V]i, or specify another editor: " editor_choice
    
    if [[ -n "$editor_choice" ]]; then
      # Determine editor based on choice
      case "$editor_choice" in
        [nN]*)
          EDITOR_CHOICE="nano"
          ;;
        [vV]*)
          EDITOR_CHOICE="vi"
          ;;
        *)
          # Use whatever they typed as the editor command
          EDITOR_CHOICE="$editor_choice"
          ;;
      esac

      # Verify editor exists
      if ! command -v "$EDITOR_CHOICE" >/dev/null 2>&1; then
        echo "⚠️  Editor '$EDITOR_CHOICE' not found. Falling back to vi."
        EDITOR_CHOICE="vi"
      fi

      # Extract just the message content
      COMMIT_MSG=$(echo "$commit_line" | sed -n 's/git commit -m "\(.*\)"/\1/p')
      
      # Create temp file with just the message
      TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/commit_msg.XXXXXX")
      echo "$COMMIT_MSG" > "$TEMP_FILE"
      
      # Open editor with clear instructions
      echo ""
      echo "✏️  Editing with $EDITOR_CHOICE..."
      echo "   - Modify your commit message"
      echo "   - Save and exit to continue"
      echo "   - Cancel the editor to abort"
      echo ""
      
      if ! "$EDITOR_CHOICE" "$TEMP_FILE"; then
        echo "⚠️  Editor exited with error. Aborting commit."
        rm -f "$TEMP_FILE"
        return 1
      fi
      
      # Read back the edited message
      EDITED_MSG=$(cat "$TEMP_FILE")
      rm "$TEMP_FILE"
      
      if [[ -z "$EDITED_MSG" ]]; then
        echo "⚠️  Empty commit message. Aborting."
        return 1
      fi
      
      # Reconstruct the full git command
      echo "git commit -m \"$EDITED_MSG\""
    else
      # Accept as-is
      echo "$commit_line"
    fi
  else
    echo ""
    echo "📝 You can copy/paste and edit the following:"
    echo "$commit_line"
    if command -v pbcopy >/dev/null 2>&1; then
      echo "$commit_line" | pbcopy
      echo "📋 Commit command copied to clipboard!"
    fi
    read -r -p "Enter your edited commit command: " final_commit
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

# Function to handle commit execution
execute_commit() {
  local commit_command="$1"
  
  echo ""
  echo "🚀 Final commit command:"
  echo "$commit_command"
  read -r -p "👉 Do you want to run this commit command now? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    eval "$commit_command"
    echo "✅ Commit executed."

    # Ask user to push commits immediately to the remote.
    echo ""
    read -r -p "🚀 Do you want to push the commit to the remote now? [y/N]: " push_confirm
    if [[ "$push_confirm" =~ ^[Yy]$ ]]; then
      echo "📡 Pushing changes to remote..."
      git push
      if [[ $? -eq 0 ]]; then
        echo "✅ Push successful!"
      else
        echo "❌ Push failed. Please check your Git configuration or network."
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