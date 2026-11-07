#!/bin/bash
#
# Audits the authenticated GitHub account's owned repository subscriptions.
#
# GitHub CLI owns authentication and supported API transport. This script remains
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

# Loads GitHub Notification Audit messages from the shared root catalog.
initialize_github_notifications_messages() {
    initialize_dev_tools_update_messages "$REPOSITORY_ROOT"
}

# Invokes the configured GitHub CLI command. Tests replace it with a fake.
run_github_notifications_gh() {
    "$GITHUB_NOTIFICATIONS_GH_COMMAND" "$@"
}

# Reports the highest-precedence GitHub.com environment-token variable by name.
# Only presence is inspected; token values are never returned or printed.
get_github_notifications_environment_token_name() {
    if [ -n "${GH_TOKEN:-}" ]; then
        printf 'GH_TOKEN\n'
    elif [ -n "${GITHUB_TOKEN:-}" ]; then
        printf 'GITHUB_TOKEN\n'
    fi
}

# Explains which documented GitHub CLI credential source will be selected.
show_github_notifications_authentication_source() {
    local environment_token_name="$1"

    if [ -n "$environment_token_name" ]; then
        printf '%s\n' "$(format_dev_tools_update_message \
            github_notifications.auth.source.environment "$environment_token_name")"
    else
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.source.stored)"
    fi
}

# Prints Bash-specific ways to stop an environment token overriding gh login.
show_github_notifications_environment_token_mitigation() {
    local environment_token_name="$1"

    printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.environment_override)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.mitigation.heading)"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.mitigation.stored)"
    printf '  unset GH_TOKEN GITHUB_TOKEN\n'
    printf '  gh auth status --active --hostname github.com\n'
    printf '%s\n' "$(format_dev_tools_update_message \
        github_notifications.auth.mitigation.token "$environment_token_name")"
    printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.mitigation.retry)"
    printf '  dev-tools --gn\n'
}

# Prints safe API failure metadata and credential-specific recovery guidance.
show_github_notifications_api_diagnostics() {
    local detail="$1" environment_token_name="$2" exit_code="$3"
    local http_status=""

    printf '%s\n' "$(format_dev_tools_update_message \
        github_notifications.error.exit_code "$exit_code")"
    if [[ "$detail" =~ HTTP[[:space:]]+([0-9][0-9][0-9]) ]]; then
        http_status="${BASH_REMATCH[1]}"
    fi
    if [ -n "$http_status" ]; then
        printf '%s\n' "$(format_dev_tools_update_message \
            github_notifications.error.http_status "$http_status")"
    fi
    if [ -n "$environment_token_name" ]; then
        show_github_notifications_environment_token_mitigation "$environment_token_name"
    elif is_github_notifications_authentication_api_failure "$detail"; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.mitigation.refresh)"
        printf '  gh auth status --active --hostname github.com\n'
        printf '  gh auth refresh --hostname github.com\n'
    else
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.non_auth)"
    fi
}

# Reports whether gh returned an authentication or authorization HTTP status.
is_github_notifications_authentication_api_failure() {
    local detail="$1"
    [[ "$detail" =~ HTTP[[:space:]]+(401|403) ]]
}

# Reports whether prompting is safe for the current terminal.
is_github_notifications_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# Requests a localized yes/no decision without exposing credential values.
confirm_github_notifications_recovery() {
    local message_key="$1" default_yes="$2" message response
    shift 2

    message=$(format_dev_tools_update_message "$message_key" "$@")
    printf '%s ' "$message" >&2
    IFS= read -r response || return 1
    if [ -z "$response" ]; then
        [ "$default_yes" = "true" ]
        return
    fi
    case "$response" in
        y|Y|j|J|yes|Yes|YES|ja|Ja|JA) return 0 ;;
        *) return 1 ;;
    esac
}

# Runs an interactive gh authentication command with live terminal output.
run_github_notifications_gh_interactive() {
    run_github_notifications_gh "$@"
}

# Applies one explicitly confirmed recovery step before a single audit retry.
attempt_github_notifications_authentication_recovery() {
    local environment_token_name="$1" recovery_action="$2"
    local prompt_key running_key

    is_github_notifications_interactive || return 1
    if [ -n "$environment_token_name" ]; then
        confirm_github_notifications_recovery \
            github_notifications.auth.recovery.environment_prompt false \
            "$environment_token_name" || return 1
        unset GH_TOKEN GITHUB_TOKEN
    else
        case "$recovery_action" in
            login)
                prompt_key=github_notifications.auth.recovery.login_prompt
                running_key=github_notifications.auth.recovery.login_running
                ;;
            refresh)
                prompt_key=github_notifications.auth.recovery.refresh_prompt
                running_key=github_notifications.auth.recovery.refresh_running
                ;;
            *) return 1 ;;
        esac
        confirm_github_notifications_recovery "$prompt_key" true || return 1
        printf '%s\n' "$(get_dev_tools_update_message "$running_key")"
        if ! run_github_notifications_gh_interactive \
            auth "$recovery_action" --hostname github.com; then
            printf '%s\n' "$(get_dev_tools_update_message \
                github_notifications.auth.recovery.failed)" >&2
            return 1
        fi
    fi

    printf '%s\n' "$(get_dev_tools_update_message github_notifications.auth.recovery.retry)"
    return 0
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
    local recovery_attempted="${1:-false}"
    local account_result account account_status
    local repository_result repository_query repository_status line
    local repository archived private state can_subscribe
    local environment_token_name
    local checked=0 broad_count=0 custom_unknown_count=0 participating_count=0
    local archived_count=0 private_count=0 error_count=0
    local -a broad_repositories=()
    local -a custom_unknown_repositories=()
    local -a participating_repositories=()
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

    environment_token_name=$(get_github_notifications_environment_token_name)
    show_github_notifications_authentication_source "$environment_token_name"
    printf '\n'

    if ! run_github_notifications_gh auth status --active --hostname github.com >/dev/null 2>&1; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.not_authenticated)" >&2
        if [ -n "$environment_token_name" ]; then
            show_github_notifications_environment_token_mitigation "$environment_token_name" >&2
        else
            printf '%s\n' "$(get_dev_tools_update_message github_notifications.authenticate_with)" >&2
            printf '  gh auth login\n' >&2
        fi
        if [ "$recovery_attempted" = "false" ] &&
            attempt_github_notifications_authentication_recovery \
                "$environment_token_name" login; then
            invoke_github_notifications_audit true
            return $?
        fi
        return 1
    fi

    if account_result=$(run_github_notifications_gh api \
        -H 'Accept: application/vnd.github+json' \
        -H "X-GitHub-Api-Version: ${GITHUB_NOTIFICATIONS_API_VERSION}" \
        user --jq '.login' 2>&1); then
        :
    else
        account_status=$?
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.account)" >&2
        show_github_notifications_api_diagnostics \
            "$account_result" "$environment_token_name" "$account_status" >&2
        if [ "$recovery_attempted" = "false" ] &&
            { [ -n "$environment_token_name" ] ||
                is_github_notifications_authentication_api_failure "$account_result"; } &&
            attempt_github_notifications_authentication_recovery \
                "$environment_token_name" refresh; then
            invoke_github_notifications_audit true
            return $?
        fi
        return 1
    fi
    account="${account_result%$'\r'}"
    if [ -z "$account" ] || [[ "$account" == *$'\n'* ]]; then
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.account)" >&2
        return 1
    fi

    printf '%s\n' "$(format_dev_tools_update_message github_notifications.audit_progress "$account")"
    repository_query="
query(\$endCursor: String) {
  viewer {
    repositories(first: 100, after: \$endCursor, affiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { nameWithOwner isArchived isPrivate viewerSubscription viewerCanSubscribe }
      pageInfo { hasNextPage endCursor }
    }
  }
}"
    if repository_result=$(run_github_notifications_gh api graphql --paginate \
        -f "query=${repository_query}" \
        --jq '.data.viewer.repositories.nodes[] | [.nameWithOwner, (.isArchived | tostring), (.isPrivate | tostring), (.viewerSubscription | tostring), (.viewerCanSubscribe | tostring)] | @tsv' 2>&1); then
        :
    else
        repository_status=$?
        printf '%s\n' "$(get_dev_tools_update_message github_notifications.error.repositories)" >&2
        show_github_notifications_api_diagnostics \
            "$repository_result" "$environment_token_name" "$repository_status" >&2
        if [ "$recovery_attempted" = "false" ] &&
            { [ -n "$environment_token_name" ] ||
                is_github_notifications_authentication_api_failure "$repository_result"; } &&
            attempt_github_notifications_authentication_recovery \
                "$environment_token_name" refresh; then
            invoke_github_notifications_audit true
            return $?
        fi
        return 1
    fi

    while IFS=$'\t' read -r repository archived private state can_subscribe || [ -n "$repository" ]; do
        repository="${repository%$'\r'}"
        archived="${archived%$'\r'}"
        private="${private%$'\r'}"
        state="${state%$'\r'}"
        can_subscribe="${can_subscribe%$'\r'}"
        [ -n "$repository" ] || continue
        [ "$state" != "null" ] || state="UNREPRESENTED"
        if { [ "$archived" != "true" ] && [ "$archived" != "false" ]; } ||
            { [ "$private" != "true" ] && [ "$private" != "false" ]; } ||
            { [ "$can_subscribe" != "true" ] && [ "$can_subscribe" != "false" ]; }; then
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

        case "$state" in
            SUBSCRIBED)
                broad_count=$((broad_count + 1))
                broad_repositories+=("$repository")
                ;;
            UNSUBSCRIBED)
                participating_count=$((participating_count + 1))
                participating_repositories+=("$repository")
                ;;
            IGNORED) ignored_repositories+=("$repository") ;;
            UNREPRESENTED)
                if [ "$can_subscribe" = "true" ]; then
                    custom_unknown_count=$((custom_unknown_count + 1))
                    custom_unknown_repositories+=("$repository")
                else
                    error_count=$((error_count + 1))
                    error_repositories+=("$repository")
                fi
                ;;
            *)
                error_count=$((error_count + 1))
                error_repositories+=("$repository")
                ;;
        esac
    done <<< "$repository_result"

    printf '\n%s\n' "$(format_dev_tools_update_message github_notifications.summary.account "$account")"
    printf '\n%s\n' "$(format_dev_tools_update_message github_notifications.summary.checked "$checked")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.broad "$broad_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.custom_unknown "$custom_unknown_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.participating "$participating_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.ignored "${#ignored_repositories[@]}")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.private "$private_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.archived "$archived_count")"
    printf '%s\n' "$(format_dev_tools_update_message github_notifications.summary.errors "$error_count")"

    if [ "$broad_count" -gt 0 ]; then
        printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.broad_note)"
        show_github_notifications_repository_list \
            github_notifications.heading.broad \
            "${broad_repositories[@]}"
    fi
    if [ "$custom_unknown_count" -gt 0 ]; then
        printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.custom_unknown_note)"
        show_github_notifications_repository_list \
            github_notifications.heading.custom_unknown \
            "${custom_unknown_repositories[@]}"
    fi
    if [ "$participating_count" -gt 0 ]; then
        printf '\n%s\n' "$(get_dev_tools_update_message github_notifications.participating_note)"
        show_github_notifications_repository_list \
            github_notifications.heading.participating \
            "${participating_repositories[@]}"
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
        --help|--h|-help|-h|help)
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
