#!/bin/bash
#
# Reports disk usage and prunes resources in the current Docker context.
# Docker handles the final confirmation after the optional volume prompt.
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

prune_arguments=(system prune -a)
printf '%s ' "$(get_dev_tools_update_message docker_cleanup.volumes_prompt)" >&2
if ! IFS= read -r answer; then
    printf '\n%s\n' "$(get_dev_tools_update_message docker_cleanup.input_closed)" >&2
    exit 1
fi
if [[ "$answer" == [yY] ]]; then
    prune_arguments+=(--volumes)
fi

docker system df
docker "${prune_arguments[@]}"
docker system df
