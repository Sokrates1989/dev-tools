#!/bin/bash
#
# Reports disk usage and prunes resources in the current Docker context.
# Dev Tools confirms the workflow and volume choice before Docker's own prompt.
#

set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../global_functions/update_manager.sh
source "$root_dir/global_functions/update_manager.sh"
initialize_dev_tools_update_messages "$root_dir"

if [[ $# -eq 1 ]]; then
    case "$1" in
        --help|--h|-help|-h|help)
            printf '%s\n' "$(get_dev_tools_update_message docker_cleanup.usage)" \
                "$(get_dev_tools_update_message docker_cleanup.description)"
            exit 0
            ;;
    esac
fi
if [[ $# -gt 0 ]]; then
    printf '%s\n' "$(get_dev_tools_update_message docker_cleanup.invalid_option)" \
        "$(get_dev_tools_update_message docker_cleanup.usage)" >&2
    exit 2
fi
if ! command -v docker >/dev/null; then
    printf '%s\n' "$(get_dev_tools_update_message docker_cleanup.docker_missing)" >&2
    exit 127
fi

# Displays the localized prompt ($1) and stores the reply in answer, or exits on EOF.
read_cleanup_answer() {
    printf '%s ' "$(get_dev_tools_update_message "$1")" >&2
    if ! IFS= read -r answer; then
        printf '\n%s\n' "$(get_dev_tools_update_message docker_cleanup.input_closed)" >&2
        exit 1
    fi
}

read_cleanup_answer docker_cleanup.continue_prompt
if [[ -n "$answer" && "$answer" != [yY] ]]; then
    printf '%s\n' "$(get_dev_tools_update_message docker_cleanup.canceled)"
    exit 0
fi

prune_arguments=(system prune -a)
read_cleanup_answer docker_cleanup.volumes_prompt
if [[ "$answer" == [yY] ]]; then
    prune_arguments+=(--volumes)
fi

docker system df
docker "${prune_arguments[@]}"
docker system df
