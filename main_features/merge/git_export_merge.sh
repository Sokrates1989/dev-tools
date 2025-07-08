#!/bin/bash

# --- Resolve paths ---
SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MERGE_DIR="$SCRIPT_DIR/git_export_merge"
ALL_IN_ONE_DIR="$MERGE_DIR/all_in_one"
AI_MESSAGE_FILE="$ALL_IN_ONE_DIR/ai_message.txt"
MERGE_MSG_FILE="$SCRIPT_DIR/merge_message_prompt.txt"
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

# --- Sync check before merge ---
echo "🔍 Checking if branch is in sync with remote..."
if ! bash "$ROOT_DIR/global_functions/sync_check.sh"; then
    echo "❌ Sync check failed. Please resolve sync issues before merging."
    exit 1
fi

# Detect uncommitted files.
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️ You have uncommitted changes in your working directory."
  echo "💡 Please commit or stash your changes before proceeding with the merge."
  exit 1
fi

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
echo "Select a branch to merge:"
select TARGET_BRANCH in $AVAILABLE_BRANCHES; do
  if [[ -n "$TARGET_BRANCH" ]]; then
    break
  fi
  echo "❌ Invalid selection. Try again."
done


# 1. Detect if there's anything at all to merge
if git diff --quiet "$CURRENT_BRANCH".."$TARGET_BRANCH"; then
  echo "✅ '$TARGET_BRANCH' is already fully merged into '$CURRENT_BRANCH'. No changes to merge."
  read -rp "🔄 Do you want to switch to '$TARGET_BRANCH' now? [y/N]: " SWITCH_AFTER_MERGE
  if [[ "$SWITCH_AFTER_MERGE" =~ ^[Yy]$ ]]; then
    echo "🔁 Switching to '$TARGET_BRANCH'..."
    git checkout "$TARGET_BRANCH"
    exec bash "$SCRIPT_PATH"
  else
    echo "ℹ️ Staying on '$CURRENT_BRANCH'."
  fi
  exit 0
fi

# 2. Use dry-run merge to detect conflicts
echo ""
echo "🧪 Checking if there are actual differences to merge..."
MERGE_CHECK_OUTPUT=$(git merge --no-commit --no-ff "$TARGET_BRANCH" 2>&1)
MERGE_EXIT_CODE=$?

# --- Handle merge result ---
if echo "$MERGE_CHECK_OUTPUT" | grep -q "Already up to date."; then
  echo "✅ Branch '$TARGET_BRANCH' is already fully merged into '$CURRENT_BRANCH'. No merge commit needed."
  git merge --abort >/dev/null 2>&1
  read -rp "🔄 Do you want to switch to '$TARGET_BRANCH' now? [y/N]: " SWITCH_AFTER_MERGE
  if [[ "$SWITCH_AFTER_MERGE" =~ ^[Yy]$ ]]; then
    echo "🔁 Switching to '$TARGET_BRANCH'..."
    git checkout "$TARGET_BRANCH"
    exec bash "$SCRIPT_PATH"
  else
    echo "ℹ️ Staying on '$CURRENT_BRANCH'."
  fi
  exit 0


elif echo "$MERGE_CHECK_OUTPUT" | grep -q "Automatic merge went well; stopped before committing as requested"; then
  echo "✅ Automatic merge is possible. Proceeding to generate commit message..."
  # continue with AI message logic

elif echo "$MERGE_CHECK_OUTPUT" | grep -q "Automatic merge failed; fix conflicts"; then
  echo ""
  echo "🧨 Merge conflict detected!"

  # Show conflict summary
  echo "$MERGE_CHECK_OUTPUT" | grep "CONFLICT" | while read -r line; do
    echo "⚠️ $line"
  done

  echo ""
  echo "🔍 Showing detailed conflicts (via 'git diff'):"
  echo ""
  git diff

  # --- Suggest better direction if user is on main/dev/release etc. ---

  # Are both mainline branches?
  SHOULD_SWITCH_DIRECTION=false
  MAINLINE_BRANCHES_REGEX="^(main|release|production|dev)$"
  if [[ "$CURRENT_BRANCH" =~ $MAINLINE_BRANCHES_REGEX && "$TARGET_BRANCH" =~ $MAINLINE_BRANCHES_REGEX ]]; then

    # Check if the direction is ok by appling some idea of hieracrchy to the branches (dev is inferior to main e.g.).
    LESSER_MAINLINE_BRANCHES_REGEX="^(dev)$"
    if [[ "$TARGET_BRANCH" =~ $LESSER_MAINLINE_BRANCHES_REGEX && ! "$CURRENT_BRANCH" =~ $LESSER_MAINLINE_BRANCHES_REGEX ]]; then
      echo "⚠️ You're trying to merge a lesser mainline branch ('$TARGET_BRANCH') into a higher one ('$CURRENT_BRANCH')."
      SHOULD_SWITCH_DIRECTION=true
    fi
  fi


  # If just one is amainline branch -> check if the direction is correct.
  if [[ "$CURRENT_BRANCH" =~ $MAINLINE_BRANCHES_REGEX && ! "$TARGET_BRANCH" =~ $MAINLINE_BRANCHES_REGEX ]]; then
    echo ""
    echo "⚠️  You're trying to merge '$TARGET_BRANCH' into '$CURRENT_BRANCH' (a mainline branch)."
    SHOULD_SWITCH_DIRECTION=true
  fi


  # Help user fix direction.
  if [[ "$SHOULD_SWITCH_DIRECTION" == true ]]; then
    echo "💡 Consider resolving the conflict in '$TARGET_BRANCH' instead:"
    echo ""
    echo "   → Checkout to '$TARGET_BRANCH'"
    echo "   → Run: dev-tools -m"
    echo "   → Resolve conflicts and commit"
    echo "   → Then redo the merge: dev-tools -m"
    echo ""

    read -rp "👉 Switch to '$TARGET_BRANCH' now and merge '$CURRENT_BRANCH' into it instead? [y/N]: " SWITCH_INSTEAD
    if [[ "$SWITCH_INSTEAD" =~ ^[Yy]$ ]]; then
      git merge --abort >/dev/null 2>&1
      echo "🧼 Merge aborted. No changes were applied."
      echo "🔄 Switching to '$TARGET_BRANCH'..."
      git checkout "$TARGET_BRANCH"
      echo "✅ Switching to '$TARGET_BRANCH'"
      git status
      echo "please run merge assistant again now"
      exit 0
    fi
  fi



  echo ""
  echo "🧭 To resolve this merge, you have 2 options:"
  echo "---------------------------------------------"
  echo "y)  Solve it manually:"
  echo "    a) Edit the conflicting files shown above."
  echo "    b) After resolving: git add <file>"
  echo "    c) Finish: git commit"
  echo "    d) Optionally rerun the merge assistant:"
  echo "       → dev-tools -m"
  echo ""
  echo "n) Abort the merge if you want to discard:"
  echo "    Run: git merge --abort"
  echo ""

  # Prompt user: fix now or abort
  read -rp "🧩 Do you want to resolve these conflicts now? [y/N]: " FIX_CONFLICTS

  if [[ "$FIX_CONFLICTS" =~ ^[Yy]$ ]]; then
    echo "🛠️  You're now in a merge state. Resolve the conflicts as described above."
    echo "👉 Once done, run: git add <files> && dev-tools -c"
    echo "💡 You can run 'git status' anytime for help."
    exit 0
  else
    git merge --abort >/dev/null 2>&1
    echo "🧼 Merge aborted. No changes were applied."
    exit 1
  fi

else
  echo "⚠️ Unexpected merge output:"
  echo "$MERGE_CHECK_OUTPUT"
  git merge --abort >/dev/null 2>&1
  echo "merge aborted"
  exit 1
fi


# Clean up the test merge state before proceeding to real merge
git merge --abort >/dev/null 2>&1


# --- Write AI message file ---
{
  echo "===== 🔀 MERGE COMMIT MESSAGE PROMPT ====="
  echo "You're about to merge branch '$TARGET_BRANCH' into '$CURRENT_BRANCH'."
  echo ""
  if [[ -f "$MERGE_MSG_FILE" ]]; then
      cat "$MERGE_MSG_FILE"
  else
      echo "Generate a concise and meaningful merge commit message summarizing the key changes adhering to this basic template strictly:"
      echo "[MERGE | $TARGET_BRANCH -> $CURRENT_BRANCH] Merged feature: short summary of the change."
      echo "⚠️ Respond ONLY with the final **message line** (no code block, no git command, no commentary)"
  fi
  echo ""
  echo "===== 🧠 GIT LOG (commits from $TARGET_BRANCH not in $CURRENT_BRANCH) ====="
  git log --oneline "$CURRENT_BRANCH".."$TARGET_BRANCH"
  echo ""
  echo "===== 🔍 DIFF ($TARGET_BRANCH vs $CURRENT_BRANCH) ====="
  git diff "$CURRENT_BRANCH".."$TARGET_BRANCH"
} > "$AI_MESSAGE_FILE"

# --- Decide execution based on AI_MODE ---
if [[ "$AI_MODE" == "api" ]]; then
  bash "$SCRIPT_DIR/handle_export_merge_api.sh" "$AI_MESSAGE_FILE" "$TARGET_BRANCH"
else
  bash "$SCRIPT_DIR/handle_export_merge_manual.sh" "$AI_MESSAGE_FILE" "$TARGET_BRANCH"
fi

# --- Final update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"


