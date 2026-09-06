#!/bin/bash
#
# Shell detection and safe profile persistence for the cls terminal cleaner.
#
# This library never prompts. Callers decide whether the user authorized a
# profile change before invoking install_cls_managed_block.
#

CLS_MANAGED_BEGIN="# dev-tools cls helper - begin."
CLS_MANAGED_END="# dev-tools cls helper - end."
CLS_PRINTF_COMMAND="printf '\\033[H\\033[2J\\033[3J'"
CLS_ALIAS_LINE="alias cls=\"$CLS_PRINTF_COMMAND\""
CLS_PROFILE_STATE=""
CLS_EXISTING_KIND=""

# Prints the operating-system name used by the setup summary.
detect_cls_os() {
    local kernel
    kernel="${DEV_TOOLS_CLS_OS:-$(uname -s 2>/dev/null || printf 'unknown')}"

    case "$kernel" in
        Darwin*) printf 'macOS' ;;
        Linux*) printf 'Linux' ;;
        MINGW*|MSYS*|CYGWIN*|Windows*) printf 'Windows' ;;
        *) printf '%s' "$kernel" ;;
    esac
}

# Normalizes a shell path or process name to one supported shell identifier.
normalize_cls_shell() {
    local shell_name
    shell_name="${1##*/}"
    shell_name="${shell_name#-}"
    shell_name="${shell_name%.exe}"
    shell_name=$(printf '%s' "$shell_name" | tr '[:upper:]' '[:lower:]')

    case "$shell_name" in
        bash|zsh|sh|ash) printf '%s' "$shell_name" ;;
        dash) printf 'sh' ;;
        *) return 1 ;;
    esac
}

# Detects the user's shell from an override, SHELL, or nearby parent process.
detect_cls_shell() {
    local candidate parent_pid attempt

    if [ -n "${DEV_TOOLS_CLS_SHELL:-}" ]; then
        normalize_cls_shell "$DEV_TOOLS_CLS_SHELL" || printf 'unknown'
        return 0
    fi
    if [ -n "${SHELL:-}" ]; then
        normalize_cls_shell "$SHELL" || printf 'unknown'
        return 0
    fi

    if command -v ps >/dev/null 2>&1; then
        parent_pid="$PPID"
        for attempt in 1 2; do
            candidate=$(ps -p "$parent_pid" -o comm= 2>/dev/null || true)
            if [ -n "$candidate" ] && normalize_cls_shell "$candidate"; then
                return 0
            fi
            parent_pid=$(ps -p "$parent_pid" -o ppid= 2>/dev/null | tr -d '[:space:]')
            [ -n "$parent_pid" ] || break
        done
    fi

    printf 'unknown'
}

# Prints a display label for a normalized shell identifier.
get_cls_shell_label() {
    case "$1" in
        bash) printf 'Bash' ;;
        zsh) printf 'Zsh' ;;
        sh) printf 'POSIX sh' ;;
        ash) printf 'BusyBox ash' ;;
        *) printf 'Unknown' ;;
    esac
}

# Resolves the supported per-user startup file for a shell.
resolve_cls_profile() {
    local shell_name="$1"
    local home_directory="${2:-${HOME:-}}"

    case "$shell_name" in
        bash|zsh|sh|ash) ;;
        *) return 1 ;;
    esac
    if [ -n "${DEV_TOOLS_CLS_PROFILE_PATH:-}" ]; then
        printf '%s' "$DEV_TOOLS_CLS_PROFILE_PATH"
        return 0
    fi
    [ -n "$home_directory" ] || return 1

    case "$shell_name" in
        bash) printf '%s/.bashrc' "$home_directory" ;;
        zsh) printf '%s/.zshrc' "$home_directory" ;;
        sh|ash) printf '%s/.profile' "$home_directory" ;;
    esac
}

# Prints the owned configuration block installed in Unix shell profiles.
get_cls_managed_block() {
    printf '%s\n%s\n%s' "$CLS_MANAGED_BEGIN" "$CLS_ALIAS_LINE" "$CLS_MANAGED_END"
}

# Prints the command the user must run in the parent shell after installation.
get_cls_reload_command() {
    local shell_name="$1"
    case "$shell_name" in
        bash) printf 'source ~/.bashrc' ;;
        zsh) printf 'source ~/.zshrc' ;;
        sh|ash) printf '. ~/.profile' ;;
        *) return 1 ;;
    esac
}

# Classifies the managed block in a profile and updates CLS_PROFILE_STATE.
get_cls_profile_state() {
    local profile_path="$1"
    local begin_count end_count begin_line end_line existing_block expected_block

    if [ ! -f "$profile_path" ]; then
        CLS_PROFILE_STATE="absent"
        return 0
    fi

    begin_count=$(awk -v marker="$CLS_MANAGED_BEGIN" '{ sub(/\r$/, ""); if ($0 == marker) count++ } END { print count + 0 }' "$profile_path")
    end_count=$(awk -v marker="$CLS_MANAGED_END" '{ sub(/\r$/, ""); if ($0 == marker) count++ } END { print count + 0 }' "$profile_path")
    if [ "$begin_count" -eq 0 ] && [ "$end_count" -eq 0 ]; then
        CLS_PROFILE_STATE="unmanaged"
        return 0
    fi
    if [ "$begin_count" -ne 1 ] || [ "$end_count" -ne 1 ]; then
        CLS_PROFILE_STATE="malformed"
        return 0
    fi

    begin_line=$(awk -v marker="$CLS_MANAGED_BEGIN" '{ sub(/\r$/, ""); if ($0 == marker) { print NR; exit } }' "$profile_path")
    end_line=$(awk -v marker="$CLS_MANAGED_END" '{ sub(/\r$/, ""); if ($0 == marker) { print NR; exit } }' "$profile_path")
    if [ "$begin_line" -ge "$end_line" ]; then
        CLS_PROFILE_STATE="malformed"
        return 0
    fi

    existing_block=$(awk -v begin="$CLS_MANAGED_BEGIN" -v end="$CLS_MANAGED_END" '
        { sub(/\r$/, "") }
        $0 == begin { inside = 1 }
        inside { print }
        $0 == end && inside { exit }
    ' "$profile_path")
    expected_block=$(get_cls_managed_block)

    if [ "$existing_block" = "$expected_block" ]; then
        CLS_PROFILE_STATE="current"
    else
        CLS_PROFILE_STATE="stale"
    fi
}

# Detects a non-dev-tools cls definition and updates CLS_EXISTING_KIND.
detect_existing_cls() {
    local profile_path="$1"
    local shell_description
    CLS_EXISTING_KIND="none"

    if [ -f "$profile_path" ] && awk -v begin="$CLS_MANAGED_BEGIN" -v end="$CLS_MANAGED_END" '
        { normalized = $0; sub(/\r$/, "", normalized) }
        normalized == begin { inside = 1; next }
        normalized == end && inside { inside = 0; next }
        !inside { print }
    ' "$profile_path" | grep -Eq \
        '^[[:space:]]*(alias[[:space:]]+cls=|function[[:space:]]+cls([[:space:]]*\(\))?([[:space:]]*\{|[[:space:]]*$)|cls[[:space:]]*\(\)[[:space:]]*\{)'; then
        CLS_EXISTING_KIND="profile"
        return 0
    fi

    shell_description=$(command -V cls 2>/dev/null || true)
    if [ -n "$shell_description" ]; then
        CLS_EXISTING_KIND="command"
    fi
}

# Prints a string using the line-ending convention detected in a profile.
write_cls_line() {
    local value="$1"
    local newline="$2"
    printf '%s%s' "$value" "$newline"
}

# Prints the managed block with the requested profile line ending.
write_cls_managed_block() {
    local newline="$1"
    write_cls_line "$CLS_MANAGED_BEGIN" "$newline" &&
        write_cls_line "$CLS_ALIAS_LINE" "$newline" &&
        write_cls_line "$CLS_MANAGED_END" "$newline"
}

# Replaces the single managed block in a regular profile file.
replace_cls_managed_block() {
    local profile_path="$1"
    local newline="$2"
    local placement="${3:-in-place}"
    local temporary_path line inside mode
    inside="false"

    if [ -L "$profile_path" ]; then
        return 2
    fi

    temporary_path=$(mktemp "${profile_path}.dev-tools-cls.XXXXXX") || return 1
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [ "$line" = "$CLS_MANAGED_BEGIN" ]; then
            if [ "$placement" = "in-place" ]; then
                write_cls_managed_block "$newline"
            fi
            inside="true"
        elif [ "$line" = "$CLS_MANAGED_END" ] && [ "$inside" = "true" ]; then
            inside="false"
        elif [ "$inside" = "false" ]; then
            write_cls_line "$line" "$newline"
        fi
    done < "$profile_path" > "$temporary_path"

    if [ "$placement" = "append" ]; then
        if ! write_cls_line "" "$newline" >> "$temporary_path" ||
            ! write_cls_managed_block "$newline" >> "$temporary_path"; then
            rm -f -- "$temporary_path"
            return 1
        fi
    fi

    if mode=$(stat -c '%a' "$profile_path" 2>/dev/null); then
        chmod "$mode" "$temporary_path"
    elif mode=$(stat -f '%Lp' "$profile_path" 2>/dev/null); then
        chmod "$mode" "$temporary_path"
    fi

    if ! mv -f -- "$temporary_path" "$profile_path"; then
        rm -f -- "$temporary_path"
        return 1
    fi
}

# Installs or updates only the dev-tools-owned block in a shell profile.
install_cls_managed_block() {
    local profile_path="$1"
    local force_append="${2:-false}"
    local profile_directory newline

    get_cls_profile_state "$profile_path"
    case "$CLS_PROFILE_STATE" in
        current)
            if [ "$force_append" != "true" ]; then
                return 0
            fi
            ;;
        malformed) return 3 ;;
    esac

    profile_directory=$(dirname "$profile_path")
    mkdir -p -- "$profile_directory" || return 1

    if [ ! -e "$profile_path" ]; then
        get_cls_managed_block > "$profile_path" || return 1
        printf '\n' >> "$profile_path" || return 1
        return 0
    fi
    [ -f "$profile_path" ] || return 1

    if grep -q $'\r$' "$profile_path" 2>/dev/null; then
        newline=$'\r\n'
    else
        newline=$'\n'
    fi

    if [ "$force_append" = "true" ] && { [ "$CLS_PROFILE_STATE" = "current" ] || [ "$CLS_PROFILE_STATE" = "stale" ]; }; then
        replace_cls_managed_block "$profile_path" "$newline" append
        return $?
    fi
    if [ "$CLS_PROFILE_STATE" = "stale" ]; then
        replace_cls_managed_block "$profile_path" "$newline" in-place
        return $?
    fi

    if [ -s "$profile_path" ]; then
        write_cls_line "" "$newline" >> "$profile_path" || return 1
    fi
    write_cls_managed_block "$newline" >> "$profile_path" || return 1
}
