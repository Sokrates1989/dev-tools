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

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEST_DIR="$SCRIPT_DIR/git_export_staged/changed_files"
DIFF_FILE="$SCRIPT_DIR/git_export_staged/last_staged_commit_diff.txt"
ALL_IN_ONE_DIR="$SCRIPT_DIR/git_export_staged/all_in_one"
ALL_IN_ONE_AI_MESSAGE_FILE="$ALL_IN_ONE_DIR/ai_message.txt"
COMMIT_MSG_FILE="$SCRIPT_DIR/commit_message_prompt.txt"

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
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

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


# --- Dispatch by AI_MODE ---
if [[ "$AI_MODE" == "api" ]]; then
  bash "$SCRIPT_DIR/handle_export_api.sh"
elif [[ "$AI_MODE" == "manual" ]]; then
  bash "$SCRIPT_DIR/handle_export_manual.sh"
else
  echo "❌ Unknown AI_MODE in .env: $AI_MODE"
  exit 1
fi

