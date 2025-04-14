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
AI_MESSAGE_FILE="$SCRIPT_DIR/git_export_merge/all_in_one/ai_message.txt"

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
    FINAL_COMMIT=$(zsh -c "read -e '?📝 Press Enter to accept or edit the command:' cmd; echo \$cmd" <<< "$COMMIT_LINE")
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

      read -r -p "🚀 Do you want to push the changes now? [y/N]: " PUSH_CONFIRM
      if [[ "$PUSH_CONFIRM" =~ ^[Yy]$ ]]; then
        git push && echo "✅ Changes pushed." || echo "❌ Push failed."
      else
        echo "ℹ️ Skipped pushing. You can push manually anytime with 'git push'."
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
