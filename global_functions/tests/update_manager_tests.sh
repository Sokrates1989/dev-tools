#!/bin/bash
#
# Disposable integration tests for the Bash update manager.
#
# Builds a local bare remote plus installed and authoring clones, then verifies
# cache, branch-state classification, decline/accept prompting, and safe
# fast-forward behavior without contacting an external network.
#

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${TEST_SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=global_functions/update_manager.sh
source "${REPOSITORY_ROOT}/global_functions/update_manager.sh"

# These searches intentionally match literal shell expressions in start.sh.
# shellcheck disable=SC2016
GUARD_LINE=$(grep -n 'invoke_dev_tools_startup_update_check "$ROOT_DIR"' "$REPOSITORY_ROOT/start.sh" | head -n 1 | cut -d: -f1)
DISPATCH_LINE=$(grep -n '# --- Argument-based quick start ---' "$REPOSITORY_ROOT/start.sh" | head -n 1 | cut -d: -f1)
if [ -z "$GUARD_LINE" ] || [ -z "$DISPATCH_LINE" ] || [ "$GUARD_LINE" -ge "$DISPATCH_LINE" ]; then
    printf '%s\n' 'Bash launcher must run its update guard before argument dispatch.' >&2
    exit 1
fi
# shellcheck disable=SC2016
if ! grep -Fq 'DEV_TOOLS_UPDATE_REPLAYED=1 exec bash "$ROOT_DIR/start.sh" "${ORIGINAL_ARGS[@]}"' "$REPOSITORY_ROOT/start.sh"; then
    printf '%s\n' 'Bash launcher must exec the updated dispatcher with the original argument array.' >&2
    exit 1
fi

TEST_TEMP_PARENT="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "${TEST_TEMP_PARENT%/}/dev-tools-update-tests.XXXXXX")"
REMOTE_REPOSITORY="${TEST_ROOT}/remote.git"
AUTHOR_REPOSITORY="${TEST_ROOT}/author"
INSTALLED_REPOSITORY="${TEST_ROOT}/installed"

cleanup_update_test() {
    case "$TEST_ROOT" in
        "${TEST_TEMP_PARENT%/}"/dev-tools-update-tests.*) rm -rf -- "$TEST_ROOT" ;;
    esac
}
trap cleanup_update_test EXIT

assert_update_test_equal() {
    local expected="$1"
    local actual="$2"
    local context="$3"
    if [ "$expected" != "$actual" ]; then
        printf '%s. Expected %q, received %q.\n' "$context" "$expected" "$actual" >&2
        return 1
    fi
}

assert_update_test_equal \
    github.com/sokrates1989/dev-tools \
    "$(normalize_dev_tools_remote_identity 'https://github.com/Sokrates1989/dev-tools.git')" \
    "HTTPS remote normalization"
assert_update_test_equal \
    github.com/sokrates1989/dev-tools \
    "$(normalize_dev_tools_remote_identity 'git@github.com:Sokrates1989/dev-tools.git')" \
    "SSH remote normalization"

git init --bare --initial-branch=main "$REMOTE_REPOSITORY" >/dev/null
git init --initial-branch=main "$AUTHOR_REPOSITORY" >/dev/null
git -C "$AUTHOR_REPOSITORY" config user.name "Dev Tools Tests"
git -C "$AUTHOR_REPOSITORY" config user.email "dev-tools-tests@example.invalid"
mkdir -p "$AUTHOR_REPOSITORY/locales"
cp "$REPOSITORY_ROOT/locales/en.properties" "$AUTHOR_REPOSITORY/locales/en.properties"
cp "$REPOSITORY_ROOT/locales/de.properties" "$AUTHOR_REPOSITORY/locales/de.properties"
printf 'initial' > "$AUTHOR_REPOSITORY/release.txt"
git -C "$AUTHOR_REPOSITORY" remote add origin "$REMOTE_REPOSITORY"
git -C "$AUTHOR_REPOSITORY" add -A
git -C "$AUTHOR_REPOSITORY" commit -m initial >/dev/null
git -C "$AUTHOR_REPOSITORY" push -u origin main >/dev/null

git clone "$REMOTE_REPOSITORY" "$INSTALLED_REPOSITORY" >/dev/null 2>&1
git -C "$INSTALLED_REPOSITORY" config user.name "Dev Tools Tests"
git -C "$INSTALLED_REPOSITORY" config user.email "dev-tools-tests@example.invalid"

EXPECTED_IDENTITY="$(normalize_dev_tools_remote_identity "$REMOTE_REPOSITORY")"
export DEV_TOOLS_LOCALE="en"
export DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS="0"
initialize_dev_tools_update_messages "$INSTALLED_REPOSITORY"

get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal equal "$DEV_TOOLS_UPDATE_STATE" "Initial state"

export DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS="300"
get_dev_tools_update_state "$INSTALLED_REPOSITORY" true "$EXPECTED_IDENTITY"
assert_update_test_equal cached "$DEV_TOOLS_UPDATE_STATE" "Fresh cache state"
export DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS="0"

OFFLINE_REMOTE="${REMOTE_REPOSITORY}.offline"
mv -- "$REMOTE_REPOSITORY" "$OFFLINE_REMOTE"
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal unavailable "$DEV_TOOLS_UPDATE_STATE" "Offline state"
mv -- "$OFFLINE_REMOTE" "$REMOTE_REPOSITORY"

printf 'remote update' > "$AUTHOR_REPOSITORY/release.txt"
git -C "$AUTHOR_REPOSITORY" add release.txt
git -C "$AUTHOR_REPOSITORY" commit -m "remote update" >/dev/null
git -C "$AUTHOR_REPOSITORY" push origin main >/dev/null

get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal behind "$DEV_TOOLS_UPDATE_STATE" "Behind state"

invoke_dev_tools_startup_update_check "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal false "$DEV_TOOLS_UPDATE_PERFORMED" "Non-interactive update result"
assert_update_test_equal 0 "$DEVTOOLS_UPDATE_AVAILABLE" "Non-interactive availability"

printf 'dirty' > "$INSTALLED_REPOSITORY/dirty.tmp"
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal dirty "$DEV_TOOLS_UPDATE_STATE" "Dirty state"
rm -- "$INSTALLED_REPOSITORY/dirty.tmp"

get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "example.invalid/wrong/repository"
assert_update_test_equal unexpected-origin "$DEV_TOOLS_UPDATE_STATE" "Origin identity state"

invoke_dev_tools_startup_update_check "$INSTALLED_REPOSITORY" true "$EXPECTED_IDENTITY" <<< "n" >/dev/null
assert_update_test_equal false "$DEV_TOOLS_UPDATE_PERFORMED" "Declined update result"
assert_update_test_equal 1 "$DEVTOOLS_UPDATE_AVAILABLE" "Declined availability"
get_dev_tools_update_state "$INSTALLED_REPOSITORY" true "$EXPECTED_IDENTITY"
assert_update_test_equal behind "$DEV_TOOLS_UPDATE_STATE" "Declined update remains discoverable"

invoke_dev_tools_startup_update_check "$INSTALLED_REPOSITORY" true "$EXPECTED_IDENTITY" <<< "" >/dev/null
assert_update_test_equal true "$DEV_TOOLS_UPDATE_PERFORMED" "Accepted update result"
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal equal "$DEV_TOOLS_UPDATE_STATE" "Post-update state"

git -C "$INSTALLED_REPOSITORY" branch --unset-upstream
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal missing-upstream "$DEV_TOOLS_UPDATE_STATE" "Missing upstream state"
git -C "$INSTALLED_REPOSITORY" branch --set-upstream-to origin/main >/dev/null

git -C "$INSTALLED_REPOSITORY" remote add other "$REMOTE_REPOSITORY"
git -C "$INSTALLED_REPOSITORY" fetch other >/dev/null 2>&1
git -C "$INSTALLED_REPOSITORY" branch --set-upstream-to other/main >/dev/null
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal unexpected-upstream "$DEV_TOOLS_UPDATE_STATE" "Unexpected upstream state"
git -C "$INSTALLED_REPOSITORY" branch --set-upstream-to origin/main >/dev/null
git -C "$INSTALLED_REPOSITORY" remote remove other

git -C "$INSTALLED_REPOSITORY" checkout -b feature >/dev/null 2>&1
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal unexpected-branch "$DEV_TOOLS_UPDATE_STATE" "Unexpected branch state"
git -C "$INSTALLED_REPOSITORY" checkout main >/dev/null 2>&1

printf 'local' > "$INSTALLED_REPOSITORY/local.txt"
git -C "$INSTALLED_REPOSITORY" add local.txt
git -C "$INSTALLED_REPOSITORY" commit -m "local update" >/dev/null
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal ahead "$DEV_TOOLS_UPDATE_STATE" "Ahead state"

printf 'diverging update' > "$AUTHOR_REPOSITORY/release.txt"
git -C "$AUTHOR_REPOSITORY" add release.txt
git -C "$AUTHOR_REPOSITORY" commit -m "diverging update" >/dev/null
git -C "$AUTHOR_REPOSITORY" push origin main >/dev/null
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal diverged "$DEV_TOOLS_UPDATE_STATE" "Diverged state"

git -C "$INSTALLED_REPOSITORY" checkout --detach >/dev/null 2>&1
get_dev_tools_update_state "$INSTALLED_REPOSITORY" false "$EXPECTED_IDENTITY"
assert_update_test_equal detached "$DEV_TOOLS_UPDATE_STATE" "Detached state"

printf 'Bash update manager tests passed.\n'
