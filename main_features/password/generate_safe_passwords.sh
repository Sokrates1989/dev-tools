#!/bin/bash
#
# Safe production password generator entrypoint.
#
# Loads the password generator core and interactive UI modules, then runs the
# menu workflow unless help was requested.
#
# Dependencies:
#   - password_core.sh
#   - password_ui.sh
#

set -euo pipefail

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

#
# Module loading.
# Core owns cryptographic generation; UI owns prompts and delivery behavior.
#
# shellcheck source-path=SCRIPTDIR
# shellcheck source=password_core.sh
source "${SCRIPT_DIR}/password_core.sh"
# The runtime-resolved sibling path is validated by syntax and behavior tests.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/password_ui.sh"

case "${1:-}" in
    --help|-h)
        show_password_generator_help
        exit 0
        ;;
    "")
        invoke_safe_password_generator
        ;;
    *)
        format_password_message unknown_option "$1" >&2
        printf '\n' >&2
        show_password_generator_help >&2
        exit 1
        ;;
esac
