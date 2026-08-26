#!/bin/bash
#
# Safely fast-forwards Dev Tools from its official configured upstream.
#
# Refuses dirty, ahead, diverged, detached, unexpected-branch, and
# unexpected-origin checkouts.
#

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=global_functions/update_manager.sh
source "${SCRIPT_DIR}/update_manager.sh"
initialize_dev_tools_update_messages "$ROOT_DIR"
invoke_dev_tools_update "$ROOT_DIR"
