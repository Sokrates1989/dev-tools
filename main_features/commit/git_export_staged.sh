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

# --- Sync check before commit ---
echo "🔍 Checking if branch is in sync with remote..."
if ! bash "$ROOT_DIR/global_functions/sync_check.sh"; then
    echo "❌ Sync check failed. Please resolve sync issues before committing."
    exit 1
fi

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

# Load utilities
source "$SCRIPT_DIR/utils/version_utils.sh"
source "$SCRIPT_DIR/utils/file_content_utils.sh"

# Initialize variables for replacements
JIRA_ID=""
IMAGE_VERSION=""
VERSION_FILES_STAGED=""

# Detect CI/CD setup
HAS_CICD=$(detect_cicd_setup)

if [[ "$HAS_CICD" == "true" ]]; then
  echo ""
  echo " CI/CD configuration detected in this repository"
  
  # Get current version info
  get_current_version_info
  env_version="$VERSION_ENV"
  ci_env_version="$VERSION_CIENV"
  base_version="$VERSION_BASE"
  version_source="$VERSION_SOURCE"
  env_var_name="$VARIABLE_NAME_ENV"
  ci_env_var_name="$VARIABLE_NAME_CIENV"
  
  # Check if .ci.env is staged for commit
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
  if [[ -n "$repo_root" ]]; then
    ci_env_staged=$(git diff --cached --name-only | grep -x ".ci.env")
    
    if [[ -n "$ci_env_staged" ]]; then
      echo ""
      echo "NOTE: .ci.env is staged and will be committed"
      
      # Get old and new version from git diff using detected variable name
      old_version=""
      new_version=""
      if [[ -n "$ci_env_var_name" ]]; then
        old_version=$(git diff --cached "$repo_root/.ci.env" 2>/dev/null | grep "^-${ci_env_var_name}=" | sed "s/^-${ci_env_var_name}=//" | tr -d ' ')
        new_version=$(git diff --cached "$repo_root/.ci.env" 2>/dev/null | grep "^+${ci_env_var_name}=" | sed "s/^+${ci_env_var_name}=//" | tr -d ' ')
      fi
      
      if [[ -n "$old_version" && -n "$new_version" && "$old_version" != "$new_version" ]]; then
        echo "  Version change: $old_version -> $new_version"
      elif [[ -n "$new_version" ]]; then
        echo "  Current staged version: $new_version"
      fi
    fi
  fi
  
  # Display current versions
  echo ""
  echo "Current IMAGE_VERSION:"
  if [[ -n "$env_var_name" && -n "$env_version" ]]; then
    echo "  - .env    : ${env_var_name}=${env_version}"
  else
    echo "  - .env    : <not set>"
  fi
  
  if [[ -n "$ci_env_var_name" && -n "$ci_env_version" ]]; then
    echo "  - .ci.env : ${ci_env_var_name}=${ci_env_version}"
  else
    echo "  - .ci.env : <not set>"
  fi
  
  if [[ -n "$base_version" ]]; then
    echo "  Base version: $base_version (from $version_source)"
  else
    echo "  No version found - will default to 0.0.0"
  fi
  
  echo ""
  read -r -p " Do you want to update IMAGE_VERSION? [y/N]: " update_version
  if [[ "$update_version" =~ ^[Yy]$ ]]; then
    NEW_VERSION=$(prompt_version_update "$base_version")
    
    if [[ -n "$NEW_VERSION" ]]; then
      # Update version in files and stage them
      VERSION_FILES_STAGED=$(update_repo_version "$NEW_VERSION")
      if [[ $? -eq 0 ]]; then
        IMAGE_VERSION="$NEW_VERSION"
        echo ""
        echo "✅ Version updated to: $IMAGE_VERSION"
      fi
    fi
  fi
fi

# Ask for JIRA Task ID (single-step input)
echo ""
read -r -p "🎫 Enter JIRA task ID (e.g. FA-123, or press Enter for none): " jira_input
if [[ -z "$jira_input" || "$jira_input" =~ ^[Nn]$ ]]; then
  JIRA_ID=""
else
  JIRA_ID="$jira_input"
fi

# Create file to pass variables to handle_export_api
VARS_FILE="$SCRIPT_DIR/git_export_staged/.commit_vars"
{
  echo "JIRA_ID=$JIRA_ID"
  echo "IMAGE_VERSION=$IMAGE_VERSION"
  echo "VERSION_FILES_STAGED=$VERSION_FILES_STAGED"
} > "$VARS_FILE"

# Set TASK_ID for backwards compatibility
TASK_ID="JIRA_ID_PLACEHOLDER"

# Concatenate everything into one single file with smart content handling
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
    
    # Generate files summary first
    echo "===== 📋 FILES SUMMARY ====="
    generate_files_summary "$FILES"
    echo ""
    
    echo "===== 🔍 STAGED DIFF ====="
    get_smart_diff_content "$DIFF_FILE"
    echo ""
    
    echo "===== 📁 STAGED FILE CONTENTS ====="
    echo "(Binary and large files show metadata only)"
    echo ""
    for file in $FILES; do
        echo "--- $(basename "$file") ---"
        get_smart_file_content "$file"
        echo ""
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

