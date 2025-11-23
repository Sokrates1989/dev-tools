#!/bin/bash
# -----------------------------------------------------------------------------
# Script: handle_export_api.sh
# Description: Sends exported commit data to AI API using settings from .env
# Platform: Bash/Zsh compatible
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALL_IN_ONE_AI_MESSAGE_FILE="$SCRIPT_DIR/git_export_staged/all_in_one/ai_message.txt"

# Load environment variables.
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

# Load commit variables from git_export_staged
VARS_FILE="$SCRIPT_DIR/git_export_staged/.commit_vars"
JIRA_ID=""
IMAGE_VERSION=""
VERSION_FILES_STAGED=""

if [[ -f "$VARS_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$VARS_FILE"
fi

# Load utility functions
# shellcheck source=utils/api_utils.sh
source "$SCRIPT_DIR/utils/api_utils.sh"
# shellcheck source=utils/ui_utils.sh
source "$SCRIPT_DIR/utils/ui_utils.sh"

# --- Prerequisite checks ---
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 'jq' is required but not installed. Please install it and try again."
  exit 1
fi

if [[ ! -f "$ALL_IN_ONE_AI_MESSAGE_FILE" ]]; then
  echo "❌ Cannot find AI message file: $ALL_IN_ONE_AI_MESSAGE_FILE"
  exit 1
fi

# Validate API configuration
if ! validate_api_config "$API_KEY" "$API_PROVIDER" "$API_BASE"; then
  exit 1
fi

# --- Build API configuration ---
API_CONFIG=$(build_api_config "$API_PROVIDER" "$API_BASE" "$API_KEY" "$DEPLOYMENT" "$API_VERSION")
API_URL=$(echo "$API_CONFIG" | cut -d'|' -f1)
AUTH_HEADER=$(echo "$API_CONFIG" | cut -d'|' -f2)

# --- Compose and send initial request ---
echo "🚀 Sending prompt to $API_PROVIDER..."

USER_CONTENT=$(cat "$ALL_IN_ONE_AI_MESSAGE_FILE")

# Build initial messages
INITIAL_MESSAGES=$(build_conversation_messages "$USER_CONTENT")

# Build and send initial request
JSON_PAYLOAD=$(build_json_payload "$INITIAL_MESSAGES" "$API_PROVIDER" "$DEPLOYMENT" "$TEMPERATURE" "$MAX_TOKENS")
RESPONSE=$(send_api_request "$JSON_PAYLOAD" "$API_URL" "$AUTH_HEADER")

# --- Extract and show response ---
COMMIT_LINE=$(get_commit_message "$RESPONSE")

# Function to replace placeholders in commit message
replace_placeholders() {
  local message="$1"
  local jira="$2"
  local version="$3"
  
  # Replace VERSION_PLACEHOLDER first
  if [[ -n "$version" ]]; then
    message="${message//VERSION_PLACEHOLDER/$version}"
  else
    # Remove VERSION_PLACEHOLDER and the pipe separator
    message=$(echo "$message" | sed -E 's/\s*VERSION_PLACEHOLDER\s*\|\s*//g')
    message=$(echo "$message" | sed -E 's/\s*\|\s*VERSION_PLACEHOLDER\s*//g')
  fi
  
  # Replace JIRA_ID_PLACEHOLDER
  if [[ -n "$jira" ]]; then
    message="${message//JIRA_ID_PLACEHOLDER/$jira}"
  else
    # Remove JIRA_ID_PLACEHOLDER and the pipe separator
    message=$(echo "$message" | sed -E 's/\s*JIRA_ID_PLACEHOLDER\s*\|\s*//g')
    message=$(echo "$message" | sed -E 's/\s*\|\s*JIRA_ID_PLACEHOLDER\s*//g')
  fi
  
  echo "$message"
}

if [[ -n "$COMMIT_LINE" ]]; then
  # Replace placeholders in initial commit message
  COMMIT_LINE=$(replace_placeholders "$COMMIT_LINE" "$JIRA_ID" "$IMAGE_VERSION")
  
  # Main interaction loop
  while true; do
    show_commit_options "$COMMIT_LINE"
    choice=$(get_user_choice)

    case "$choice" in
      "")
        # Accept as-is
        FINAL_COMMIT="$COMMIT_LINE"
        break
        ;;
      [Ee])
        # Edit manually
        FINAL_COMMIT=$(edit_commit_message "$COMMIT_LINE")
        
        if [[ $? -ne 0 ]]; then
          exit 1
        fi
        
        if ! validate_commit_message "$FINAL_COMMIT"; then
          exit 1
        fi
        
        break
        ;;
      [Rr])
        # Regenerate message
        echo ""
        echo "🔄 Regenerating commit message..."
        
        # Add context that previous output was not accepted
        REGENERATE_MESSAGES=$(build_conversation_messages \
          "$USER_CONTENT" \
          "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages." \
          "$COMMIT_LINE" \
          "The previous commit message was not accepted. Please generate a different commit message with a different approach or style.")
        
        JSON_PAYLOAD=$(build_json_payload "$REGENERATE_MESSAGES" "$API_PROVIDER" "$DEPLOYMENT" "$TEMPERATURE" "$MAX_TOKENS")
        RESPONSE=$(send_api_request "$JSON_PAYLOAD" "$API_URL" "$AUTH_HEADER")
        NEW_COMMIT_LINE=$(get_commit_message "$RESPONSE")
        
        if [[ -n "$NEW_COMMIT_LINE" ]]; then
          # Replace placeholders in regenerated message
          COMMIT_LINE=$(replace_placeholders "$NEW_COMMIT_LINE" "$JIRA_ID" "$IMAGE_VERSION")
          show_regeneration_success
        else
          show_api_error "regenerate"
          exit 1
        fi
        ;;
      [Cc])
        # Chat with AI
        chat_prompt=$(get_chat_instructions)
        
        if [[ -z "$chat_prompt" ]]; then
          echo "No chat message provided. Keeping current message."
        else
          echo ""
          echo "💬 Chatting with AI..."
          
          # Add chat context
          CHAT_MESSAGES=$(build_conversation_messages \
            "$USER_CONTENT" \
            "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages." \
            "$COMMIT_LINE" \
            "$chat_prompt")
          
          JSON_PAYLOAD=$(build_json_payload "$CHAT_MESSAGES" "$API_PROVIDER" "$DEPLOYMENT" "$TEMPERATURE" "$MAX_TOKENS")
          RESPONSE=$(send_api_request "$JSON_PAYLOAD" "$API_URL" "$AUTH_HEADER")
          NEW_COMMIT_LINE=$(get_commit_message "$RESPONSE")
          
          if [[ -n "$NEW_COMMIT_LINE" ]]; then
            # Replace placeholders in chat response
            COMMIT_LINE=$(replace_placeholders "$NEW_COMMIT_LINE" "$JIRA_ID" "$IMAGE_VERSION")
            show_improvement_success
          else
            show_api_error "chat"
            exit 1
          fi
        fi
        ;;
      *)
        show_invalid_option
        ;;
    esac
  done

  if [[ -n "$FINAL_COMMIT" ]]; then
    # Show version files that were staged if any
    if [[ -n "$VERSION_FILES_STAGED" ]]; then
      echo ""
      echo "📝 Version files included in this commit: $VERSION_FILES_STAGED"
    fi
    
    execute_commit "$FINAL_COMMIT"
  fi
else
  echo "⚠️ Could not extract commit command from AI response."
  echo ""
  echo "🧠 Full AI response:"
  echo "$RESPONSE" | jq .
fi
