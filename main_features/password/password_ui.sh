#!/bin/bash
#
# Interactive prompts and delivery helpers for password generation.
#
# Contains the menu flow for choosing password policy, count, and delivery,
# plus clipboard, file, and terminal output handlers.
#
# Dependencies:
#   - password_core.sh must be sourced first.
#   - Optional clipboard tool: pbcopy, wl-copy, xclip, xsel, clip.exe, or clip.
#

PASSWORD_MESSAGE_FILE=""

# load_password_messages
#
# Loads password-generator messages for the active locale. German is selected
# for de locales and English otherwise. PASSWORD_GENERATOR_LOCALE can override
# locale detection with en or de for deterministic CLI use and testing.
#
# Returns:
#   0 after selecting the global PASSWORD_MESSAGE_FILE catalog.
load_password_messages() {
    local requested_locale locale_file
    requested_locale="${PASSWORD_GENERATOR_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}"

    case "$requested_locale" in
        [Dd][Ee]|[Dd][Ee][_-]*) locale_file="de.properties" ;;
        *) locale_file="en.properties" ;;
    esac

    PASSWORD_MESSAGE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/locales/${locale_file}"
}

# get_password_message
#
# Returns one localized message without interpreting percent characters.
#
# Arguments:
#   $1 - key: stable message-catalog key.
#
# Outputs:
#   The localized message.
#
# Returns:
#   0 when the key exists; 1 otherwise.
get_password_message() {
    local key="$1" line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "$key="* ]]; then
            line="${line%$'\r'}"
            printf '%s' "${line#*=}"
            return 0
        fi
    done < "$PASSWORD_MESSAGE_FILE"

    printf 'Missing password message key: %s\n' "$key" >&2
    return 1
}

# format_password_message
#
# Formats one localized message with ordered %s placeholders.
#
# Arguments:
#   $1 - key: stable message-catalog key.
#   Remaining arguments - values for the message's %s placeholders.
#
# Outputs:
#   The formatted localized message.
#
# Returns:
#   0 when the key exists and formatting succeeds; 1 otherwise.
format_password_message() {
    local key="$1" message remaining prefix formatted argument
    shift
    message=$(get_password_message "$key") || return 1
    remaining="$message"
    formatted=""

    for argument in "$@"; do
        if [[ "$remaining" != *"%s"* ]]; then
            printf 'Password message key has too few placeholders: %s\n' "$key" >&2
            return 1
        fi

        prefix="${remaining%%\%s*}"
        formatted+="${prefix}${argument}"
        remaining="${remaining#*%s}"
    done

    printf '%s' "${formatted}${remaining}"
}

load_password_messages

# show_password_generator_help
#
# Prints launcher usage and summarizes the interactive defaults.
#
# Outputs:
#   Usage text.
#
# Returns:
#   0 after writing usage text.
show_password_generator_help() {
    local balanced_special_characters
    balanced_special_characters=$(get_special_character_set "$DEFAULT_SPECIAL_CHARACTER_PRESET")

    printf '%s\n' "$(get_password_message title)"
    printf '\n'
    printf '%s\n' "$(get_password_message usage)"
    printf '%s\n' "$(get_password_message usage_password)"
    printf '%s\n' "$(get_password_message usage_pw)"
    printf '\n'
    printf '%s\n' "$(get_password_message interactive_defaults)"
    format_password_message default_characters "$balanced_special_characters"
    printf '\n'
    printf '%s\n' "$(get_password_message default_special_preset)"
    format_password_message default_length "$DEFAULT_PASSWORD_LENGTH"
    printf '\n'
    format_password_message default_count "$DEFAULT_PASSWORD_COUNT"
    printf '\n'
    printf '%s\n' "$(get_password_message default_delivery)"
}

# read_yes_no_choice
#
# Prompts for a yes/no answer with a default.
#
# Arguments:
#   $1 - prompt: question shown to the user.
#   $2 - default_yes: "true" when Enter means yes, otherwise false.
#
# Outputs:
#   "true" or "false".
#
# Returns:
#   0 after a valid answer is read.
read_yes_no_choice() {
    local prompt="$1"
    local default_yes="$2"
    local suffix answer

    if [ "$default_yes" = true ]; then
        suffix="Y/n"
    else
        suffix="y/N"
    fi

    while true; do
        read -r -p "$(format_password_message prompt_with_default "$prompt" "$suffix"): " answer
        answer=$(LC_ALL=C tr '[:upper:]' '[:lower:]' <<< "$answer")

        if [ -z "$answer" ]; then
            echo "$default_yes"
            return 0
        fi

        case "$answer" in
            y|yes) echo "true"; return 0 ;;
            n|no) echo "false"; return 0 ;;
            *) printf '%s\n' "$(get_password_message yes_no_invalid)" >&2 ;;
        esac
    done
}

# read_integer_choice
#
# Prompts for an integer with default, minimum, and maximum validation.
#
# Arguments:
#   $1 - prompt: question shown to the user.
#   $2 - default_value: value used when Enter is pressed.
#   $3 - minimum_value: lowest accepted integer.
#   $4 - maximum_value: highest accepted integer.
#
# Outputs:
#   The selected integer.
#
# Returns:
#   0 after a valid integer is read.
read_integer_choice() {
    local prompt="$1"
    local default_value="$2"
    local minimum_value="$3"
    local maximum_value="$4"
    local answer

    while true; do
        read -r -p "$(format_password_message prompt_with_default "$prompt" "$default_value"): " answer
        if [ -z "$answer" ]; then
            echo "$default_value"
            return 0
        fi

        if [[ "$answer" =~ ^[0-9]+$ ]] &&
            [ "$answer" -ge "$minimum_value" ] &&
            [ "$answer" -le "$maximum_value" ]; then
            echo "$answer"
            return 0
        fi

        format_password_message integer_range "$minimum_value" "$maximum_value" >&2
        printf '\n' >&2
    done
}

# read_special_character_preset
#
# Prompts for a numbered or lettered special-character compatibility preset.
# Pressing Enter selects balanced, the recommended default.
#
# Outputs:
#   "none", "minimum", "balanced", "high", or "all".
#
# Returns:
#   0 after a valid selection is read.
read_special_character_preset() {
    local answer

    while true; do
        printf '\n' >&2
        printf '%s\n' "$(get_password_message special_menu_title)" >&2
        printf '%s\n' "$(get_password_message special_option_none)" >&2
        printf '%s\n' "$(get_password_message special_option_minimum)" >&2
        printf '%s\n' "$(get_password_message special_option_balanced)" >&2
        printf '%s\n' "$(get_password_message special_option_high)" >&2
        printf '%s\n' "$(get_password_message special_option_all)" >&2
        read -r -p "$(get_password_message special_prompt): " answer

        answer=$(LC_ALL=C tr '[:upper:]' '[:lower:]' <<< "$answer")
        case "${answer:-$DEFAULT_SPECIAL_CHARACTER_PRESET}" in
            1|n|none) printf '%s' "none"; return 0 ;;
            2|m|minimum) printf '%s' "minimum"; return 0 ;;
            3|b|balanced) printf '%s' "balanced"; return 0 ;;
            4|h|high) printf '%s' "high"; return 0 ;;
            5|a|all) printf '%s' "all"; return 0 ;;
            *) printf '%s\n' "$(get_password_message special_invalid)" >&2 ;;
        esac
    done
}

# find_clipboard_command
#
# Detects a clipboard utility available on the current platform.
#
# Outputs:
#   A command identifier understood by copy_passwords_to_clipboard.
#
# Returns:
#   0 when a clipboard utility is found; 1 otherwise.
find_clipboard_command() {
    if command -v pbcopy >/dev/null 2>&1; then
        echo "pbcopy"
    elif command -v wl-copy >/dev/null 2>&1; then
        echo "wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
        echo "xclip"
    elif command -v xsel >/dev/null 2>&1; then
        echo "xsel"
    elif command -v clip.exe >/dev/null 2>&1; then
        echo "clip.exe"
    elif command -v clip >/dev/null 2>&1; then
        echo "clip"
    else
        return 1
    fi
}

# read_delivery_choice
#
# Prompts for the generated password delivery method.
#
# Outputs:
#   "clipboard", "file", or "terminal".
#
# Returns:
#   0 after a valid delivery method is selected.
read_delivery_choice() {
    local answer

    while true; do
        printf '\n' >&2
        printf '%s\n' "$(get_password_message delivery_title)" >&2
        printf '%s\n' "$(get_password_message delivery_clipboard)" >&2
        printf '%s\n' "$(get_password_message delivery_file)" >&2
        printf '%s\n' "$(get_password_message delivery_terminal)" >&2
        read -r -p "$(get_password_message delivery_prompt): " answer

        case "${answer:-1}" in
            1) echo "clipboard"; return 0 ;;
            2) echo "file"; return 0 ;;
            3) echo "terminal"; return 0 ;;
            *) printf '%s\n' "$(get_password_message delivery_invalid)" >&2 ;;
        esac
    done
}

# write_passwords_to_clipboard
#
# Writes generated password material to the selected clipboard command.
#
# Arguments:
#   $1 - clipboard_command: command identifier from find_clipboard_command.
#   $2 - payload: newline-separated password values.
#
# Returns:
#   0 when the clipboard command accepted the payload; 1 otherwise.
write_passwords_to_clipboard() {
    local clipboard_command="$1"
    local payload="$2"

    case "$clipboard_command" in
        pbcopy) printf '%s' "$payload" | pbcopy ;;
        wl-copy) printf '%s' "$payload" | wl-copy ;;
        xclip) printf '%s' "$payload" | xclip -selection clipboard ;;
        xsel) printf '%s' "$payload" | xsel --clipboard --input ;;
        clip.exe) printf '%s' "$payload" | clip.exe ;;
        clip) printf '%s' "$payload" | clip ;;
        *) return 1 ;;
    esac
}

# copy_passwords_to_clipboard
#
# Copies generated passwords to the system clipboard and offers to clear it
# after the user has pasted the values.
#
# Arguments:
#   Remaining arguments - password values to copy.
#
# Returns:
#   0 on success; non-zero when no clipboard utility is available.
copy_passwords_to_clipboard() {
    local clipboard_command
    clipboard_command=$(find_clipboard_command) || {
        printf '%s\n' "$(get_password_message clipboard_missing)" >&2
        return 1
    }

    local payload
    payload=$(printf '%s\n' "$@")

    if ! write_passwords_to_clipboard "$clipboard_command" "$payload"; then
        format_password_message clipboard_copy_failed "$clipboard_command" >&2
        printf '\n' >&2
        return 1
    fi

    printf '\n'
    format_password_message clipboard_copied "$#"
    printf '\n'
    printf '%s\n' "$(get_password_message clipboard_paste)"

    local clear_clipboard
    clear_clipboard=$(read_yes_no_choice "$(get_password_message clipboard_clear_prompt)" true)
    if [ "$clear_clipboard" = true ] && clear_password_clipboard "$clipboard_command"; then
        printf '%s\n' "$(get_password_message clipboard_cleared)"
    elif [ "$clear_clipboard" = true ]; then
        printf '%s\n' "$(get_password_message clipboard_clear_failed)" >&2
    fi
}

# clear_password_clipboard
#
# Removes generated password material from the clipboard.
#
# Arguments:
#   $1 - clipboard_command: command identifier from find_clipboard_command.
#
# Returns:
#   0 when the clipboard was cleared or overwritten; 1 otherwise.
clear_password_clipboard() {
    local clipboard_command="$1"

    case "$clipboard_command" in
        pbcopy) printf '' | pbcopy && return 0 ;;
        wl-copy) printf '' | wl-copy && return 0 ;;
        xclip) printf '' | xclip -selection clipboard && return 0 ;;
        xsel) printf '' | xsel --clipboard --input && return 0 ;;
        clip.exe|clip)
            if command -v powershell.exe >/dev/null 2>&1; then
                powershell.exe -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.Clipboard]::Clear()" >/dev/null 2>&1 && return 0
            fi
            printf ' ' | "$clipboard_command" && return 0
            ;;
    esac

    return 1
}

# save_passwords_to_file
#
# Saves generated passwords to a user-selected plaintext file.
#
# Arguments:
#   Remaining arguments - password values to write.
#
# Returns:
#   0 after the file is written.
save_passwords_to_file() {
    printf '\n'
    printf '%s\n' "$(get_password_message file_warning)"

    local path
    read -r -p "$(get_password_message file_prompt): " path
    path="${path:-generated-passwords.txt}"

    umask 077
    printf '%s\n' "$@" > "$path"
    format_password_message file_saved "$#" "$path"
    printf '\n'
    printf '%s\n' "$(get_password_message file_cleanup)"
}

# write_passwords_to_terminal
#
# Prints generated password values to the terminal.
#
# Arguments:
#   Remaining arguments - password values to print.
#
# Returns:
#   0 after writing password values.
write_passwords_to_terminal() {
    printf '\n'
    printf '%s\n' "$(get_password_message terminal_header)"
    printf '%s\n' "$@"
}

# invoke_safe_password_generator
#
# Runs the interactive safe password generation workflow.
#
# Returns:
#   0 after passwords are generated and delivered.
invoke_safe_password_generator() {
    printf '\n'
    printf '%s\n' "$(get_password_message title)"
    printf '%s\n' "$(get_password_message title_divider)"
    printf '\n'

    local special_character_preset password_length password_count generated_passwords password delivery
    local -a passwords=()
    special_character_preset=$(read_special_character_preset)
    password_length=$(read_integer_choice "$(get_password_message password_length)" "$DEFAULT_PASSWORD_LENGTH" "$MINIMUM_PASSWORD_LENGTH" 4096)
    password_count=$(read_integer_choice "$(get_password_message password_count)" "$DEFAULT_PASSWORD_COUNT" 1 100)
    generated_passwords=$(new_safe_password_set "$password_length" "$password_count" "$special_character_preset") || return 1
    while IFS= read -r password; do
        passwords+=("$password")
    done <<< "$generated_passwords"

    while true; do
        delivery=$(read_delivery_choice)
        case "$delivery" in
            clipboard)
                if copy_passwords_to_clipboard "${passwords[@]}"; then
                    return 0
                fi
                printf '%s\n' "$(get_password_message delivery_retry)" >&2
                ;;
            file)
                save_passwords_to_file "${passwords[@]}"
                return 0
                ;;
            terminal)
                write_passwords_to_terminal "${passwords[@]}"
                return 0
                ;;
        esac
    done
}
