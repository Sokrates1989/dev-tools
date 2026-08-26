#!/bin/bash
#
# Reports safe Dev Tools update state without modifying the checkout.
#
# This compatibility entrypoint remains non-prompting because the top-level
# dispatcher owns the once-per-launch update prompt.
#

SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=global_functions/update_manager.sh
source "${SCRIPT_DIR}/update_manager.sh"
initialize_dev_tools_update_messages "$ROOT_DIR" || exit 0
is_dev_tools_interactive_session || exit 0

get_dev_tools_update_state "$ROOT_DIR" true
if [ "$DEV_TOOLS_UPDATE_STATE" = "behind" ]; then
    format_dev_tools_update_message updates.available "${DEV_TOOLS_UPDATE_LOCAL_COMMIT:0:7}" "${DEV_TOOLS_UPDATE_REMOTE_COMMIT:0:7}"
    printf '\n'
else
    write_dev_tools_update_state_notice
fi
