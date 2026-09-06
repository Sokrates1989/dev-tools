#!/bin/bash

SCRIPT_PATH="$(realpath "$0")"
ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ORIGINAL_ARGS=("$@")

# --- Startup update guard ---
# Every normal launcher invocation checks once before dispatch. An accepted
# update replays the exact original argument array through the updated script.
# shellcheck source=global_functions/update_manager.sh
source "$ROOT_DIR/global_functions/update_manager.sh"
initialize_dev_tools_update_messages "$ROOT_DIR"

SKIP_UPDATE_GUARD="false"
if [ "${DEV_TOOLS_UPDATE_REPLAYED:-}" = "1" ]; then
    SKIP_UPDATE_GUARD="true"
    unset DEV_TOOLS_UPDATE_REPLAYED
fi

IS_EXPLICIT_UPDATE="false"
case "${1:-}" in
    --update|-u) IS_EXPLICIT_UPDATE="true" ;;
esac

if [ "$SKIP_UPDATE_GUARD" = "false" ] && [ "$IS_EXPLICIT_UPDATE" = "false" ]; then
    invoke_dev_tools_startup_update_check "$ROOT_DIR"
    if [ "$DEV_TOOLS_UPDATE_PERFORMED" = "true" ]; then
        DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh" "${ORIGINAL_ARGS[@]}"
    fi
fi

# Prints the complete top-level command reference.
show_dev_tools_help() {
    printf '%s\n%s\n\n' \
        "$(get_dev_tools_update_message launcher.help.usage)" \
        "$(get_dev_tools_update_message launcher.help.description)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.core_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.commit)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cc)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.merge)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.readme)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.stash)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.branch_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.branch_cleanup)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.sync_branches)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.track_remote)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.create_branch)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.debug_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.log)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.amend)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cleanup_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.remove_gitignored)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.reset)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.maintenance_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.repair)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.update)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.security_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.password)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.deploy_key)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.configuration_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.settings)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.cls)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.general_heading)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.help)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.examples_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.example_menu)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.example_cls)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cls_note)"
}

# --- Argument-based quick start ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|-c|--cm)
            bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
            exit 0
            ;;
        --cc|-cc)
            bash "$ROOT_DIR/main_features/commit/create_commit_with_external_ai.sh"
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
        --password|--pw)
            bash "$ROOT_DIR/main_features/password/generate_safe_passwords.sh" "${@:2}"
            exit 0
            ;;
        --deploy-key|--dk)
            bash "$ROOT_DIR/main_features/deploy-key/deploy_key_manager.sh" "${@:2}"
            exit 0
            ;;
        --cls)
            bash "$ROOT_DIR/main_features/cls/cls_installer.sh" "${@:2}"
            exit $?
            ;;
        --settings|--cfg|-cfg|--config)
            bash "$ROOT_DIR/main_features/settings/edit_settings.sh"
            exit 0
            ;;
        --help|-h|help)
            show_dev_tools_help
            exit 0
            ;;
        --update|-u)
            if invoke_dev_tools_update "$ROOT_DIR"; then
                DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh"
            fi
            exit 1
            ;;

        *)
            echo "❌ Unknown argument: $1"
            echo ""
            show_dev_tools_help
            exit 1
            ;;
    esac
fi



# --- Interactive Menu ---
echo ""
echo "🛠️  Dev Tools Launcher"
echo "======================"
echo "Choose a tool to run (you can also use these flags directly):"
echo ""
echo "🔄 Core Operations (1-4):"
echo "1) 📤 Commit Message Helper             [--commit | -c | --cm]"
echo "cc) 🤖 Commit style instructions for external AI [--cc | -cc]"
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
printf '%s\n' "$(get_dev_tools_update_message launcher.security_heading)"
echo "14) Generate Safe Passwords              [--password | --pw]"
printf '%s\n' "$(get_dev_tools_update_message launcher.deploy_key_menu)"
echo ""
printf '⚙️  %s\n' "$(get_dev_tools_update_message launcher.configuration_heading)"
printf '%s\n' "$(get_dev_tools_update_message launcher.settings_menu)"
printf '%s\n' "$(get_dev_tools_update_message launcher.cls_menu)"
echo ""
if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
    echo "u) 🔄 Update Dev Tools now            [--update | -u]"
fi
echo "q) ❌ Exit"
echo ""

read -r -p "$(get_dev_tools_update_message launcher.choice_prompt) " choice

# Convert choice to lowercase for easier matching
choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice_lower" in
  1|"commit"|"--commit"|"-c"|"c"|"cm")
    bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
    ;;
  "cc"|"--cc"|"-cc"|"commit-external"|"external-commit")
    bash "$ROOT_DIR/main_features/commit/create_commit_with_external_ai.sh"
    ;;
  2|"merge"|"--merge"|"-m"|"m"|"me")
    bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
    ;;
  3|"readme"|"--readme"|"-r"|"r"|"rd")
    bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
    ;;
  4|"stash"|"--stash"|"-st"|"st"|"--st")
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
  14|"password"|"--password"|"pw"|"--pw")
    bash "$ROOT_DIR/main_features/password/generate_safe_passwords.sh"
    ;;
  15|"deploy-key"|"--deploy-key"|"dk"|"--dk")
    bash "$ROOT_DIR/main_features/deploy-key/deploy_key_manager.sh"
    ;;
  16|"settings"|"--settings"|"cfg"|"--cfg"|"-cfg"|"config"|"--config")
    bash "$ROOT_DIR/main_features/settings/edit_settings.sh"
    ;;
  17|"cls"|"--cls")
    bash "$ROOT_DIR/main_features/cls/cls_installer.sh"
    ;;
  "u"|"update"|"--update"|"-u")
    if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
      if invoke_dev_tools_update "$ROOT_DIR"; then
        DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh"
      fi
    else
      printf '%s\n' "$(get_dev_tools_update_message updates.current)"
    fi
    ;;
  "q"|"quit"|"exit")
    echo "👋 Bye!"
    exit 0
    ;;
  *)
    echo "❌ Invalid choice: $choice"
    printf '%s\n' "$(get_dev_tools_update_message launcher.invalid_choices)"
    ;;
esac
