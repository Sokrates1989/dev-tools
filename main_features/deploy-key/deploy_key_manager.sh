#!/bin/bash
#
# Repository-specific SSH deploy-key manager entrypoint.
#
# Loads the core, interactive UI, and setup-instruction modules, then creates
# or safely reuses one ED25519 key identified by repository and hostname.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=deploy_key_core.sh
source "${SCRIPT_DIR}/deploy_key_core.sh"
# Runtime-resolved sibling paths are validated by syntax and behavior tests.
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/deploy_key_ui.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/deploy_key_instructions.sh"

initialize_deploy_key_messages "$REPOSITORY_ROOT"

case "${1:-}" in
    --help|-h|help)
        show_deploy_key_help
        ;;
    "")
        invoke_deploy_key_manager
        ;;
    *)
        format_deploy_key_message deploy_key.error.unknown_option "$1" >&2
        printf '\n' >&2
        show_deploy_key_help >&2
        exit 1
        ;;
esac
