#!/bin/bash
#
# Renders the standalone Ubuntu installer and runs it when launched on Linux.
#

set -euo pipefail

feature_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(cd -- "$feature_dir/../.." && pwd)
# shellcheck source=../../global_functions/update_manager.sh
source "$root_dir/global_functions/update_manager.sh"
initialize_dev_tools_update_messages "$root_dir"

# Emits the paste-ready block with both catalogs embedded for offline setup.
print_udc_installer() {
    local line language
    while IFS= read -r line; do
        if [[ "$line" == '# UDC_MESSAGES' ]]; then
            for language in en de; do
                sed -n "s/^udc\./$language.udc./p" "$root_dir/locales/$language.properties" | tr -d '\r'
            done
        else
            printf '%s\n' "$line"
        fi
    done < "$feature_dir/install_udc.sh"
}

case "${1:-}" in
    --help|--h|-help|-h|help)
        get_dev_tools_update_message launcher.udc.usage
        get_dev_tools_update_message launcher.udc.description
        ;;
    --print)
        print_udc_installer
        ;;
    '')
        if [[ "$(uname -s)" != Linux ]]; then
            print_udc_installer
            exit 0
        fi
        print_udc_installer | bash
        case ":${PATH:-}:" in
            *":$HOME/.local/bin:"*) ;;
            *)
                # shellcheck disable=SC2016
                format_dev_tools_update_message launcher.udc.activate \
                    'export PATH="$HOME/.local/bin${PATH:+:$PATH}"'
                ;;
        esac
        ;;
    *)
        format_dev_tools_update_message launcher.udc.unknown_option "$1" >&2
        get_dev_tools_update_message launcher.udc.usage >&2
        exit 2
        ;;
esac
