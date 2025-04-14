#!/bin/bash

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MERGE_DIR="$SCRIPT_DIR/git_export_merge"
ALL_IN_ONE_DIR="$MERGE_DIR/all_in_one"
AI_MESSAGE_FILE="$ALL_IN_ONE_DIR/ai_message.txt"
mkdir -p "$ALL_IN_ONE_DIR"

# --- Load environment ---
ENV_FILE="$ROOT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo "❌ .env file not found at $ENV_FILE"
  exit 1
fi

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

# --- Detect current branch ---
CURRENT_BRANCH=$(git symbolic-ref --short HEAD)
if [[ -z "$CURRENT_BRANCH" ]]; then
  echo "❌ Could not detect current Git branch."
  exit 1
fi

echo ""
echo "🔀 Merge Commit Message Assistant"
echo "=================================="
echo "📍 You are currently on branch: $CURRENT_BRANCH"
echo ""

# --- List other local branches ---
AVAILABLE_BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads | grep -v "^$CURRENT_BRANCH$")
if [[ -z "$AVAILABLE_BRANCHES" ]]; then
  echo "⚠️  No other branches available to merge."
  exit 0
fi

# --- Prompt for target branch ---
echo "Select a branch to merge from:"
select TARGET_BRANCH in $AVAILABLE_BRANCHES; do
  if [[ -n "$TARGET_BRANCH" ]]; then
    break
  fi
  echo "❌ Invalid selection. Try again."
done

# --- Write AI message file ---
{
  echo "===== 🔀 MERGE COMMIT MESSAGE PROMPT ====="
  echo "You're about to merge branch '$TARGET_BRANCH' into '$CURRENT_BRANCH'."
  echo "Generate a concise and meaningful merge commit message summarizing the key changes."
  echo ""
  echo "===== 🧠 GIT LOG (commits from $TARGET_BRANCH not in $CURRENT_BRANCH) ====="
  git log --oneline "$CURRENT_BRANCH".."$TARGET_BRANCH"
  echo ""
  echo "===== 🔍 DIFF ($TARGET_BRANCH vs $CURRENT_BRANCH) ====="
  git diff "$CURRENT_BRANCH".."$TARGET_BRANCH"
} > "$AI_MESSAGE_FILE"

# --- Decide execution based on AI_MODE ---
if [[ "$AI_MODE" == "api" ]]; then
  bash "$SCRIPT_DIR/handle_export_merge_api.sh" "$AI_MESSAGE_FILE"
else
  bash "$SCRIPT_DIR/handle_export_merge_manual.sh" "$AI_MESSAGE_FILE"
fi

# --- Final update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"
