#!/bin/bash
#
# Runs mocked regression tests for the Bash GitHub Notification Audit.
#
# No request reaches GitHub and no repository subscription is changed.
#

set -euo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIRECTORY="$(cd "${TEST_DIRECTORY}/.." && pwd)"
REPOSITORY_ROOT="$(cd "${FEATURE_DIRECTORY}/../.." && pwd)"

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=github_notifications.sh
source "${FEATURE_DIRECTORY}/github_notifications.sh"

# Fails when two scalar values differ.
assert_equal() {
    local expected="$1" actual="$2" context="$3"
    if [ "$expected" != "$actual" ]; then
        printf '%s. Expected %q, received %q.\n' "$context" "$expected" "$actual" >&2
        return 1
    fi
}

# Fails when a text block does not contain an expected literal value.
assert_contains() {
    local expected="$1" actual="$2" context="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        printf '%s. Missing text: %q.\n' "$context" "$expected" >&2
        return 1
    fi
}

# Fails when a text block contains a forbidden literal value.
assert_not_contains() {
    local unexpected="$1" actual="$2" context="$3"
    if [[ "$actual" == *"$unexpected"* ]]; then
        printf '%s. Unexpected text: %q.\n' "$context" "$unexpected" >&2
        return 1
    fi
}

# Fakes the gh command for authentication, pagination, and subscription states.
gh() {
    local joined=" $* " argument endpoint=""
    if [ "${GH_MOCK_SCENARIO:-}" = "unauthenticated" ] &&
        [[ "$joined" == *" auth status "* ]]; then
        return 1
    fi
    if [[ "$joined" == *" auth status "* ]]; then
        return 0
    fi
    if [[ "$joined" == *" user/repos?"* ]]; then
        if [[ "$joined" != *" --paginate "* ]]; then
            return 70
        fi
        printf '%s\t%s\t%s\n' \
            'audit-user/subscribed' false false \
            'audit-user/not-subscribed' false false \
            'audit-user/ignored' false true \
            'audit-user/api-error' false false \
            'audit-user/archived' true true
        return 0
    fi
    if [[ "$joined" == *" api "* && "$joined" == *" user "* ]]; then
        printf 'audit-user\n'
        return 0
    fi

    for argument in "$@"; do
        case "$argument" in
            repos/*/subscription) endpoint="$argument" ;;
        esac
    done
    case "$endpoint" in
        repos/audit-user/subscribed/subscription)
            printf 'HTTP/2.0 200 OK\n\ntrue\tfalse\n'
            return 0
            ;;
        repos/audit-user/not-subscribed/subscription)
            printf 'HTTP/2.0 404 Not Found\n'
            printf 'gh: Not Found (HTTP 404)\n' >&2
            return 1
            ;;
        repos/audit-user/ignored/subscription)
            printf 'HTTP/2.0 200 OK\n\nfalse\ttrue\n'
            return 0
            ;;
        repos/audit-user/api-error/subscription)
            printf 'HTTP/2.0 403 Forbidden\n'
            printf 'gh: Forbidden (HTTP 403)\n' >&2
            return 1
            ;;
        repos/audit-user/archived/subscription)
            printf 'Archived repositories must not be checked.\n' >&2
            return 99
            ;;
    esac
    return 64
}

export DEV_TOOLS_LOCALE=en
initialize_github_notifications_messages

GITHUB_NOTIFICATIONS_GH_COMMAND=definitely-missing-gh-for-test
set +e
missing_output=$(invoke_github_notifications_audit 2>&1)
missing_status=$?
set -e
assert_equal 1 "$missing_status" 'Missing gh did not fail cleanly'
assert_contains 'GitHub CLI (gh) is not installed.' "$missing_output" 'Missing gh explanation changed'
assert_contains 'Normal git authentication is not sufficient' "$missing_output" 'Git authentication distinction is missing'
assert_not_contains 'gh auth login' "$missing_output" 'Missing gh was treated as an authentication-only problem'

GITHUB_NOTIFICATIONS_GH_COMMAND=gh
GH_MOCK_SCENARIO=unauthenticated
set +e
unauthenticated_output=$(invoke_github_notifications_audit 2>&1)
unauthenticated_status=$?
set -e
assert_equal 1 "$unauthenticated_status" 'Unauthenticated gh did not fail cleanly'
assert_contains 'gh auth login' "$unauthenticated_output" 'Authentication guidance is missing'

GH_MOCK_SCENARIO=audit
set +e
audit_output=$(invoke_github_notifications_audit 2>&1)
audit_status=$?
set -e
assert_equal 1 "$audit_status" 'Per-repository API errors did not mark the audit incomplete'
assert_contains 'Account: audit-user' "$audit_output" 'Authenticated account is missing'
assert_contains 'Repositories checked: 4' "$audit_output" 'Active repository count changed'
assert_contains 'Subscribed:           1' "$audit_output" 'Subscribed state changed'
assert_contains 'Not subscribed:       1' "$audit_output" 'HTTP 404 classification changed'
assert_contains 'Ignored:              1' "$audit_output" 'Ignored state changed'
assert_contains 'Private (included):   1' "$audit_output" 'Private repository inclusion changed'
assert_contains 'Archived/skipped:     1' "$audit_output" 'Archived skip count changed'
assert_contains 'Errors:               1' "$audit_output" 'API error count changed'
assert_contains 'Subscribed — exact Custom event categories cannot be verified via the GitHub API.' "$audit_output" 'Custom-category limitation is missing'
assert_contains 'https://github.com/audit-user/not-subscribed' "$audit_output" 'Not-subscribed URL is missing'
assert_contains 'https://github.com/audit-user/ignored' "$audit_output" 'Ignored URL is missing'
assert_contains 'https://github.com/audit-user/api-error' "$audit_output" 'API-error URL is missing'
assert_not_contains 'https://github.com/audit-user/archived' "$audit_output" 'Archived repository was not skipped'
assert_contains '[x] Issues' "$audit_output" 'Recommended Issues configuration is missing'
assert_contains '[x] Pull requests' "$audit_output" 'Recommended Pull requests configuration is missing'
assert_contains '[x] Security alerts' "$audit_output" 'Recommended Security alerts configuration is missing'

launcher_content=$(<"${REPOSITORY_ROOT}/start.sh")
assert_contains '--github-notifications|--gh-notifications|--gn)' "$launcher_content" 'Bash quick-command routing is missing'
assert_contains 'main_features/github-notifications/github_notifications.sh' "$launcher_content" 'Bash feature path is missing'
assert_contains '17|"cls"|"--cls")' "$launcher_content" 'Bash interactive menu numbering changed unexpectedly'

english_keys=$(grep -E '^[^#].*=' "${REPOSITORY_ROOT}/locales/en.properties" | cut -d= -f1)
german_keys=$(grep -E '^[^#].*=' "${REPOSITORY_ROOT}/locales/de.properties" | cut -d= -f1)
assert_equal "$english_keys" "$german_keys" 'Root locale key sets differ'

printf 'Bash GitHub Notification Audit tests passed.\n'
