#!/bin/bash
#
# Selectable setup-stage instructions for the Deploy Key Manager.
#
# This module consumes deploy_key_core.sh plus the localized message helpers
# from deploy_key_ui.sh. It only renders guidance and never changes Git or SSH
# configuration.
#

# Cross-module selection state is consumed by deploy_key_ui.sh.
# shellcheck disable=SC2034
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
        case "${configured_mode,,}" in
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

        case "${answer,,}" in
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

# Prints exact server-side SSH config and Git commands for the managed key.
#
# Arguments:
#   $1 - ssh_alias: repository-specific SSH alias.
#   $2 - displayed_private_path: private key location, never its contents.
show_server_ssh_git_instructions() {
    local ssh_alias="$1"
    local displayed_private_path="$2"
    local remote_url="git@${ssh_alias}:${DEPLOY_KEY_OWNER}/${DEPLOY_KEY_REPOSITORY}.git"

    printf '\n%s\n' "$(get_deploy_key_message deploy_key.ssh.heading)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.ssh.preserve_config)"
    printf '\nHost %s\n' "$ssh_alias"
    printf '    HostName %s\n' "$DEPLOY_KEY_PROVIDER"
    printf '    User git\n'
    printf '    IdentityFile %s\n' "$displayed_private_path"
    printf '    IdentitiesOnly yes\n'

    printf '\n%s\n\n%s\n' \
        "$(get_deploy_key_message deploy_key.remote.heading)" "$remote_url"
    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.existing_clone.heading)"
    printf 'git remote set-url origin %s\n' "$remote_url"
    printf 'git remote -v\n'
    printf 'git fetch\n'
    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.new_clone.heading)"
    printf 'git clone %s\n' "$remote_url"
    printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.test.heading)"
    printf 'ssh -T git@%s\n' "$ssh_alias"
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
#   $3 - ssh_alias: repository-specific SSH alias.
#   $4 - displayed_private_path: private key location, never its contents.
show_selected_deploy_key_instructions() {
    local instruction_mode="$1"
    local hostname="$2"
    local ssh_alias="$3"
    local displayed_private_path="$4"

    case "$instruction_mode" in
        provider)
            show_repository_provider_instructions "$hostname"
            ;;
        ssh)
            show_server_ssh_git_instructions "$ssh_alias" "$displayed_private_path"
            ;;
        both)
            show_repository_provider_instructions "$hostname"
            show_server_ssh_git_instructions "$ssh_alias" "$displayed_private_path"
            ;;
        *)
            return 1
            ;;
    esac
}
