#!/bin/bash
#
# Audits the authenticated GitHub account's owned repository subscriptions.
#
# GitHub CLI owns authentication and REST transport. This script remains
# read-only and never attempts to infer granular Custom notification choices.
#

set -u

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIRECTORY}/../.." && pwd)"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=../../global_functions/update_manager.sh
source "${REPOSITORY_ROOT}/global_functions/update_manager.sh"

GITHUB_NOTIFICATIONS_API_VERSION="2026-03-10"
GITHUB_NOTIFICATIONS_GH_COMMAND="${GITHUB_NOTIFICATIONS_GH_COMMAND:-gh}"
GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE="error"

# Loads GitHub Notification Audit messages from the shared root catalog.
initialize_github_notifications_messages() {
    initialize_dev_tools_update_messages "$REPOSITORY_ROOT"
}

# Invokes the configured GitHub CLI command. Tests replace it with a fake.
run_github_notifications_gh() {
    "$GITHUB_NOTIFICATIONS_GH_COMMAND" "$@"
}

# Prints the platform-appropriate GitHub CLI installation guidance.
show_github_notifications_install_instructions() {
    local operating_system
    operating_system=$(uname -s 2>/dev/null || printf 'Unknown')

    case "$operating_system" in
        Darwin)
            printf '%s\n' "$(get_dev_tools_update_message github_notifications.install.macos)"
            printf '  brew install gh\n'
            ;;
        MINGW*|MSYS*|CYGWIN*)
            printf '%s\n' "$(get_dev_tools_update_message github_notifications.install.windows)"
            printf '  winget install --id GitHub.cli --source winget\n'
            ;;
        *)
            printf '%s\n' "$(get_dev_tools_update_message github_notifications.install.linux)"
            printf '  https://github.com/cli/cli/blob/trunk/docs/install_linux.md\n'
            ;;
    esac
}

# Prints focused command help without contacting GitHub.
show_github_notifications_help() {
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.title)"
    printf '%s\n\n' "$(get_dev_tools_update_message github_notifications.title_divider)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.help.usage)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.help.description)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.help.read_only)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.help.custom_limit)"
}

# Classifies one documented repository-subscription response.
#
# Arguments:
#   $1 - repository: owner/name identity returned by the authenticated API.
#
# Global state:
#   Sets GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE to subscribed,
#   not-subscribed, ignored, or error.
#
# Returns:
#   0 for a recognized subscription state; 1 for transport or response errors.
get_github_notifications_subscription_state() {
    local repository="$1"
    local response exit_code status="" subscribed="" ignored="" line

    GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE="error"
    if response=$(run_github_notifications_gh api --include \
        -H 'Accept: application/vnd.github+json' \
        -H "X-GitHub-Api-Version: ${GITHUB_NOTIFICATIONS_API_VERSION}" \
        "repos/${repository}/subscription" \
        --jq '[.subscribed, .ignored] | @tsv' 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^HTTP/[0-9.]+[[:space:]]+([0-9]{3}) ]]; then
            status="${BASH_REMATCH[1]}"
        elif [ -z "$status" ] && [[ "$line" =~ HTTP[[:space:]]+([0-9]{3}) ]]; then
            status="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^(true|false)$'\t'(true|false)$ ]]; then
            subscribed="${BASH_REMATCH[1]}"
            ignored="${BASH_REMATCH[2]}"
        fi
    done <<< "$response"

    if [ "$status" = "404" ]; then
        GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE="not-subscribed"
        return 0
    fi
    if [ "$exit_code" -ne 0 ] || [ "$status" != "200" ]; then
        return 1
    fi
    if [ "$ignored" = "true" ]; then
        GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE="ignored"
        return 0
    fi
    if [ "$subscribed" = "true" ] && [ "$ignored" = "false" ]; then
        GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE="subscribed"
        return 0
    fi

    return 1
}

# Prints repositories in one attention category with copyable GitHub URLs.
#
# Arguments:
#   $1 - heading_key: localized heading catalog key.
#   Remaining arguments - owner/name repository identities.
show_github_notifications_repository_list() {
    local heading_key="$1" repository
    shift

    printf '\n%s\n' "$(get_dev_tools_update_message "$heading_key")"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.list.divider)"
    for repository in "$@"; do
        printf -- '- %s\n  https://github.com/%s\n' "$repository" "$repository"
    done
}

# Runs the complete read-only audit and prints its localized summary.
#
# Returns:
#   0 when the audit completed, including attention findings; 1 when a
#   prerequisite or API error made the result incomplete.
invoke_github_notifications_audit() {
    local account_result account repository_result line
    local repository archived private state
    local checked=0 subscribed_count=0 archived_count=0 private_count=0 error_count=0
    local -a subscribed_repositories=()
    local -a not_subscribed_repositories=()
    local -a ignored_repositories=()
    local -a error_repositories=()

    printf '%s\n' "$(get_dev_tools_update_message github_notifications.title)"
    printf '%s\n\n' "$(get_dev_tools_update_message github_notifications.title_divider)"

    if ! command -v "$GITHUB_NOTIFICATIONS_GH_COMMAND" >/dev/null 2>&1; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.gh_missing)" >&2
        printf '%s\n\n' "$(get_dev_tools_update_message github_notifications.git_auth_insufficient)" >&2
        show_github_notifications_install_instructions >&2
        return 1
    fi

    if ! run_github_notifications_gh auth status --active --hostname github.com >/dev/null 2>&1; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.not_authenticated)" >&2
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.authenticate_with)" >&2
        printf '  gh auth login\n' >&2
        return 1
    fi

    if ! account_result=$(run_github_notifications_gh api \
        -H 'Accept: application/vnd.github+json' \
        -H "X-GitHub-Api-Version: ${GITHUB_NOTIFICATIONS_API_VERSION}" \
        user --jq '.login' 2>&1); then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.account)" >&2
        return 1
    fi
    account="${account_result%$'\r'}"
    if [ -z "$account" ] || [[ "$account" == *$'\n'* ]]; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.account)" >&2
        return 1
    fi

    printf '%s\n' "$(format_dev_tools_update_message github_notifications.audit_progress "$account")"
    if ! repository_result=$(run_github_notifications_gh api --paginate \
        -H 'Accept: application/vnd.github+json' \
        -H "X-GitHub-Api-Version: ${GITHUB_NOTIFICATIONS_API_VERSION}" \
        'user/repos?affiliation=owner&visibility=all&per_page=100&sort=full_name&direction=asc' \
        --jq '.[] | [.full_name, (.archived | tostring), (.private | tostring)] | @tsv' 2>&1); then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.repositories)" >&2
        return 1
    fi

    while IFS=$'\t' read -r repository archived private || [ -n "$repository" ]; do
        repository="${repository%$'\r'}"
        archived="${archived%$'\r'}"
        private="${private%$'\r'}"
        [ -n "$repository" ] || continue
        if { [ "$archived" != "true" ] && [ "$archived" != "false" ]; } ||
            { [ "$private" != "true" ] && [ "$private" != "false" ]; }; then
            printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.repositories)" >&2
            return 1
        fi

        if [ "$archived" = "true" ]; then
            archived_count=$((archived_count + 1))
            continue
        fi
        checked=$((checked + 1))
        if [ "$private" = "true" ]; then
            private_count=$((private_count + 1))
        fi

        if get_github_notifications_subscription_state "$repository"; then
            state="$GITHUB_NOTIFICATIONS_SUBSCRIPTION_STATE"
        else
            state="error"
        fi
        case "$state" in
            subscribed)
                subscribed_count=$((subscribed_count + 1))
                subscribed_repositories+=("$repository")
                ;;
            not-subscribed) not_subscribed_repositories+=("$repository") ;;
            ignored) ignored_repositories+=("$repository") ;;
            *)
                error_count=$((error_count + 1))
                error_repositories+=("$repository")
                ;;
        esac
    done <<< "$repository_result"

    printf '\n%s\n' "$(format_dev_tools_update_message github_notifications.summary.account "$account")"
    printf '\n%s\n' "$(format_dev_tools_update_message github_notifications.summary.checked "$checked")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.subscribed "$subscribed_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.not_subscribed "${#not_subscribed_repositories[@]}")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.ignored "${#ignored_repositories[@]}")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.private "$private_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.archived "$archived_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.errors "$error_count")"

    if [ "$subscribed_count" -gt 0 ]; then
        printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.subscribed_note)"
        show_github_notifications_repository_list \
            github_notifications.heading.subscribed \
            "${subscribed_repositories[@]}"
    fi
    if [ "${#not_subscribed_repositories[@]}" -gt 0 ]; then
        show_github_notifications_repository_list \
            github_notifications.heading.not_subscribed \
            "${not_subscribed_repositories[@]}"
    fi
    if [ "${#ignored_repositories[@]}" -gt 0 ]; then
        show_github_notifications_repository_list \
            github_notifications.heading.ignored \
            "${ignored_repositories[@]}"
    fi
    if [ "${#error_repositories[@]}" -gt 0 ]; then
        show_github_notifications_repository_list \
            github_notifications.heading.errors \
            "${error_repositories[@]}"
    fi

    printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.heading)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.path)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.issues)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.pull_requests)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.security_alerts)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.recommendation.limit)"

    printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.management.heading)"
    printf 'https://github.com/watching\n'

    [ "$error_count" -eq 0 ]
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    initialize_github_notifications_messages || {
        printf 'Unable to load GitHub Notification Audit messages.\n' >&2
        exit 1
    }

    case "${1:-}" in
        --help|-h|help)
            show_github_notifications_help
            ;;
        "")
            invoke_github_notifications_audit
            ;;
        *)
            format_dev_tools_update_message github_notifications.error.unknown_option "$1" >&2
            printf '\n' >&2
            show_github_notifications_help >&2
            exit 1
            ;;
    esac
fi
