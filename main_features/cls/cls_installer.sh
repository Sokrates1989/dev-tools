#!/bin/bash
#
# Entrypoint for the interactive cls terminal-cleaner setup workflow.
#

set -u

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=cls_core.sh
source "$SCRIPT_DIRECTORY/cls_core.sh"
# shellcheck source=cls_ui.sh
source "$SCRIPT_DIRECTORY/cls_ui.sh"

initialize_cls_messages "$SCRIPT_DIRECTORY" || {
    printf 'Unable to load cls message catalog.\n' >&2
    exit 1
}

case "${1:-}" in
    --help|-h|help)
        show_cls_help
        ;;
    "")
        invoke_cls_setup
        ;;
    *)
        printf '%s\n' "$(format_cls_message error.unknown_option "$1")" >&2
        show_cls_help >&2
        exit 1
        ;;
esac
