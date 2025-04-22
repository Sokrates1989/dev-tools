
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


# --- Prerequisite checks ---
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ 'jq' is required but not installed. Please install it and try again."
  exit 1
fi

if [[ ! -f "$ALL_IN_ONE_AI_MESSAGE_FILE" ]]; then
  echo "❌ Cannot find AI message file: $ALL_IN_ONE_AI_MESSAGE_FILE"
  exit 1
fi


# --- Build API URL ---
if [[ "$API_PROVIDER" == "openai" ]]; then
  API_URL="${API_BASE}chat/completions"
  AUTH_HEADER="Authorization: Bearer ${API_KEY}"
elif [[ "$API_PROVIDER" == "azure" ]]; then
  API_URL="${API_BASE}openai/deployments/${DEPLOYMENT}/chat/completions?api-version=${API_VERSION}"
  AUTH_HEADER="api-key: ${API_KEY}"
else
  echo "❌ Invalid API_PROVIDER in .env: $API_PROVIDER"
  exit 1
fi

# --- Compose and send request ---
echo "🚀 Sending prompt to $API_PROVIDER..."

USER_CONTENT=$(cat "$ALL_IN_ONE_AI_MESSAGE_FILE")

# Build JSON payload
if [[ "$API_PROVIDER" == "openai" ]]; then
  JSON_PAYLOAD=$(jq -n \
    --arg model "$DEPLOYMENT" \
    --arg content "$USER_CONTENT" \
    --arg temp "$TEMPERATURE" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      model: $model,
      messages: [
        { role: "system", content: "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages." },
        { role: "user", content: $content }
      ],
      temperature: ($temp | tonumber),
      max_tokens: $max_tokens
    }')
else
  JSON_PAYLOAD=$(jq -n \
    --arg content "$USER_CONTENT" \
    --arg temp "$TEMPERATURE" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      messages: [
        { role: "system", content: "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git commit messages." },
        { role: "user", content: $content }
      ],
      temperature: ($temp | tonumber),
      max_tokens: $max_tokens
    }')
fi

# Make the request
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$JSON_PAYLOAD")

# --- Extract and show response ---
COMMIT_LINE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' | sed -n 's/.*\(git commit -m .*"\).*/\1/p')

if [[ -n "$COMMIT_LINE" ]]; then
  echo ""
  echo "✅ AI suggested commit command:"
  echo "$COMMIT_LINE"

  # Let user edit or accept
  if [[ -n "$BASH_VERSION" && "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    read -e -i "$COMMIT_LINE" -p "📝 Press Enter to accept or edit the command: " FINAL_COMMIT
  elif command -v zsh >/dev/null 2>&1; then
    # macOS specific handling.
    echo ""
    read -r -p "📝 Press Enter to accept, type 'n' for [N]ano, 'v' for [V]i, or specify another editor: " choice
    
    if [[ -n "$choice" ]]; then
      # Determine editor based on choice
      case "$choice" in
        [nN]*)
          EDITOR_CHOICE="nano"
          ;;
        [vV]*)
          EDITOR_CHOICE="vi"
          ;;
        *)
          # Use whatever they typed as the editor command
          EDITOR_CHOICE="$choice"
          ;;
      esac

      # Verify editor exists
      if ! command -v "$EDITOR_CHOICE" >/dev/null 2>&1; then
        echo "⚠️  Editor '$EDITOR_CHOICE' not found. Falling back to vi."
        EDITOR_CHOICE="vi"
      fi

      # Extract just the message content
      COMMIT_MSG=$(echo "$COMMIT_LINE" | sed -n 's/git commit -m "\(.*\)"/\1/p')
      
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
        exit 1
      fi
      
      # Read back the edited message
      EDITED_MSG=$(cat "$TEMP_FILE")
      rm "$TEMP_FILE"
      
      if [[ -z "$EDITED_MSG" ]]; then
        echo "⚠️  Empty commit message. Aborting."
        exit 1
      fi
      
      # Reconstruct the full git command
      FINAL_COMMIT="git commit -m \"$EDITED_MSG\""
    else
      # Accept as-is
      FINAL_COMMIT="$COMMIT_LINE"
    fi
  else
    echo ""
    echo "📝 You can copy/paste and edit the following:"
    echo "$COMMIT_LINE"
    if command -v pbcopy >/dev/null 2>&1; then
      echo "$COMMIT_LINE" | pbcopy
      echo "📋 Commit command copied to clipboard!"
    fi
    FINAL_COMMIT=""
  fi

  if [[ -n "$FINAL_COMMIT" ]]; then
    echo ""
    echo "🚀 Final commit command:"
    echo "$FINAL_COMMIT"
    read -r -p "👉 Do you want to run this commit command now? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      eval "$FINAL_COMMIT"
      echo "✅ Commit executed."

      # Ask user to push commits immeadiately to the remote.
      echo ""
      read -r -p "🚀 Do you want to push the commit to the remote now? [y/N]: " PUSH_CONFIRM
      if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
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
      echo "$FINAL_COMMIT"
    fi
  fi
else
  echo "⚠️ Could not extract commit command from AI response."
  echo ""
  echo "🧠 Full AI response:"
  echo "$RESPONSE" | jq .
fi
