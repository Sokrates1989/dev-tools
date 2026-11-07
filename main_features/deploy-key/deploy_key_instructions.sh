#!/bin/bash
#
# Selectable setup-stage instructions for the Deploy Key Manager.
#
# This module consumes deploy_key_core.sh plus the localized message helpers
# from deploy_key_ui.sh. It only renders copy-pasteable guidance and never
# changes Git or SSH configuration itself.
#

# Cross-module state is consumed by deploy_key_ui.sh, and literal dollar
# expressions are intentionally printed for the user's command blocks.
# shellcheck disable=SC2016,SC2034
DEPLOY_KEY_SELECTED_INSTRUCTION_MODE=""

# Prints the GitHub deploy-key registration steps.
#
# Arguments:
#   $1 - hostname: detected server hostname.
show_github_deploy_key_instructions() {
    local hostname="$1"

    printf '%s\n' "$(get_deploy_key_message deploy_key.github.heading)"
    printf '\n'
    printf '%s\n' "$(get_deploy_key_message deploy_key.github.step_open)"
    printf '\nhttps://github.com/%s/%s/settings/keys\n\n' \
        "$DEPLOY_KEY_OWNER" "$DEPLOY_KEY_REPOSITORY"
    printf '%s\n' "$(get_deploy_key_message deploy_key.github.step_add)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.github.step_title)"
    printf '\n%s - %s\n\n' "$hostname" "$DEPLOY_KEY_REPOSITORY"
    printf '%s\n' "$(get_deploy_key_message deploy_key.github.step_paste)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.github.step_read_only)"
    printf '\n%s\n' "$(get_deploy_key_message deploy_key.github.read_only_explanation)"
}

# Prints provider-neutral deploy-key registration guidance.
show_generic_deploy_key_instructions() {
    printf '%s\n' "$(get_deploy_key_message deploy_key.generic.heading)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.generic.instructions)"
}

# Returns the user-facing repository provider name.
get_deploy_key_provider_label() {
    if [ "$DEPLOY_KEY_PROVIDER" = "github.com" ]; then
        get_deploy_key_message deploy_key.instructions.provider_github
    else
        printf '%s' "$DEPLOY_KEY_PROVIDER"
    fi
}

# Prints instructions for registering the public key with its provider.
#
# Arguments:
#   $1 - hostname: detected server hostname.
show_repository_provider_instructions() {
    local hostname="$1"
    if [ "$DEPLOY_KEY_PROVIDER" = "github.com" ]; then
        show_github_deploy_key_instructions "$hostname"
    else
        show_generic_deploy_key_instructions
    fi
}

# Returns the current checkout root when its origin matches the selected
# repository. Previously generated dev-tools SSH aliases are normalized by the
# core parser and therefore remain eligible.
#
# Outputs:
#   The absolute Git work-tree root.
#
# Returns:
#   0 for a matching checkout; 1 outside one or for a different repository.
get_matching_deploy_key_checkout_directory() {
    local selected_repository_id="$DEPLOY_KEY_REPOSITORY_ID"
    local origin current_repository_id

    command -v git >/dev/null 2>&1 || return 1
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
    origin=$(git remote get-url origin 2>/dev/null) || return 1
    current_repository_id=$(
        normalize_deploy_key_repository_url "$origin" &&
            printf '%s' "$DEPLOY_KEY_REPOSITORY_ID"
    ) || return 1
    [ "$current_repository_id" = "$selected_repository_id" ] || return 1

    git rev-parse --show-toplevel 2>/dev/null
}

# Prints a shell-safe variable assignment for a generated command block.
#
# Arguments:
#   $1 - variable_name: trusted variable name owned by this module.
#   $2 - value: assignment value to shell-escape.
print_deploy_key_shell_assignment() {
    local variable_name="$1"
    local value="$2"

    printf '%s=' "$variable_name"
    printf '%q' "$value"
    printf '\n'
}

# Selects which setup-instruction stage to display next.
#
# Interactive sessions default to provider registration. Non-interactive
# sessions retain complete output by selecting both stages. The optional
# DEPLOY_KEY_INSTRUCTION_MODE value supports provider, ssh, or both.
#
# Arguments:
#   $1 - provider_label: user-facing repository provider name.
#
# Global state:
#   Sets DEPLOY_KEY_SELECTED_INSTRUCTION_MODE.
#
# Returns:
#   0 for a supported selection; 1 for an invalid environment override.
select_deploy_key_instruction_mode() {
    local provider_label="$1"
    local configured_mode="${DEPLOY_KEY_INSTRUCTION_MODE:-}"
    local answer=""

    if [ -n "$configured_mode" ]; then
        case "$(lowercase_deploy_key_value "$configured_mode")" in
            1|provider) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="provider" ;;
            2|ssh|server) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="ssh" ;;
            3|both) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="both" ;;
            *)
                format_deploy_key_message \
                    deploy_key.instructions.invalid_mode "$configured_mode" >&2
                printf '\n' >&2
                return 1
                ;;
        esac
        return 0
    fi

    if [ ! -t 0 ]; then
        DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="both"
        return 0
    fi

    printf '%s\n' "$(get_deploy_key_message deploy_key.instructions.heading)"
    printf '%s\n\n' "$(get_deploy_key_message deploy_key.instructions.explanation)"
    while true; do
        format_deploy_key_message deploy_key.instructions.option_provider "$provider_label"
        printf '\n'
        printf '%s\n' "$(get_deploy_key_message deploy_key.instructions.option_ssh)"
        printf '%s\n\n' "$(get_deploy_key_message deploy_key.instructions.option_both)"
        printf '%s ' "$(get_deploy_key_message deploy_key.instructions.prompt)"
        if ! IFS= read -r answer; then
            answer=""
        fi

        case "$(lowercase_deploy_key_value "$answer")" in
            ""|1|provider) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="provider"; return 0 ;;
            2|ssh|server) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="ssh"; return 0 ;;
            3|both) DEPLOY_KEY_SELECTED_INSTRUCTION_MODE="both"; return 0 ;;
            *)
                printf '\n%s\n\n' \
                    "$(get_deploy_key_message deploy_key.instructions.invalid)" >&2
                ;;
        esac
    done
}

# Prints complete repository-local SSH and Git command blocks.
#
# Arguments:
#   $1 - private_key_path: managed private key path, never its contents.
#   $2 - checkout_directory: matching checkout root, or empty when unknown.
show_server_ssh_git_instructions() {
    local private_key_path="$1"
    local checkout_directory="$2"
    local remote_url="git@${DEPLOY_KEY_PROVIDER}:${DEPLOY_KEY_OWNER}/${DEPLOY_KEY_REPOSITORY}.git"

    printf '\n%s\n' "$(get_deploy_key_message deploy_key.ssh.heading)"
    if [[ "$OSTYPE" == msys* ]]; then
        printf '%s\n' "$(get_deploy_key_message deploy_key.ssh.windows_shell)"
    fi
    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.existing_clone.heading)"
    if [ -n "$checkout_directory" ]; then
        printf '%s\n\n' "$(get_deploy_key_message deploy_key.existing_clone.detected)"
    else
        checkout_directory="/path/to/${DEPLOY_KEY_REPOSITORY}"
        printf '%s\n\n' "$(get_deploy_key_message deploy_key.existing_clone.placeholder)"
    fi
    print_deploy_key_shell_assignment REPOSITORY_DIR "$checkout_directory"
    print_deploy_key_shell_assignment DEPLOY_KEY_PATH "$private_key_path"
    printf '\n'
    printf 'git -C "$REPOSITORY_DIR" config core.sshCommand \\\n'
    printf '  "ssh -i \\"$DEPLOY_KEY_PATH\\" -o IdentitiesOnly=yes"\n\n'
    printf 'git -C "$REPOSITORY_DIR" remote set-url origin \\\n'
    printf '  %s\n\n' "$remote_url"
    printf 'git -C "$REPOSITORY_DIR" remote -v\n'
    printf 'git -C "$REPOSITORY_DIR" fetch origin\n'
    printf '\n%s\n' "$(get_deploy_key_message deploy_key.existing_clone.local_note)"

    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.new_clone.heading)"
    print_deploy_key_shell_assignment DEPLOY_KEY_PATH "$private_key_path"
    print_deploy_key_shell_assignment CLONE_DIRECTORY "$DEPLOY_KEY_REPOSITORY"
    printf '\n'
    printf 'GIT_SSH_COMMAND="ssh -i \\"$DEPLOY_KEY_PATH\\" -o IdentitiesOnly=yes" \\\n'
    printf '  git clone %s "$CLONE_DIRECTORY"\n\n' "$remote_url"
    printf 'git -C "$CLONE_DIRECTORY" config core.sshCommand \\\n'
    printf '  "ssh -i \\"$DEPLOY_KEY_PATH\\" -o IdentitiesOnly=yes"\n'

    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.test.heading)"
    print_deploy_key_shell_assignment DEPLOY_KEY_PATH "$private_key_path"
    printf 'ssh -T -i "$DEPLOY_KEY_PATH" -o IdentitiesOnly=yes git@%s\n' \
        "$DEPLOY_KEY_PROVIDER"
    if [ "$DEPLOY_KEY_PROVIDER" = "github.com" ]; then
        printf '\n%s\n' "$(get_deploy_key_message deploy_key.test.github_note)"
    fi
}

# Dispatches the selected setup-instruction stage.
#
# New independently rendered stages can be added here without changing key
# creation, provider-specific rendering, or result-summary behavior.
#
# Arguments:
#   $1 - instruction_mode: provider, ssh, or both.
#   $2 - hostname: detected server hostname.
#   $3 - private_key_path: managed private key path, never its contents.
#   $4 - checkout_directory: matching checkout root, or empty when unknown.
show_selected_deploy_key_instructions() {
    local instruction_mode="$1"
    local hostname="$2"
    local private_key_path="$3"
    local checkout_directory="$4"

    case "$instruction_mode" in
        provider)
            show_repository_provider_instructions "$hostname"
            ;;
        ssh)
            show_server_ssh_git_instructions "$private_key_path" "$checkout_directory"
            ;;
        both)
            show_repository_provider_instructions "$hostname"
            show_server_ssh_git_instructions "$private_key_path" "$checkout_directory"
            ;;
        *)
            return 1
            ;;
    esac
}
