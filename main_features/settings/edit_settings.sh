#!/bin/bash
# -----------------------------------------------------------------------------
# Script: edit_settings.sh
# Author: Patrick Michiels
# Date: 2026-05-04
# Version: 1.0.0
#
# Description:
#     Lets the user edit the dev-tools .env settings/config file.
#     Offers three options:
#       1) Inline terminal editor (nano/vim/vi/$EDITOR — first available)
#       2) Default GUI editor (xdg-open / open / explorer)
#       3) Reveal the .env file's parent folder in the system file manager
#
#     If .env is missing but .env.template exists, the user is offered the
#     chance to bootstrap .env from the template before editing.
#
# Usage:
#     bash edit_settings.sh
# -----------------------------------------------------------------------------

set -u

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ENV_TEMPLATE="$ROOT_DIR/.env.template"

# -----------------------------------------------------------------------------
# detect_platform
#
# Detects the current OS family for picking GUI helpers.
#
# Returns:
#     Echoes one of: "macos", "windows", "linux", "unknown"
# -----------------------------------------------------------------------------
detect_platform() {
    case "$(uname -s)" in
        Darwin*)                echo "macos" ;;
        MINGW*|MSYS*|CYGWIN*)   echo "windows" ;;
        Linux*)
            # WSL still reports Linux but has explorer.exe available.
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "windows"
            else
                echo "linux"
            fi
            ;;
        *)                      echo "unknown" ;;
    esac
}

# -----------------------------------------------------------------------------
# ensure_env_file
#
# Verifies that the .env file exists. If it is missing but a .env.template
# exists, prompts the user to copy the template into place.
#
# Returns:
#     0 if .env is ready to edit, 1 if the user declined or no template exists.
# -----------------------------------------------------------------------------
ensure_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        return 0
    fi

    echo "⚠️  No .env file found at: $ENV_FILE"
    if [[ -f "$ENV_TEMPLATE" ]]; then
        read -p "📄 Copy .env.template → .env now? [Y/n] " reply
        reply="${reply:-Y}"
        if [[ "$reply" =~ ^[Yy] ]]; then
            cp "$ENV_TEMPLATE" "$ENV_FILE"
            echo "✅ Created $ENV_FILE from template."
            return 0
        fi
        echo "ℹ️  Skipped. Cannot edit a non-existent file."
        return 1
    fi

    echo "❌ No .env.template found either. Nothing to edit."
    return 1
}

# -----------------------------------------------------------------------------
# open_inline_editor
#
# Opens the .env file in a terminal editor. Honours $VISUAL/$EDITOR first,
# then falls back to nano, vim, vi, in that order.
# -----------------------------------------------------------------------------
open_inline_editor() {
    local editor=""
    if [[ -n "${VISUAL:-}" ]] && command -v "${VISUAL%% *}" >/dev/null 2>&1; then
        editor="$VISUAL"
    elif [[ -n "${EDITOR:-}" ]] && command -v "${EDITOR%% *}" >/dev/null 2>&1; then
        editor="$EDITOR"
    elif command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    fi

    if [[ -z "$editor" ]]; then
        echo "❌ No terminal editor found (tried \$VISUAL, \$EDITOR, nano, vim, vi)."
        echo "   Set the EDITOR environment variable or install nano/vim."
        return 1
    fi

    echo "📝 Opening $ENV_FILE in: $editor"
    # shellcheck disable=SC2086
    $editor "$ENV_FILE"
    echo "✅ Editor closed."
}

# -----------------------------------------------------------------------------
# open_gui_editor
#
# Opens the .env file in the OS default GUI handler for that file type.
# -----------------------------------------------------------------------------
open_gui_editor() {
    local platform
    platform="$(detect_platform)"
    echo "🖥️  Opening $ENV_FILE in the default GUI editor..."
    case "$platform" in
        macos)
            open -t "$ENV_FILE" 2>/dev/null || open "$ENV_FILE"
            ;;
        windows)
            # Convert path for Windows tools when running under Git Bash / WSL.
            local win_path="$ENV_FILE"
            if command -v cygpath >/dev/null 2>&1; then
                win_path="$(cygpath -w "$ENV_FILE")"
            elif command -v wslpath >/dev/null 2>&1; then
                win_path="$(wslpath -w "$ENV_FILE")"
            fi
            if command -v explorer.exe >/dev/null 2>&1; then
                explorer.exe "$win_path" || true
            elif command -v notepad.exe >/dev/null 2>&1; then
                notepad.exe "$win_path" &
            else
                echo "❌ Could not find explorer.exe or notepad.exe."
                return 1
            fi
            ;;
        linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$ENV_FILE" >/dev/null 2>&1 &
            else
                echo "❌ xdg-open not found. Install xdg-utils or use the inline editor."
                return 1
            fi
            ;;
        *)
            echo "❌ Unsupported platform: $platform"
            return 1
            ;;
    esac
    echo "✅ Launched. Save the file in your editor to apply changes."
}

# -----------------------------------------------------------------------------
# open_folder
#
# Reveals the directory containing .env in the system file manager.
# -----------------------------------------------------------------------------
open_folder() {
    local platform
    platform="$(detect_platform)"
    echo "📂 Opening folder: $ROOT_DIR"
    case "$platform" in
        macos)
            open "$ROOT_DIR"
            ;;
        windows)
            local win_path="$ROOT_DIR"
            if command -v cygpath >/dev/null 2>&1; then
                win_path="$(cygpath -w "$ROOT_DIR")"
            elif command -v wslpath >/dev/null 2>&1; then
                win_path="$(wslpath -w "$ROOT_DIR")"
            fi
            if command -v explorer.exe >/dev/null 2>&1; then
                explorer.exe "$win_path" || true
            else
                echo "❌ explorer.exe not available."
                return 1
            fi
            ;;
        linux)
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$ROOT_DIR" >/dev/null 2>&1 &
            else
                echo "❌ xdg-open not found. Install xdg-utils."
                return 1
            fi
            ;;
        *)
            echo "❌ Unsupported platform: $platform"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# main
#
# Prints the settings sub-menu and dispatches the chosen action.
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "⚙️  Dev Tools — Settings / Config"
    echo "================================="
    echo "Target file: $ENV_FILE"
    if [[ -f "$ENV_FILE" ]]; then
        echo "Status:      ✅ exists"
    else
        echo "Status:      ⚠️  missing"
    fi
    echo ""
    echo "How would you like to edit the settings?"
    echo "1) 📝 Inline terminal editor (nano / vim / \$EDITOR)"
    echo "2) 🖥️  Open .env in default GUI editor"
    echo "3) 📂 Reveal folder in file manager"
    echo "q) ↩️  Cancel"
    echo ""
    read -p "Enter your choice [1-3, q]: " sub_choice
    sub_choice="$(echo "$sub_choice" | tr '[:upper:]' '[:lower:]')"

    case "$sub_choice" in
        1|inline|nano|vim|vi|editor)
            ensure_env_file || return 1
            open_inline_editor
            ;;
        2|gui|open|edit)
            ensure_env_file || return 1
            open_gui_editor
            ;;
        3|folder|reveal|explorer|finder)
            open_folder
            ;;
        q|quit|exit|cancel|"")
            echo "↩️  Cancelled."
            ;;
        *)
            echo "❌ Invalid choice: $sub_choice"
            return 1
            ;;
    esac
}

main "$@"
