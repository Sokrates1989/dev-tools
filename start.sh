#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# --- Argument-based quick start (must be FIRST!) ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|-c|--cm)
            bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
            exit 0
            ;;
        --merge|-m|--me)
            bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
            exit 0
            ;;
        --log|-l|--lg)
            bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
            exit 0
            ;;
        --readme|-r|--rd)
            bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
            exit 0
            ;;
        --reset|-x|--re)
            bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
            exit 0
            ;;
        --amend|-a|--am)
            bash "$ROOT_DIR/main_features/amend/git_amend.sh"
            exit 0
            ;;
        --remove-gitignored|-i|--rg)
            bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
            exit 0
            ;;
        --branch-cleanup|-b|--bc)
            bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
            exit 0
            ;;
        --sync-branches|-s|--sb)
            bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
            exit 0
            ;;
        --track-remote|-t|--tr)
            bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
            exit 0
            ;;
        --create-branch|-n|--nb|--cnb)
            bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
            exit 0
            ;;
        --stash|--st)
            bash "$ROOT_DIR/main_features/stash/stash_manager.sh"
            exit 0
            ;;
        --repair|--fix|-f)
            bash "$ROOT_DIR/main_features/git-repair/git_repair.sh"
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
            echo "  --commit | -c | --cm   → Commit Message Helper"
            echo "  --merge  | -m | --me   → Merge commit assistant"
            echo "  --readme | -r | --rd   → Show README creation instructions"
            echo "  --stash  | -st | --st  → Git Stash Manager"
            echo ""
            echo "🔄 Branch Management:"
            echo "  --branch-cleanup | -b | --bc → Clean Up Merged Branches"
            echo "  --sync-branches | -s | --sb → Sync All Branches"
            echo "  --track-remote | -t | --tr → Track Remote Branches"
            echo "  --create-branch | -n | --nb | --cnb → Create New Branch"
            echo ""
            echo "🔍 Debug & Investigation:"
            echo "  --log    | -l | --lg   → Git log explorer"
            echo "  --amend  | -a | --am   → Amend Last Commit"
            echo ""
            echo "🧹 Cleanup & Reset:"
            echo "  --remove-gitignored | -i | --rg → Remove Gitignored Files"
            echo "  --reset  | -x | --re   → Reset Local Git Changes"
            echo ""
            echo "🔧 Repair & Maintenance:"
            echo "  --repair | --fix | -f  → Repair Corrupted Git Repository"
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
echo "🔄 Core Operations (1-4):"
echo "1) 📤 Commit Message Helper             [--commit | -c | --cm]"
echo "2) 🔀 Merge commit assistant            [--merge  | -m | --me]"
echo "3) 📘 Show README creation instructions [--readme | -r | --rd]"
echo "4) 📦 Git Stash Manager                 [--stash | -st | --st]"
echo ""
echo "🔄 Branch Management (5-8):"
echo "5) 🌿 Clean Up Merged Branches          [--branch-cleanup | -b | --bc]"
echo "6) 🔄 Sync All Branches                 [--sync-branches | -s | --sb]"
echo "7) 📡 Track Remote Branches             [--track-remote | -t | --tr]"
echo "8) 🌱 Create New Branch                  [--create-branch | -n | --nb | --cnb]"
echo ""
echo "🔍 Debug & Investigation (9-10):"
echo "9) 📜 Git log explorer                  [--log    | -l | --lg]"
echo "10) 🔄 Amend Last Commit                 [--amend  | -a | --am]"
echo ""
echo "🧹 Cleanup & Reset (11-12):"
echo "11) 🧹 Remove Gitignored Files           [--remove-gitignored | -i | --rg]"
echo "12) 🧹 Reset Local Git Changes          [--reset  | -x | --re]"
echo ""
echo "🔧 Repair & Maintenance (13):"
echo "13) 🔧 Repair Corrupted Git Repository  [--repair | --fix | -f]"
echo ""
if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
    echo "u) 🔄 Update Dev Tools now            [--update | -u]"
fi
echo "q) ❌ Exit"
echo ""

# --- Git update check ---
bash "$ROOT_DIR/global_functions/check_for_updates.sh"

read -p "Enter your choice [1-13, u, q, or option name]: " choice

# Convert choice to lowercase for easier matching
choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice_lower" in
  1|"commit"|"--commit"|"-c"|"c"|"cm")
    bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
    ;;
  2|"merge"|"--merge"|"-m"|"m"|"me")
    bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
    ;;
  3|"readme"|"--readme"|"-r"|"r"|"rd")
    bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
    ;;
  4|"stash"|"--stash"|"-st"|"st"|"st"|"--st")
    bash "$ROOT_DIR/main_features/stash/stash_manager.sh"
    ;;
  5|"branch-cleanup"|"--branch-cleanup"|"-b"|"b"|"bc"|"--bc")
    bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
    ;;
  6|"sync-branches"|"--sync-branches"|"-s"|"s"|"sb"|"--sb")
    bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
    ;;
  7|"track-remote"|"--track-remote"|"-t"|"t"|"tr"|"--tr")
    bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
    ;;
  8|"create-branch"|"--create-branch"|"-n"|"n"|"nb"|"--nb"|"cnb"|"--cnb")
    bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
    ;;
  9|"log"|"--log"|"-l"|"l"|"lg"|"--lg")
    bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
    ;;
  10|"amend"|"--amend"|"-a"|"a" |"am"|"--am")
    bash "$ROOT_DIR/main_features/amend/git_amend.sh"
    ;;
  11|"remove-gitignored"|"--remove-gitignored"|"-i"|"i"|"rg"|"--rg")
    bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
    ;;
  12|"reset"|"--reset"|"-x"|"x"|"revert"|"--revert"|"re"|"--re")
    bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
    ;;
  13|"repair"|"--repair"|"fix"|"--fix"|"-f"|"f")
    bash "$ROOT_DIR/main_features/git-repair/git_repair.sh"
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
    echo "Valid options: 1-13, u, q, or option names like 'commit', '--merge', '-l', 'stash', 'repair', etc."
    ;;
esac
