#!/bin/bash

# -----------------------------------------------------------------------------
# Script: git_export_staged.sh
#
# Description:
# This script does two things:
# 1. Exports the current staged diff using `git diff --staged` into a file
#    named `last_staged_commit_diff.txt`.
# 2. Copies all staged files into a flat folder named `changedFiles/`,
#    stripping away any directory structure.
#
# Useful for code review, CI pipelines, pre-commit backups, or patch creation.
# -----------------------------------------------------------------------------

# Resolve script location (so paths work anywhere).
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST_DIR="$SCRIPT_DIR/git_export_staged/changed_files"
DIFF_FILE="$SCRIPT_DIR/git_export_staged/last_staged_commit_diff.txt"

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
bash "$ROOT_DIR/check_for_updates.sh"

# ✅ Define the function early
print_export_instructions() {
    echo ""
    if [[ "$OS" == "Darwin" ]]; then
        echo "📂 Export folder will open in Finder."
        echo "🔍 To see all files (e.g., .gitignore): Press ⌘ + Shift + ."
    elif [[ "$OS" == "Linux" ]]; then
        echo "📂 Export folder will open in your file manager."
        echo "🔍 To see all files (e.g., .gitignore): Press Ctrl + H"
    fi
    echo ""
    echo "🤖 Copy the content of the opened folder to your preferred AI tool,"
    echo "   or alternatively just paste the file:"
    echo "   → $ALL_IN_ONE_AI_MESSAGE_FILE"
    echo ""
    echo "📝 Then, add the related Project Task ID (if available), or write: \"no task ID\""
    echo ""
}


# Clean up previous outputs.
rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"
rm -f "$DIFF_FILE"

# Export staged diff to file.
git diff --staged > "$DIFF_FILE"

# Get list of staged files.
FILES=$(git diff --name-only --cached)

# Exit early if no staged files.
if [[ -z "$FILES" ]]; then
    echo "⚠️  No staged files found. Please stage some changes with 'git add' before running this script."
    exit 0
fi

# Copy staged files to the flat destination directory.
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        cp "$file" "$DEST_DIR/$(basename "$file")"
    fi
done <<< "$FILES"



# Copy commit_message_prompt.txt if available
COMMIT_MSG_FILE="$SCRIPT_DIR/commit_message_prompt.txt"
if [[ -f "$COMMIT_MSG_FILE" ]]; then
    cp "$COMMIT_MSG_FILE" "$SCRIPT_DIR/git_export_staged/"
fi

# Ask for Task ID to append to the AI message
read -r -p "🔖 Enter related Project Task ID (or press Enter to skip): " TASK_ID
if [[ -z "$TASK_ID" ]]; then
  TASK_ID="Please omit the ID-XY from the template this time and just use \"[Categories] Affected files or feature: more details of the change.\""
fi

# Concatenate everything into one single file. 
ALL_IN_ONE_DIR="$SCRIPT_DIR/git_export_staged/all_in_one"
ALL_IN_ONE_AI_MESSAGE_FILE="$ALL_IN_ONE_DIR/ai_message.txt"
mkdir -p "$ALL_IN_ONE_DIR"
rm -f "$ALL_IN_ONE_AI_MESSAGE_FILE"
{
    echo "===== 📝 COMMIT MESSAGE PROMPT ====="
    if [[ -f "$COMMIT_MSG_FILE" ]]; then
        cat "$COMMIT_MSG_FILE"
    else
        echo "(no commit_message_prompt.txt found)"
    fi
    echo ""
    echo "===== 🔍 STAGED DIFF ====="
    cat "$DIFF_FILE"
    echo ""
    echo "===== 📁 STAGED FILE CONTENTS ====="
    for file in $FILES; do
        if [[ -f "$file" ]]; then
            echo "--- $(basename "$file") ---"
            cat "$file"
            echo ""
        fi
    done
    echo ""
    echo "$TASK_ID"
} > "$ALL_IN_ONE_AI_MESSAGE_FILE"


# --- Send to Azure OpenAI ---
echo "🚀 Sending message to Azure OpenAI..."

if command -v jq >/dev/null 2>&1; then
  RESPONSE=$(curl -s -X POST "${API_BASE}openai/deployments/${DEPLOYMENT}/chat/completions?api-version=${API_VERSION}" \
    -H "Content-Type: application/json" \
    -H "api-key: ${API_KEY}" \
    -d "$(jq -n \
      --arg content "$(cat "$ALL_IN_ONE_AI_MESSAGE_FILE")" \
      '{messages: [{role: "system", content: "You are a helpful assistant."}, {role: "user", content: $content}], temperature: 0.7, max_tokens: 16384}')")

    # echo "🧠 Azure OpenAI Response:"
    # echo "$RESPONSE" | jq .

    # Extract commit command from assistant's reply.
    COMMIT_LINE=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' | sed -n 's/.*\(git commit -m .*"\).*/\1/p')

  if [[ -n "$COMMIT_LINE" ]]; then
    echo ""
    echo "✅ AI suggested commit command:"
    echo "$COMMIT_LINE"

    # Ask user to confirm or edit
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
      else
        echo "ℹ️ Commit not executed. You can run it manually:"
        echo "$FINAL_COMMIT"
      fi
    fi

  else
    echo "⚠️ Could not extract commit command from AI response."
  fi

else
  echo "❌ 'jq' is required to format the JSON body. Please install it and try again."
fi



# --- Git update check ---
bash "$ROOT_DIR/check_for_updates.sh"

exit 0