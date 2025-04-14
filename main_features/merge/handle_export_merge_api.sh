#!/bin/bash

# -----------------------------------------------------------------------------
# Script: handle_merge_api.sh
#
# Description:
# Sends merge context to AI API to generate a commit message.
# -----------------------------------------------------------------------------

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AI_MESSAGE_FILE="$1"
TARGET_BRANCH="$2"

# Load environment variables
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

if [[ ! -f "$AI_MESSAGE_FILE" ]]; then
  echo "❌ Cannot find AI message file: $AI_MESSAGE_FILE"
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

RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -H "$AUTH_HEADER" \
  -d "$(jq -n \
    --arg content "$(cat "$AI_MESSAGE_FILE")" \
    --arg temp "$TEMPERATURE" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      model: env.DEPLOYMENT,
      messages: [
        { role: "system", content: "You are a helpful expert developer with decades of experience in writing clean, concise and context-aware Git merge commit messages." },
        { role: "user", content: $content }
      ],
      temperature: ($temp | tonumber),
      max_tokens: $max_tokens
    }')"
)

# --- Extract and validate response ---
RAW_SUGGESTED_MESSAGE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' | xargs)

if ! echo "$RAW_SUGGESTED_MESSAGE" | grep -qE '^\[MERGE \|.+->.+\]'; then
  echo "❌ AI response doesn't match expected format."
  echo "🔍 Received: $RAW_SUGGESTED_MESSAGE"
  exit 1
fi


# --- Handle merge command ---
if [[ -n "$RAW_SUGGESTED_MESSAGE" ]]; then
  echo ""
  echo "✅ AI suggested merge message:"
  echo "$RAW_SUGGESTED_MESSAGE"

  # Let user edit or accept
  if [[ -n "$BASH_VERSION" && "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    read -e -i "$RAW_SUGGESTED_MESSAGE" -p "📝 Press Enter to accept or edit the message: " FINAL_MESSAGE
  elif command -v zsh >/dev/null 2>&1; then
    FINAL_MESSAGE=$(zsh -c "read -e '?📝 Press Enter to accept or edit the command:' cmd; echo \$cmd" <<< "$RAW_SUGGESTED_MESSAGE")
  else
    echo ""
    echo "📝 You can copy/paste and edit the following:"
    echo "$RAW_SUGGESTED_MESSAGE"
    if command -v pbcopy >/dev/null 2>&1; then
      echo "$RAW_SUGGESTED_MESSAGE" | pbcopy
      echo "📋 Merge command copied to clipboard!"
    fi
    FINAL_MESSAGE=""
  fi

  if [[ -n "$FINAL_MESSAGE" ]]; then
    echo ""
    echo "🚀 Final merge command:"
    echo git merge --no-ff "$TARGET_BRANCH" -m "$FINAL_MESSAGE"
    read -r -p "👉 Do you want to run this commit command now? [y/N]: " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
      git merge --no-ff "$TARGET_BRANCH" -m "$FINAL_MESSAGE"
      echo "✅ Merge successfully executed."

      read -r -p "🚀 Do you want to push the changes now? [y/N]: " PUSH_CONFIRM
      if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
        git push && echo "✅ Changes pushed." || echo "❌ Push failed."
      else
        echo "ℹ️ Skipped pushing. You can push manually anytime with 'git push'."
      fi
    else
      echo "ℹ️  not executed. You can run it manually:"
      echo git merge --no-ff "$TARGET_BRANCH" -m "$FINAL_MESSAGE"
    fi
  fi
else
  echo "⚠️ Could not extract commit command from AI response."
  echo ""
  echo "🧠 Full AI response:"
  echo "$RESPONSE" | jq .
fi
