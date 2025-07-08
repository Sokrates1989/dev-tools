#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# --- Argument-based quick start (must be FIRST!) ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|-c)
            bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
            exit 0
            ;;
        --merge|-m)
            bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
            exit 0
            ;;
        --log|-l)
            bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
            exit 0
            ;;
        --readme|-r)
            bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
            exit 0
            ;;
        --reset|-x)
            bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
            exit 0
            ;;
        --amend|-a)
            bash "$ROOT_DIR/main_features/amend/git_amend.sh"
            exit 0
            ;;
        --remove-gitignored|-i)
            bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
            exit 0
            ;;
        --branch-cleanup|-b)
            bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
            exit 0
            ;;
        --sync-branches|-s)
            bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
            exit 0
            ;;
        --track-remote|-t)
            bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
            exit 0
            ;;
        --create-branch|-n)
            bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
            exit 0
            ;;
        --update|-u)
            # Auto update and restart script.
            bash "$ROOT_DIR/global_functions/perform_auto_update.sh"
            exec bash "$ROOT_DIR/start.sh"
            ;;

        *)
            echo "❌ Unknown argument: $1"
            echo ""
            echo "Usage:"
            echo ""
            echo "🔄 Core Operations:"
            echo "  --commit | -c   → Commit Message Helper"
            echo "  --merge  | -m   → Merge commit assistant"
            echo "  --readme | -r   → Show README creation instructions"
            echo ""
            echo "🔄 Branch Management:"
            echo "  --branch-cleanup | -b → Clean Up Merged Branches"
            echo "  --sync-branches | -s → Sync All Branches"
            echo "  --track-remote | -t → Track Remote Branches"
            echo ""
            echo "🔍 Debug & Investigation:"
            echo "  --log    | -l   → Git log explorer"
            echo "  --amend  | -a   → Amend Last Commit"
            echo ""
            echo "🧹 Cleanup & Reset:"
            echo "  --remove-gitignored | -i → Remove Gitignored Files"
            echo "  --reset  | -x   → Reset Local Git Changes"
            exit 1
            ;;
    esac
fi



# --- Git update check ---´
bash "$ROOT_DIR/global_functions/check_for_updates.sh"
DEVTOOLS_UPDATE_AVAILABLE=$(bash "$ROOT_DIR/global_functions/check_for_updates_flag.sh")


# --- Interactive Menu ---
echo ""
echo "🛠️  Dev Tools Launcher"
echo "======================"
echo "Choose a tool to run (you can also use these flags directly):"
echo ""
echo "🔄 Core Operations (1-3):"
echo "1) 📤 Commit Message Helper             [--commit | -c]"
echo "2) 🔀 Merge commit assistant            [--merge  | -m]"
echo "3) 📘 Show README creation instructions [--readme | -r]"
echo ""
echo "🔄 Branch Management (4-6):"
echo "4) 🌿 Clean Up Merged Branches          [--branch-cleanup | -b]"
echo "5) 🔄 Sync All Branches                 [--sync-branches | -s]"
echo "6) 📡 Track Remote Branches             [--track-remote | -t]"
echo "7) 🌱 Create New Branch                  [--create-branch | -n]"
echo ""
echo "🔍 Debug & Investigation (8-9):"
echo "8) 📜 Git log explorer                  [--log    | -l]"
echo "9) 🔄 Amend Last Commit                 [--amend  | -a]"
echo ""
echo "�� Cleanup & Reset (10-11):"
echo "10) 🧹 Remove Gitignored Files           [--remove-gitignored | -i]"
echo "11) 🧹 Reset Local Git Changes          [--reset  | -x]"
echo ""
if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
    echo "u) 🔄 Update Dev Tools now            [--update | -u]"
fi
echo "q) ❌ Exit"
echo ""

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

read -p "Enter your choice [1-11, u, q, or option name]: " choice

# Convert choice to lowercase for easier matching
choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice_lower" in
  1|"commit"|"--commit"|"-c"|"c")
    bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
    ;;
  2|"merge"|"--merge"|"-m"|"m")
    bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
    ;;
  3|"readme"|"--readme"|"-r"|"r")
    bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
    ;;
  4|"branch-cleanup"|"--branch-cleanup"|"-b"|"b"|"cleanup"|"--cleanup")
    bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
    ;;
  5|"sync-branches"|"--sync-branches"|"-s"|"s"|"sync"|"--sync")
    bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
    ;;
  6|"track-remote"|"--track-remote"|"-t"|"t"|"track"|"--track")
    bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
    ;;
  7|"create-branch"|"--create-branch"|"-n"|"n"|"new-branch"|"newbranch")
    bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
    ;;
  8|"log"|"--log"|"-l"|"l")
    bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
    ;;
  9|"amend"|"--amend"|"-a"|"a")
    bash "$ROOT_DIR/main_features/amend/git_amend.sh"
    ;;
  10|"remove-gitignored"|"--remove-gitignored"|"-i"|"i"|"gitignored"|"--gitignored")
    bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
    ;;
  11|"reset"|"--reset"|"-x"|"x"|"revert"|"--revert")
    bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
    ;;
  "u"|"update"|"--update"|"-u")
    if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
      # Auto update and restart script.
      bash "$ROOT_DIR/global_functions/perform_auto_update.sh"
      exec bash "$ROOT_DIR/start.sh"
    else
      echo "✅ Already up to date with the latest version of Dev Tools."
    fi
    ;;
  "q"|"quit"|"exit")
    echo "👋 Bye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice: $choice"
    echo "Valid options: 1-11, u, q, or option names like 'commit', '--merge', '-l', etc."
    ;;
esac
