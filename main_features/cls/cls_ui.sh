#!/bin/bash
#
# Localized interactive workflow for installing the cls terminal cleaner.
#

CLS_LOCALE_FILE=""

# Selects the English or German cls message catalog.
initialize_cls_messages() {
    local feature_directory="$1"
    local requested_locale language
    requested_locale="${DEV_TOOLS_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}"
    case "$requested_locale" in
        de|de[_-]*|DE|DE[_-]*) language="de" ;;
        *) language="en" ;;
    esac
    CLS_LOCALE_FILE="${feature_directory}/locales/${language}.properties"
    [ -f "$CLS_LOCALE_FILE" ]
}

# Returns one localized cls message without interpreting percent characters.
get_cls_message() {
    local key="$1"
    local line message_key
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
            continue
        fi
        message_key="${line%%=*}"
        if [ "$message_key" = "$key" ]; then
            printf '%s' "${line#*=}"
            return 0
        fi
    done < "$CLS_LOCALE_FILE"
    printf 'Missing cls message key: %s\n' "$key" >&2
    return 1
}

# Formats one localized cls message with ordered %s placeholders.
format_cls_message() {
    local key="$1" message remaining prefix formatted argument
    shift
    message=$(get_cls_message "$key") || return 1
    remaining="$message"
    formatted=""
    for argument in "$@"; do
        if [[ "$remaining" != *"%s"* ]]; then
            printf 'cls message key has too few placeholders: %s\n' "$key" >&2
            return 1
        fi
        prefix="${remaining%%\%s*}"
        formatted="${formatted}${prefix}${argument}"
        remaining="${remaining#*%s}"
    done
    printf '%s' "${formatted}${remaining}"
}

# Prompts until the user accepts or declines; Enter defaults to no.
read_cls_yes_no_choice() {
    local prompt="$1"
    local answer
    while true; do
        read -r -p "$prompt " answer || answer=""
        case "$answer" in
            y|Y|yes|YES|Yes|j|J|ja|JA|Ja) return 0 ;;
            ""|n|N|no|NO|No|nein|NEIN|Nein) return 1 ;;
            *) printf '%s\n' "$(get_cls_message prompt.invalid)" ;;
        esac
    done
}

# Prints the exact configuration and reload steps for manual installation.
show_cls_manual_instructions() {
    local shell_name="$1"
    local profile_path="${2:-}"
    local reload_command

    printf '\n%s\n\n' "$(get_cls_message manual.heading)"
    if [ -n "$profile_path" ]; then
        printf '%s\n\n' "$(format_cls_message manual.add_to "$profile_path")"
    else
        printf '%s\n\n' "$(get_cls_message manual.choose_profile)"
    fi
    get_cls_managed_block
    printf '\n'

    if reload_command=$(get_cls_reload_command "$shell_name" 2>/dev/null); then
        printf '\n%s\n\n  %s\n' "$(get_cls_message manual.reload)" "$reload_command"
    fi
}

# Prints a safe one-shot command when persistent syntax is unknown.
show_cls_unknown_shell_instructions() {
    printf '\n%s\n\n' "$(get_cls_message manual.heading)"
    printf '%s\n\n  %s\n\n' "$(get_cls_message manual.command)" "$CLS_PRINTF_COMMAND"
    printf '%s\n' "$(get_cls_message manual.shell_docs)"
}

# Prints activation instructions after a successful or existing installation.
show_cls_activation() {
    local shell_name="$1"
    local reload_command
    reload_command=$(get_cls_reload_command "$shell_name") || return 0

    printf '\n%s\n\n  %s\n\n' "$(get_cls_message success.activate)" "$reload_command"
    printf '%s\n\n' "$(get_cls_message success.future)"
    printf '%s\n\n  cls\n' "$(get_cls_message success.run)"
}

# Coordinates shell detection, conflict handling, confirmation, and install.
invoke_cls_setup() {
    local os_name shell_name shell_label profile_path prompt install_status force_append
    force_append="false"
    os_name=$(detect_cls_os)
    shell_name=$(detect_cls_shell)
    shell_label=$(get_cls_shell_label "$shell_name")
    profile_path=$(resolve_cls_profile "$shell_name" 2>/dev/null || true)

    printf '\n%s\n%s\n\n' "$(get_cls_message title)" "$(get_cls_message divider)"
    printf '%-8s %s\n' "$(get_cls_message summary.os)" "$os_name"
    printf '%-8s %s\n' "$(get_cls_message summary.shell)" "$shell_label"
    if [ -n "$profile_path" ]; then
        printf '%-8s %s\n' "$(get_cls_message summary.profile)" "$profile_path"
    else
        printf '%-8s %s\n' "$(get_cls_message summary.profile)" "$(get_cls_message summary.unavailable)"
    fi

    printf '\n%s\n%s\n' "$(get_cls_message description.first)" "$(get_cls_message description.second)"
    printf '%s\n' "$(get_cls_message description.ed3)"
    printf '\n%s\n\n%s\n' "$(get_cls_message config.heading)" "$CLS_ALIAS_LINE"

    if [ -z "$profile_path" ]; then
        printf '\n%s\n' "$(format_cls_message unsupported.shell "$shell_label")"
        show_cls_unknown_shell_instructions
        return 0
    fi

    get_cls_profile_state "$profile_path"
    if [ "$CLS_PROFILE_STATE" = "malformed" ]; then
        printf '\n%s\n' "$(get_cls_message error.malformed)" >&2
        show_cls_manual_instructions "$shell_name" "$profile_path"
        return 1
    fi

    detect_existing_cls "$profile_path"
    if [ "$CLS_EXISTING_KIND" != "none" ]; then
        printf '\n%s\n' "$(get_cls_message conflict.detected)"
        prompt=$(get_cls_message prompt.override)
        if [ "$CLS_PROFILE_STATE" = "current" ] || [ "$CLS_PROFILE_STATE" = "stale" ]; then
            force_append="true"
        fi
    else
        case "$CLS_PROFILE_STATE" in
        current)
            printf '\n%s\n' "$(get_cls_message already_installed)"
            printf '%s\n' "$(format_cls_message existing.profile "$profile_path")"
            show_cls_activation "$shell_name"
            return 0
            ;;
        stale)
            prompt=$(get_cls_message prompt.update)
            ;;
        *)
            prompt=$(get_cls_message prompt.install)
            ;;
        esac
    fi

    if ! read_cls_yes_no_choice "$prompt"; then
        printf '\n%s\n' "$(get_cls_message declined)"
        show_cls_manual_instructions "$shell_name" "$profile_path"
        return 0
    fi

    if install_cls_managed_block "$profile_path" "$force_append"; then
        printf '\n%s\n' "$(get_cls_message success.installed)"
        show_cls_activation "$shell_name"
        return 0
    else
        install_status=$?
    fi

    if [ "$install_status" -eq 2 ]; then
        printf '\n%s\n' "$(get_cls_message error.symlink_update)" >&2
    else
        printf '\n%s\n' "$(format_cls_message error.write "$profile_path")" >&2
    fi
    show_cls_manual_instructions "$shell_name" "$profile_path"
    return 1
}

# Prints focused help for the cls setup command.
show_cls_help() {
    printf '%s\n\n' "$(get_cls_message help.usage)"
    printf '%s\n' "$(get_cls_message help.description)"
    printf '%s\n' "$(get_cls_message help.supported)"
    printf '%s\n' "$(get_cls_message description.ed3)"
}
