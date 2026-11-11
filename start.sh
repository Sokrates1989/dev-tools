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
    --update|--u|-update|-u) IS_EXPLICIT_UPDATE="true" ;;
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
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.amend)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.stash)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.branch_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.create_branch)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.track_remote)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.sync_branches)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.branch_cleanup)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cleanup_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.log)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.remove_gitignored)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.reset)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.repair)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.security_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.password)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.deploy_key)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.github_notifications)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.configuration_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.settings)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cls)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.udc)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.readme)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.general_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.update)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.help)"
    printf '%s\n\n' "$(get_dev_tools_update_message launcher.help.quit)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.examples_heading)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.example_menu)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.example_shortcut)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.example_feature_help)"
    printf '%s\n' "$(get_dev_tools_update_message launcher.help.cls_note)"
}

# print_dev_tools_menu_line
#
# Prints one localized heading or an aligned number;mnemonic;label;flags row.
#
# Arguments:
#   $1 - key: locale-catalog key to render.
print_dev_tools_menu_line() {
    local key="$1"
    local message number mnemonic label flags selector description

    message=$(get_dev_tools_update_message "$key") || return 1
    IFS=';' read -r number mnemonic label flags <<< "$message"
    if [[ "$number" =~ ^[0-9]+$ && -n "$mnemonic" && -n "$label" && -n "$flags" ]]; then
        printf -v selector '%2s | %s)' "$number" "$mnemonic"
        description="${selector} ${label}"
        printf '%-62s[%s]\n' "$description" "$flags"
    else
        printf '%s\n' "$message"
    fi
}

# show_dev_tools_menu
#
# Prints every Bash launcher action with its numeric and mnemonic selectors.
show_dev_tools_menu() {
    local key
    local menu_keys=(
        launcher.menu.title
        launcher.menu.divider
        launcher.menu.description
        ""
        launcher.menu.git_heading
        launcher.menu.commit
        launcher.menu.commit_external
        launcher.menu.merge
        launcher.menu.amend
        launcher.menu.stash
        ""
        launcher.menu.branch_heading
        launcher.menu.create_branch
        launcher.menu.track_remote
        launcher.menu.sync_branches
        launcher.menu.branch_cleanup
        ""
        launcher.menu.recovery_heading
        launcher.menu.log
        launcher.menu.remove_gitignored
        launcher.menu.reset
        launcher.menu.repair
        ""
        launcher.menu.security_heading
        launcher.menu.password
        launcher.menu.deploy_key
        launcher.menu.github_notifications
        ""
        launcher.menu.setup_heading
        launcher.menu.settings
        launcher.menu.cls
        launcher.menu.udc
        launcher.menu.readme
        ""
        launcher.menu.general_heading
        launcher.menu.update
        launcher.menu.help
        launcher.menu.exit
    )

    for key in "${menu_keys[@]}"; do
        if [ -z "$key" ]; then
            printf '\n'
        else
            print_dev_tools_menu_line "$key"
        fi
    done
}

# --- Argument-based quick start ---
if [[ $# -gt 0 ]]; then
    case "$1" in
        --commit|--c|-commit|-c|--cm)
            bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
            exit 0
            ;;
        --cc|-cc)
            bash "$ROOT_DIR/main_features/commit/create_commit_with_external_ai.sh"
            exit 0
            ;;
        --merge|--m|-merge|-m|--me)
            bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
            exit 0
            ;;
        --log|--l|-log|-l|--lg)
            bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
            exit 0
            ;;
        --readme|--r|-readme|-r|--rd)
            bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
            exit 0
            ;;
        --reset|--re|--revert|--x|-reset|-revert|-x)
            bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
            exit 0
            ;;
        --amend|--a|-amend|-a|--am)
            bash "$ROOT_DIR/main_features/amend/git_amend.sh"
            exit 0
            ;;
        --remove-gitignored|--i|-remove_gitignored|-i|--rg)
            bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
            exit 0
            ;;
        --branch-cleanup|--b|-branch_cleanup|-b|--bc)
            bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
            exit 0
            ;;
        --sync-branches|--s|-sync_branches|-s|--sb)
            bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
            exit 0
            ;;
        --track-remote|--t|-track_remote|-t|--tr)
            bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
            exit 0
            ;;
        --create-branch|--n|-create_branch|-n|--nb|--cnb)
            bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
            exit 0
            ;;
        --stash|--st|-stash|-st)
            bash "$ROOT_DIR/main_features/stash/stash_manager.sh"
            exit 0
            ;;
        --repair|--rp|--fix|--f|-repair|-fix|-f)
            bash "$ROOT_DIR/main_features/git-repair/git_repair.sh"
            exit 0
            ;;
        --password|--pw|-password|-pw)
            bash "$ROOT_DIR/main_features/password/generate_safe_passwords.sh" "${@:2}"
            exit $?
            ;;
        --deploy-key|--dk)
            bash "$ROOT_DIR/main_features/deploy-key/deploy_key_manager.sh" "${@:2}"
            exit 0
            ;;
        --github-notifications|--gh-notifications|--gn)
            bash "$ROOT_DIR/main_features/github-notifications/github_notifications.sh" "${@:2}"
            exit $?
            ;;
        --cls|-cls)
            bash "$ROOT_DIR/main_features/cls/cls_installer.sh" "${@:2}"
            exit $?
            ;;
        --udc)
            bash "$ROOT_DIR/main_features/udc/udc_installer.sh" "${@:2}"
            exit $?
            ;;
        --settings|--cfg|-settings|-cfg|--config|-config)
            bash "$ROOT_DIR/main_features/settings/edit_settings.sh"
            exit 0
            ;;
        --help|--h|-help|-h|help)
            show_dev_tools_help
            exit 0
            ;;
        --update|--u|-update|-u)
            if invoke_dev_tools_update "$ROOT_DIR"; then
                DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh"
            fi
            exit 1
            ;;
        --quit|--q)
            printf '%s\n' "$(get_dev_tools_update_message launcher.menu.exit_message)"
            exit 0
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
show_dev_tools_menu
echo ""

read -r -p "$(get_dev_tools_update_message launcher.menu.choice_prompt) " choice

# Convert choice to lowercase for easier matching
choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

case "$choice_lower" in
  1|"commit"|"--commit"|"-c"|"c"|"cm"|"--cm")
    bash "$ROOT_DIR/main_features/commit/git_export_staged.sh"
    ;;
  2|"cc"|"--cc"|"-cc"|"commit-external"|"external-commit")
    bash "$ROOT_DIR/main_features/commit/create_commit_with_external_ai.sh"
    ;;
  3|"merge"|"--merge"|"-m"|"m"|"me"|"--me")
    bash "$ROOT_DIR/main_features/merge/git_export_merge.sh"
    ;;
  4|"amend"|"--amend"|"-a"|"a"|"am"|"--am")
    bash "$ROOT_DIR/main_features/amend/git_amend.sh"
    ;;
  5|"stash"|"--stash"|"-st"|"st"|"--st")
    bash "$ROOT_DIR/main_features/stash/stash_manager.sh"
    ;;
  6|"create-branch"|"--create-branch"|"-n"|"n"|"nb"|"--nb"|"cnb"|"--cnb"|"new-branch"|"newbranch")
    bash "$ROOT_DIR/main_features/create-branch/create_branch.sh"
    ;;
  7|"track-remote"|"--track-remote"|"-t"|"t"|"tr"|"--tr"|"track"|"--track")
    bash "$ROOT_DIR/main_features/track-remote/track_remote.sh"
    ;;
  8|"sync-branches"|"--sync-branches"|"-s"|"s"|"sb"|"--sb"|"sync"|"--sync")
    bash "$ROOT_DIR/main_features/sync-branches/sync_branches.sh"
    ;;
  9|"branch-cleanup"|"--branch-cleanup"|"-b"|"b"|"bc"|"--bc"|"cleanup"|"--cleanup")
    bash "$ROOT_DIR/main_features/branch-cleanup/branch_cleanup.sh"
    ;;
  10|"log"|"--log"|"-l"|"l"|"lg"|"--lg")
    bash "$ROOT_DIR/main_features/git/git_log_explorer.sh"
    ;;
  11|"remove-gitignored"|"--remove-gitignored"|"-i"|"i"|"rg"|"--rg"|"gitignored"|"--gitignored")
    bash "$ROOT_DIR/main_features/remove-gitignored/remove_gitignored.sh"
    ;;
  12|"reset"|"--reset"|"-x"|"x"|"revert"|"--revert"|"re"|"--re")
    bash "$ROOT_DIR/main_features/git/reset_local_changes.sh"
    ;;
  13|"repair"|"--repair"|"rp"|"--rp"|"fix"|"--fix"|"-f"|"f")
    bash "$ROOT_DIR/main_features/git-repair/git_repair.sh"
    ;;
  14|"password"|"--password"|"pw"|"--pw")
    bash "$ROOT_DIR/main_features/password/generate_safe_passwords.sh"
    ;;
  15|"deploy-key"|"--deploy-key"|"dk"|"--dk")
    bash "$ROOT_DIR/main_features/deploy-key/deploy_key_manager.sh"
    ;;
  16|"gn"|"--gn"|"github-notifications"|"--github-notifications"|"gh-notifications"|"--gh-notifications")
    bash "$ROOT_DIR/main_features/github-notifications/github_notifications.sh"
    ;;
  17|"settings"|"--settings"|"cfg"|"--cfg"|"-cfg"|"config"|"--config")
    bash "$ROOT_DIR/main_features/settings/edit_settings.sh"
    ;;
  18|"cls"|"--cls")
    bash "$ROOT_DIR/main_features/cls/cls_installer.sh"
    ;;
  22|"udc"|"--udc")
    bash "$ROOT_DIR/main_features/udc/udc_installer.sh"
    ;;
  19|"readme"|"--readme"|"-r"|"r"|"rd"|"--rd")
    bash "$ROOT_DIR/main_features/readme/show_readme_instructions.sh"
    ;;
  20|"u"|"update"|"--update"|"-u"|"--u")
    if [[ "$DEVTOOLS_UPDATE_AVAILABLE" == "1" ]]; then
      if invoke_dev_tools_update "$ROOT_DIR"; then
        DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh"
      fi
    else
      printf '%s\n' "$(get_dev_tools_update_message updates.current)"
    fi
    ;;
  21|"h"|"help"|"--help"|"-h"|"--h")
    show_dev_tools_help
    ;;
  0|"q"|"quit"|"--quit"|"--q"|"exit")
    printf '%s\n' "$(get_dev_tools_update_message launcher.menu.exit_message)"
    exit 0
    ;;
  *)
    format_dev_tools_update_message launcher.menu.invalid_choice "$choice"
    printf '\n%s\n' "$(get_dev_tools_update_message launcher.menu.invalid_choices)"
    ;;
esac
