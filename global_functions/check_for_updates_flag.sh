#!/bin/bash
#
# Returns 1 only when a clean main checkout is strictly behind the official
# configured upstream. All unsafe, ambiguous, cached, or offline states return 0.
#

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=global_functions/update_manager.sh
source "${SCRIPT_DIR}/update_manager.sh"
get_dev_tools_update_state "$ROOT_DIR" false

if [ "$DEV_TOOLS_UPDATE_STATE" = "behind" ]; then
    printf '1\n'
else
    printf '0\n'
fi
