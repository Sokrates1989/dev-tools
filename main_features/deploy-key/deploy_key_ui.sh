#!/bin/bash
#
# Interactive repository input and result output for the Deploy Key Manager.
#
# This module consumes deploy_key_core.sh, deploy_key_instructions.sh, and
# localized root catalogs. It never changes ~/.ssh/config.
#

DEPLOY_KEY_LOCALE_FILE=""
DEPLOY_KEY_REPOSITORY_INPUT=""
DEPLOY_KEY_PASTE_TIMEOUT_SECONDS="${DEPLOY_KEY_PASTE_TIMEOUT_SECONDS:-0.15}"

# Selects the shared English or German Dev Tools catalog.
#
# Arguments:
#   $1 - repository_root: Dev Tools checkout containing locales.
#
# Returns:
#   0 when the selected catalog exists; 1 otherwise.
initialize_deploy_key_messages() {
    local repository_root="$1"
    local requested_locale language
    requested_locale="${DEV_TOOLS_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}"

    case "$requested_locale" in
        de|de[_-]*|DE|DE[_-]*) language="de" ;;
        *) language="en" ;;
    esac

    DEPLOY_KEY_LOCALE_FILE="${repository_root}/locales/${language}.properties"
    [ -f "$DEPLOY_KEY_LOCALE_FILE" ]
}

# Returns one localized Deploy Key Manager message.
#
# Arguments:
#   $1 - key: stable message-catalog key.
#
# Outputs:
#   The localized message without interpreting percent characters.
#
# Returns:
#   0 when the key exists; 1 otherwise.
get_deploy_key_message() {
    local key="$1"
    local line message_key message_value

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [ -z "$line" ] || [[ "$line" == \#* ]]; then
            continue
        fi

        message_key="${line%%=*}"
        if [ "$message_key" = "$key" ]; then
            message_value="${line#*=}"
            printf '%s' "$message_value"
            return 0
        fi
    done < "$DEPLOY_KEY_LOCALE_FILE"

    printf 'Missing Deploy Key Manager message key: %s\n' "$key" >&2
    return 1
}

# Formats one localized message with ordered percent-s placeholders.
#
# Arguments:
#   $1 - key: stable message-catalog key.
#   Remaining arguments - values for the message placeholders.
#
# Outputs:
#   The formatted localized message.
#
# Returns:
#   0 when the key exists and formatting succeeds; 1 otherwise.
format_deploy_key_message() {
    local key="$1"
    local message remaining prefix formatted argument
    shift
    message=$(get_deploy_key_message "$key") || return 1
    remaining="$message"
    formatted=""

    for argument in "$@"; do
        if [[ "$remaining" != *"%s"* ]]; then
            printf 'Deploy Key Manager message key has too few placeholders: %s\n' "$key" >&2
            return 1
        fi

        prefix="${remaining%%\%s*}"
        formatted+="${prefix}${argument}"
        remaining="${remaining#*%s}"
    done

    printf '%s' "${formatted}${remaining}"
}

# Prints focused command help without making filesystem changes.
show_deploy_key_help() {
    printf '%s\n' "$(get_deploy_key_message deploy_key.title)"
    printf '\n'
    printf '%s\n' "$(get_deploy_key_message deploy_key.help.usage)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.help.description)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.help.input)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.help.storage)"
    printf '%s\n' "$(get_deploy_key_message deploy_key.help.instructions)"
}

# Collects a complete immediately available paste block from standard input.
#
# A short timeout drains additional terminal lines so a second git remote line
# cannot escape into the parent shell. Non-interactive input is read to EOF.
#
# Arguments:
#   $1 - detected_default: optional origin URL selected by an empty first line.
#
# Global state:
#   Sets DEPLOY_KEY_REPOSITORY_INPUT.
#
# Returns:
#   0 when input or a default is available; 1 on empty end-of-file input.
collect_deploy_key_repository_input() {
    local detected_default="$1"
    local first_line=""
    local next_line=""
    local input_block=""
    local read_succeeded="false"

    printf '%s\n' "$(get_deploy_key_message deploy_key.prompt)"
    printf '\n> '
    if IFS= read -r first_line; then
        read_succeeded="true"
    elif [ -n "$first_line" ]; then
        read_succeeded="true"
    fi

    if [ "$read_succeeded" = "false" ]; then
        return 1
    fi

    if [ -z "$first_line" ] && [ -n "$detected_default" ]; then
        DEPLOY_KEY_REPOSITORY_INPUT="$detected_default"
        return 0
    fi

    input_block="$first_line"
    if [ -t 0 ]; then
        while true; do
            next_line=""
            if IFS= read -r -t "$DEPLOY_KEY_PASTE_TIMEOUT_SECONDS" next_line; then
                input_block+=$'\n'"$next_line"
            elif [ -n "$next_line" ]; then
                input_block+=$'\n'"$next_line"
                break
            else
                break
            fi
        done
    else
        while IFS= read -r next_line || [ -n "$next_line" ]; do
            input_block+=$'\n'"$next_line"
        done
    fi

    DEPLOY_KEY_REPOSITORY_INPUT="$input_block"
}

# Returns the current origin only when it is a supported repository URL.
detect_current_deploy_key_origin() {
    local origin
    if ! command -v git >/dev/null 2>&1; then
        return 1
    fi
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        return 1
    fi

    origin=$(git remote get-url origin 2>/dev/null) || return 1
    if ! normalize_deploy_key_repository_url "$origin"; then
        return 1
    fi

    printf '%s' "$origin"
}

# Replaces the current home-directory prefix with a readable tilde.
#
# Arguments:
#   $1 - path: absolute path to display.
#
# Outputs:
#   A tilde-prefixed path when it is below HOME.
get_deploy_key_display_path() {
    local path="$1"
    local home_marker="~"
    case "$path" in
        "${HOME}"/*) printf '%s/%s' "$home_marker" "${path#"${HOME}/"}" ;;
        *) printf '%s' "$path" ;;
    esac
}

# Prints the safe recovery explanation for an incomplete managed key pair.
#
# Arguments:
#   $1 - private_key_path: missing private key path.
show_missing_private_key_recovery() {
    local private_key_path="$1"
    local displayed_private_path
    displayed_private_path=$(get_deploy_key_display_path "$private_key_path")

    printf '%s\n' "$(get_deploy_key_message deploy_key.error.public_only)" >&2
    format_deploy_key_message deploy_key.error.public_only_path "${displayed_private_path}.pub" >&2
    printf '\n' >&2
    format_deploy_key_message deploy_key.error.private_expected "$displayed_private_path" >&2
    printf '\n' >&2
    printf '%s\n' "$(get_deploy_key_message deploy_key.error.public_only_recovery)" >&2
}

# Prints the final key summary, public key, and setup instructions.
#
# Arguments:
#   $1 - hostname: detected server hostname.
#   $2 - private_key_path: managed private key path.
#   $3 - key_comment: canonical public-key comment.
show_deploy_key_result() {
    local hostname="$1"
    local private_key_path="$2"
    local key_comment="$3"
    local public_key_path="${private_key_path}.pub"
    local displayed_private_path displayed_public_path public_material status_text
    local provider_label checkout_directory=""

    displayed_private_path=$(get_deploy_key_display_path "$private_key_path")
    displayed_public_path=$(get_deploy_key_display_path "$public_key_path")
    public_material=$(derive_deploy_key_public_material "$private_key_path")

    if [ "$DEPLOY_KEY_STATUS" = "CREATED" ]; then
        status_text=$(get_deploy_key_message deploy_key.status.created)
        printf '\n%s\n' "$(get_deploy_key_message deploy_key.ready.created)"
    else
        status_text=$(get_deploy_key_message deploy_key.status.existing)
        printf '\n%s\n' "$(get_deploy_key_message deploy_key.ready.existing)"
        printf '%s\n' "$(get_deploy_key_message deploy_key.ready.reuse)"
    fi
    printf '%s\n\n' "$(get_deploy_key_message deploy_key.ready.divider)"

    format_deploy_key_message deploy_key.summary.repository "$DEPLOY_KEY_REPOSITORY_ID"
    printf '\n'
    format_deploy_key_message deploy_key.summary.server "$hostname"
    printf '\n'
    format_deploy_key_message deploy_key.summary.status "$status_text"
    printf '\n\n'
    printf '%s\n%s\n' \
        "$(get_deploy_key_message deploy_key.summary.private)" "$displayed_private_path"
    printf '\n%s\n%s\n' \
        "$(get_deploy_key_message deploy_key.summary.public)" "$displayed_public_path"

    if [ "$DEPLOY_KEY_PUBLIC_RECOVERED" = "true" ]; then
        printf '\n%s\n' "$(get_deploy_key_message deploy_key.ready.recovered)"
    fi

    printf '\n%s\n%s\n\n' \
        "$(get_deploy_key_message deploy_key.public_key.heading)" \
        "$(get_deploy_key_message deploy_key.public_key.divider)"
    printf '%s %s\n\n' "$public_material" "$key_comment"

    provider_label=$(get_deploy_key_provider_label)
    checkout_directory=$(get_matching_deploy_key_checkout_directory || true)
    select_deploy_key_instruction_mode "$provider_label" || return 1
    show_selected_deploy_key_instructions \
        "$DEPLOY_KEY_SELECTED_INSTRUCTION_MODE" \
        "$hostname" \
        "$private_key_path" \
        "$checkout_directory"
}

# Runs the complete interactive Deploy Key Manager workflow.
#
# Returns:
#   0 when a key is created or reused; non-zero for validation or key errors.
invoke_deploy_key_manager() {
    local required_command hostname detected_origin="" repository_input
    local ssh_directory deploy_key_directory key_basename private_key_path key_comment
    local ensure_status

    for required_command in ssh-keygen hostname mkdir chmod; do
        if ! command -v "$required_command" >/dev/null 2>&1; then
            format_deploy_key_message deploy_key.error.missing_command "$required_command" >&2
            printf '\n' >&2
            return 1
        fi
    done
    if [ -z "${HOME:-}" ]; then
        printf '%s\n' "$(get_deploy_key_message deploy_key.error.home_missing)" >&2
        return 1
    fi

    hostname=$(detect_deploy_key_hostname) || {
        printf '%s\n' "$(get_deploy_key_message deploy_key.error.hostname)" >&2
        return 1
    }

    printf '\n%s\n%s\n\n' \
        "$(get_deploy_key_message deploy_key.title)" \
        "$(get_deploy_key_message deploy_key.title_divider)"
    format_deploy_key_message deploy_key.detected_server "$hostname"
    printf '\n\n'

    detected_origin=$(detect_current_deploy_key_origin || true)
    if [ -n "$detected_origin" ]; then
        printf '%s\n\n%s\n\n' \
            "$(get_deploy_key_message deploy_key.detected_repository)" "$detected_origin"
        printf '%s\n\n' "$(get_deploy_key_message deploy_key.detected_repository_hint)"
    fi

    while true; do
        if ! collect_deploy_key_repository_input "$detected_origin"; then
            printf '\n%s\n' "$(get_deploy_key_message deploy_key.error.input_required)" >&2
            return 1
        fi
        repository_input="$DEPLOY_KEY_REPOSITORY_INPUT"
        if extract_deploy_key_repository "$repository_input"; then
            break
        fi
        printf '\n%s\n\n' "$(get_deploy_key_message deploy_key.error.invalid_repository)" >&2
        detected_origin=""
    done

    printf '\n%s\n%s\n\n' \
        "$(get_deploy_key_message deploy_key.repository_detected)" \
        "$DEPLOY_KEY_REPOSITORY_ID"

    ssh_directory="${HOME}/.ssh"
    deploy_key_directory=$(get_managed_deploy_key_directory "$ssh_directory")
    if ! prepare_managed_deploy_key_directory "$ssh_directory"; then
        printf '%s\n' "$(get_deploy_key_message deploy_key.error.directory)" >&2
        return 1
    fi

    key_basename=$(get_deploy_key_basename \
        "$DEPLOY_KEY_PROVIDER" "$DEPLOY_KEY_OWNER" "$DEPLOY_KEY_REPOSITORY" "$hostname")
    private_key_path="${deploy_key_directory}/${key_basename}"
    key_comment="dev-tools deploy key | ${DEPLOY_KEY_REPOSITORY_ID} | ${hostname}"

    if ensure_managed_deploy_key "$private_key_path" "$key_comment"; then
        show_deploy_key_result "$hostname" "$private_key_path" "$key_comment" || return 1
        return 0
    else
        ensure_status=$?
    fi

    case "$ensure_status" in
        10) show_missing_private_key_recovery "$private_key_path" ;;
        11) printf '%s\n' "$(get_deploy_key_message deploy_key.error.unsafe_path)" >&2 ;;
        12) printf '%s\n' "$(get_deploy_key_message deploy_key.error.mismatched_pair)" >&2 ;;
        14) printf '%s\n' "$(get_deploy_key_message deploy_key.error.recovery_failed)" >&2 ;;
        *) printf '%s\n' "$(get_deploy_key_message deploy_key.error.generation_failed)" >&2 ;;
    esac
    return 1
}
