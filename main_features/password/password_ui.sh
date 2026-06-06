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
    echo "Safe Password Generator"
    echo ""
    echo "Usage:"
    echo "  dev-tools --password"
    echo "  dev-tools --pw"
    echo ""
    echo "Interactive defaults:"
    echo "  Characters: A-Z, a-z, 0-9, and safe specials (${SAFE_SPECIAL_CHARS})"
    echo "  Length:     ${DEFAULT_PASSWORD_LENGTH}"
    echo "  Count:      ${DEFAULT_PASSWORD_COUNT}"
    echo "  Delivery:   Clipboard (recommended)"
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
        suffix="[Y/n]"
    else
        suffix="[y/N]"
    fi

    while true; do
        read -r -p "${prompt} ${suffix}: " answer
        answer="${answer,,}"

        if [ -z "$answer" ]; then
            echo "$default_yes"
            return 0
        fi

        case "$answer" in
            y|yes) echo "true"; return 0 ;;
            n|no) echo "false"; return 0 ;;
            *) echo "Please enter yes or no." >&2 ;;
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
        read -r -p "${prompt} [${default_value}]: " answer
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

        echo "Enter a number from ${minimum_value} to ${maximum_value}." >&2
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
        echo "" >&2
        echo "How should the password be shown?" >&2
        echo "1) Copy to clipboard (Recommended: avoids terminal history and plaintext files)" >&2
        echo "2) Save to a plaintext file" >&2
        echo "3) Echo to CLI output" >&2
        read -r -p "Choose delivery method [1]: " answer

        case "${answer:-1}" in
            1) echo "clipboard"; return 0 ;;
            2) echo "file"; return 0 ;;
            3) echo "terminal"; return 0 ;;
            *) echo "Choose 1, 2, or 3." >&2 ;;
        esac
    done
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
        echo "No supported clipboard utility was found." >&2
        return 1
    }

    local payload
    payload=$(printf '%s\n' "$@")

    case "$clipboard_command" in
        pbcopy) printf '%s' "$payload" | pbcopy ;;
        wl-copy) printf '%s' "$payload" | wl-copy ;;
        xclip) printf '%s' "$payload" | xclip -selection clipboard ;;
        xsel) printf '%s' "$payload" | xsel --clipboard --input ;;
        clip.exe) printf '%s' "$payload" | clip.exe ;;
        clip) printf '%s' "$payload" | clip ;;
    esac

    echo ""
    echo "Copied $# password(s) to the clipboard."
    echo "Paste them into the target secret manager now."

    local clear_clipboard
    clear_clipboard=$(read_yes_no_choice "Clear clipboard after you have pasted them? (recommended)" true)
    if [ "$clear_clipboard" = true ]; then
        case "$clipboard_command" in
            pbcopy) printf '' | pbcopy ;;
            wl-copy) printf '' | wl-copy ;;
            xclip) printf '' | xclip -selection clipboard ;;
            xsel) printf '' | xsel --clipboard --input ;;
            clip.exe) printf '' | clip.exe ;;
            clip) printf '' | clip ;;
        esac
        echo "Clipboard cleared."
    fi
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
    echo ""
    echo "Warning: this writes plaintext passwords to disk."

    local path
    read -r -p "File path [generated-passwords.txt]: " path
    path="${path:-generated-passwords.txt}"

    umask 077
    printf '%s\n' "$@" > "$path"
    echo "Saved $# password(s) to ${path}."
    echo "Delete or move this file into your secure secret storage as soon as possible."
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
    echo ""
    echo "Generated password(s):"
    printf '%s\n' "$@"
}

# invoke_safe_password_generator
#
# Runs the interactive safe password generation workflow.
#
# Returns:
#   0 after passwords are generated and delivered.
invoke_safe_password_generator() {
    echo ""
    echo "Safe Password Generator"
    echo "======================="
    echo ""
    echo "Special characters use this safe set: ${SAFE_SPECIAL_CHARS}"
    echo "Excluded: quotes, backslashes, whitespace, #, $, &, |, ;, <, >, brackets, equals"
    echo ""

    local include_special password_length password_count passwords delivery
    include_special=$(read_yes_no_choice "Include safe special characters?" true)
    password_length=$(read_integer_choice "Password length" "$DEFAULT_PASSWORD_LENGTH" "$MINIMUM_PASSWORD_LENGTH" 4096)
    password_count=$(read_integer_choice "Number of passwords to generate" "$DEFAULT_PASSWORD_COUNT" 1 100)
    mapfile -t passwords < <(new_safe_password_set "$password_length" "$password_count" "$include_special")

    while true; do
        delivery=$(read_delivery_choice)
        case "$delivery" in
            clipboard)
                if copy_passwords_to_clipboard "${passwords[@]}"; then
                    return 0
                fi
                echo "Please choose another delivery method." >&2
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
