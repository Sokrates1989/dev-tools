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
unset GH_TOKEN GITHUB_TOKEN

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

# Fakes the gh command for authentication and paginated GraphQL watch states.
gh() {
    local joined=" $* " index error_state=BROKEN literal_end_cursor=\$endCursor
    if { [ "${GH_MOCK_SCENARIO:-}" = "unauthenticated" ] ||
        [ "${GH_MOCK_SCENARIO:-}" = "recoverable-login" ]; } &&
        [[ "$joined" == *" auth status "* ]]; then
        return 1
    fi
    if [[ "$joined" == *" auth status "* ]]; then
        return 0
    fi
    if [[ "$joined" == *" api graphql "* ]]; then
        if [[ "$joined" != *" --paginate "* ]] ||
            [[ "$joined" != *'pageInfo'* ]] ||
            [[ "$joined" != *"$literal_end_cursor"* ]]; then
            return 70
        fi
        if [[ "$joined" == *'"UNREPRESENTED"'* ]]; then
            return 71
        fi
        if [ "${GH_MOCK_SCENARIO:-}" = "api-failure" ] ||
            [ "${GH_MOCK_SCENARIO:-}" = "recoverable-api-failure" ] ||
            { [ "${GH_MOCK_SCENARIO:-}" = "environment-recoverable" ] &&
                [ -n "${GITHUB_TOKEN:-}" ]; }; then
            printf 'gh: mock GraphQL access denied (HTTP 403)\n' >&2
            return 75
        fi
        if [ "${GH_MOCK_SCENARIO:-}" = "client-failure" ]; then
            printf 'function not defined: UNREPRESENTED/0\n' >&2
            return 1
        fi
        if [ "${GH_MOCK_SCENARIO:-}" = "recovered-audit" ] ||
            [ "${GH_MOCK_SCENARIO:-}" = "environment-recoverable" ]; then
            error_state=SUBSCRIBED
        fi
        printf '%s\t%s\t%s\t%s\t%s\n' \
            'audit-user/all-activity' false false SUBSCRIBED true \
            'Sokrates1989/thunderbird-ai' false true null true \
            'audit-user/participating' false false UNSUBSCRIBED true \
            'audit-user/ignored' false false IGNORED true \
            'audit-user/api-error' false false "$error_state" true \
            'audit-user/archived' true true SUBSCRIBED true
        for ((index = 1; index <= 101; index++)); do
            printf 'audit-user/bulk-%03d\tfalse\tfalse\tSUBSCRIBED\ttrue\n' "$index"
        done
        return 0
    fi
    if [[ "$joined" == *" api "* && "$joined" == *" user "* ]]; then
        printf 'audit-user\n'
        return 0
    fi
    return 64
}

MOCK_GITHUB_NOTIFICATIONS_INTERACTIVE=false
MOCK_GITHUB_NOTIFICATIONS_CONFIRM=false

is_github_notifications_interactive() {
    [ "$MOCK_GITHUB_NOTIFICATIONS_INTERACTIVE" = "true" ]
}

confirm_github_notifications_recovery() {
    [ "$MOCK_GITHUB_NOTIFICATIONS_CONFIRM" = "true" ]
}

run_github_notifications_gh_interactive() {
    if [ "${GH_MOCK_SCENARIO:-}" = "recoverable-login" ] &&
        [ "$*" = "auth login --hostname github.com" ]; then
        GH_MOCK_SCENARIO=recovered-audit
        return 0
    fi
    if [ "${GH_MOCK_SCENARIO:-}" = "recoverable-api-failure" ] &&
        [ "$*" = "auth refresh --hostname github.com" ]; then
        GH_MOCK_SCENARIO=recovered-audit
        return 0
    fi
    return 64
}

export DEV_TOOLS_LOCALE=en
initialize_github_notifications_messages

GH_TOKEN=hidden-primary-token
GITHUB_TOKEN=hidden-secondary-token
assert_equal GH_TOKEN "$(get_github_notifications_environment_token_name)" 'GH_TOKEN precedence changed'
unset GH_TOKEN GITHUB_TOKEN

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

GH_MOCK_SCENARIO=api-failure
GITHUB_TOKEN=hidden-mock-token
set +e
api_failure_output=$(invoke_github_notifications_audit 2>&1)
api_failure_status=$?
set -e
assert_equal 1 "$api_failure_status" 'A failed GraphQL request did not fail the audit'
assert_contains 'Owned repository watch states could not be retrieved' "$api_failure_output" 'GraphQL failure explanation is missing'
assert_contains 'environment variable GITHUB_TOKEN (value hidden)' "$api_failure_output" 'Environment-token source was not detected'
assert_contains 'GitHub CLI request failed with exit code 75.' "$api_failure_output" 'GitHub CLI exit code is missing'
assert_contains 'GitHub API HTTP status: 403.' "$api_failure_output" 'GitHub API status is missing'
assert_not_contains 'mock GraphQL access denied' "$api_failure_output" 'Unfiltered GitHub CLI output was exposed'
assert_contains 'GH_TOKEN and GITHUB_TOKEN take precedence' "$api_failure_output" 'Credential precedence explanation is missing'
assert_contains 'unset GH_TOKEN GITHUB_TOKEN' "$api_failure_output" 'Bash environment-token mitigation is missing'
assert_contains 'gh auth status --active --hostname github.com' "$api_failure_output" 'Stored-login check is missing'
assert_contains 'Keep GITHUB_TOKEN' "$api_failure_output" 'Environment-token replacement option is missing'
assert_not_contains 'hidden-mock-token' "$api_failure_output" 'Environment-token value was exposed'
unset GITHUB_TOKEN

GH_MOCK_SCENARIO=client-failure
MOCK_GITHUB_NOTIFICATIONS_INTERACTIVE=true
MOCK_GITHUB_NOTIFICATIONS_CONFIRM=true
set +e
client_failure_output=$(invoke_github_notifications_audit 2>&1)
client_failure_status=$?
set -e
assert_equal 1 "$client_failure_status" 'A client-side gh failure did not fail the audit'
assert_contains 'not being treated as an authentication problem' "$client_failure_output" 'Client-side failure was misclassified'
assert_not_contains 'gh auth refresh --hostname github.com' "$client_failure_output" 'Client-side failure suggested an authentication refresh'

GH_MOCK_SCENARIO=recoverable-login
login_recovery_output=$(invoke_github_notifications_audit 2>&1)
assert_equal 2 "$(grep -c '^GitHub Notification Audit$' <<< "$login_recovery_output")" 'Audit did not rerun after gh auth login'
assert_contains 'Errors:                              0' "$login_recovery_output" 'Login recovery did not complete successfully'

GH_MOCK_SCENARIO=recoverable-api-failure
set +e
recovery_output=$(invoke_github_notifications_audit 2>&1)
recovery_status=$?
set -e
assert_equal 0 "$recovery_status" 'Recovered audit did not complete successfully'
assert_equal 2 "$(grep -c '^GitHub Notification Audit$' <<< "$recovery_output")" 'Audit did not rerun after gh auth refresh'
assert_contains 'Recovery step completed.' "$recovery_output" 'Automatic retry message is missing'
assert_contains 'Errors:                              0' "$recovery_output" 'Recovered audit did not complete successfully'

GH_MOCK_SCENARIO=environment-recoverable
GITHUB_TOKEN=hidden-mock-token
environment_recovery_output=$(invoke_github_notifications_audit 2>&1)
assert_equal 2 "$(grep -c '^GitHub Notification Audit$' <<< "$environment_recovery_output")" 'Audit did not rerun after ignoring the environment token'
assert_contains 'stored gh credentials (no environment-token override detected)' "$environment_recovery_output" 'Stored credentials were not selected on retry'
assert_contains 'Errors:                              0' "$environment_recovery_output" 'Environment-token recovery did not complete successfully'
unset GITHUB_TOKEN
MOCK_GITHUB_NOTIFICATIONS_INTERACTIVE=false
MOCK_GITHUB_NOTIFICATIONS_CONFIRM=false

GH_MOCK_SCENARIO=audit
set +e
audit_output=$(invoke_github_notifications_audit 2>&1)
audit_status=$?
set -e
assert_equal 1 "$audit_status" 'Per-repository API errors did not mark the audit incomplete'
assert_contains 'stored gh credentials (no environment-token override detected)' "$audit_output" 'Stored-credential source was not reported'
assert_contains 'Account: audit-user' "$audit_output" 'Authenticated account is missing'
assert_contains 'Repositories checked:                106' "$audit_output" 'Pagination beyond 100 repositories failed'
assert_contains 'All Activity / broad watch:          102' "$audit_output" 'Broad-watch state changed'
assert_contains 'Custom / API-unrepresented:          1' "$audit_output" 'Custom control state changed'
assert_contains 'Participating / @mentions only:      1' "$audit_output" 'Participating state changed'
assert_contains 'Ignored:                             1' "$audit_output" 'Ignored state changed'
assert_contains 'Private (included):                  1' "$audit_output" 'Private repository inclusion changed'
assert_contains 'Archived/skipped:                    1' "$audit_output" 'Archived skip count changed'
assert_contains 'Errors:                              1' "$audit_output" 'API error count changed'
assert_contains 'ALL ACTIVITY / BROAD WATCH' "$audit_output" 'Broad-watch heading is missing'
assert_contains 'https://github.com/audit-user/all-activity' "$audit_output" 'Broad-watch repository URL is missing'
assert_contains 'CUSTOM / API-UNREPRESENTED' "$audit_output" 'Custom heading is missing'
assert_contains 'https://github.com/Sokrates1989/thunderbird-ai' "$audit_output" 'Custom control repository is missing'
assert_contains 'PARTICIPATING / @MENTIONS ONLY' "$audit_output" 'Participating heading is missing'
assert_contains 'https://github.com/audit-user/participating' "$audit_output" 'Participating repository URL is missing'
assert_contains 'https://github.com/audit-user/ignored' "$audit_output" 'Ignored URL is missing'
assert_contains 'https://github.com/audit-user/api-error' "$audit_output" 'API-error URL is missing'
assert_not_contains 'https://github.com/audit-user/archived' "$audit_output" 'Archived repository was not skipped'
assert_not_contains 'Not subscribed' "$audit_output" 'Custom-capable repositories were labelled not subscribed'
assert_not_contains 'NOT SUBSCRIBED' "$audit_output" 'Legacy not-subscribed heading remains'
assert_contains '[x] Issues' "$audit_output" 'Recommended Issues configuration is missing'
assert_contains '[x] Pull requests' "$audit_output" 'Recommended Pull requests configuration is missing'
assert_contains '[x] Security alerts' "$audit_output" 'Recommended Security alerts configuration is missing'
assert_contains 'Manage watched repositories:' "$audit_output" 'Watching management guidance is missing'
assert_contains 'https://github.com/watching' "$audit_output" 'Watching management URL is missing'

launcher_content=$(<"${REPOSITORY_ROOT}/start.sh")
assert_contains '--github-notifications|--gh-notifications|--gn)' "$launcher_content" 'Bash quick-command routing is missing'
assert_contains 'main_features/github-notifications/github_notifications.sh' "$launcher_content" 'Bash feature path is missing'
assert_contains '16|"gn"|"--gn"|"github-notifications"' "$launcher_content" 'Bash interactive notification routing is missing'
assert_contains '18|"cls"|"--cls")' "$launcher_content" 'Bash interactive menu numbering changed unexpectedly'

english_keys=$(grep -E '^[^#].*=' "${REPOSITORY_ROOT}/locales/en.properties" | cut -d= -f1)
german_keys=$(grep -E '^[^#].*=' "${REPOSITORY_ROOT}/locales/de.properties" | cut -d= -f1)
assert_equal "$english_keys" "$german_keys" 'Root locale key sets differ'

printf 'Bash GitHub Notification Audit tests passed.\n'
