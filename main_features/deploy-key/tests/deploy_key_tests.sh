#!/bin/bash
#
# Disposable regression tests for repository parsing and deploy-key lifecycle.
#
# Every key is created below a temporary directory and no real SSH state is
# read, changed, or removed.
#

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIRECTORY="$(cd "${TEST_SCRIPT_DIR}/.." && pwd)"
REPOSITORY_ROOT="$(cd "${FEATURE_DIRECTORY}/../.." && pwd)"

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=deploy_key_core.sh
source "${FEATURE_DIRECTORY}/deploy_key_core.sh"
# The runtime-resolved sibling path is exercised by this test.
# shellcheck disable=SC1091
source "${FEATURE_DIRECTORY}/deploy_key_ui.sh"

if ! command -v ssh-keygen >/dev/null 2>&1; then
    printf 'ssh-keygen is required for Deploy Key Manager tests.\n' >&2
    exit 1
fi

TEST_TEMP_PARENT="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "${TEST_TEMP_PARENT%/}/dev-tools-deploy-key-tests.XXXXXX")"
TEST_SSH_DIRECTORY="${TEST_ROOT}/home/.ssh"

# Removes only the guarded disposable test directory.
cleanup_deploy_key_tests() {
    case "$TEST_ROOT" in
        "${TEST_TEMP_PARENT%/}"/dev-tools-deploy-key-tests.*) rm -rf -- "$TEST_ROOT" ;;
    esac
}
trap cleanup_deploy_key_tests EXIT

# Fails when two scalar values differ.
assert_equal() {
    local expected="$1"
    local actual="$2"
    local context="$3"

    if [ "$expected" != "$actual" ]; then
        printf '%s. Expected %q, received %q.\n' "$context" "$expected" "$actual" >&2
        return 1
    fi
}

# Fails when a path does not exist as a regular file.
assert_file_exists() {
    local path="$1"
    local context="$2"
    if [ ! -f "$path" ]; then
        printf '%s. Missing file: %s.\n' "$context" "$path" >&2
        return 1
    fi
}

# Fails when a text block does not contain the expected literal value.
assert_contains() {
    local expected="$1"
    local actual="$2"
    local context="$3"

    if [[ "$actual" != *"$expected"* ]]; then
        printf '%s. Missing text: %q.\n' "$context" "$expected" >&2
        return 1
    fi
}

# Parses input and compares its canonical repository identity.
assert_repository_parse() {
    local input="$1"
    local expected="$2"
    local context="$3"
    if ! extract_deploy_key_repository "$input"; then
        printf '%s. Input was rejected.\n' "$context" >&2
        return 1
    fi
    assert_equal "$expected" "$DEPLOY_KEY_REPOSITORY_ID" "$context"
}

assert_repository_parse \
    'https://github.com/my-user/server-info' \
    'github.com/my-user/server-info' \
    'GitHub browser URL without suffix'
assert_repository_parse \
    'https://github.com/my-user/server-info.git' \
    'github.com/my-user/server-info' \
    'GitHub HTTPS remote'
assert_repository_parse \
    'git@github.com:my-user/server-info.git' \
    'github.com/my-user/server-info' \
    'GitHub SCP-style SSH remote'
assert_repository_parse \
    'origin  https://github.com/my-user/server-info.git (fetch)' \
    'github.com/my-user/server-info' \
    'Git fetch output line'
assert_repository_parse \
    'origin  https://github.com/my-user/server-info.git (push)' \
    'github.com/my-user/server-info' \
    'Git push output line'
assert_repository_parse \
    $'origin  https://github.com/my-user/server-info.git (fetch)\norigin  https://github.com/my-user/server-info.git (push)' \
    'github.com/my-user/server-info' \
    'Complete git remote output'
assert_repository_parse \
    'https://github.com/my-user/server-info.git/' \
    'github.com/my-user/server-info' \
    'Trailing slash normalization'
assert_repository_parse \
    'https://github.com/team-name/repo-name_with.parts.git' \
    'github.com/team-name/repo-name_with.parts' \
    'Repository punctuation support'

if extract_deploy_key_repository 'not a repository URL'; then
    printf 'Invalid repository input was accepted.\n' >&2
    exit 1
fi

expected_basename='github.com__my-user__server-info__netcup-server'
actual_basename=$(get_deploy_key_basename github.com my-user server-info netcup-server)
assert_equal "$expected_basename" "$actual_basename" 'Deterministic key filename changed'

first_escaped_basename=$(get_deploy_key_basename github.com 'owner__part' repository server)
second_escaped_basename=$(get_deploy_key_basename github.com owner 'part__repository' server)
if [ "$first_escaped_basename" = "$second_escaped_basename" ]; then
    printf 'Escaped identity components generated the same key filename.\n' >&2
    exit 1
fi

uppercase_basename=$(get_deploy_key_basename git.example Team Repository server)
lowercase_basename=$(get_deploy_key_basename git.example team repository server)
if [ "$uppercase_basename" = "$lowercase_basename" ]; then
    printf 'Case-sensitive repository identities generated the same key filename.\n' >&2
    exit 1
fi

same_path=$(get_deploy_key_basename github.com my-user server-info netcup-server)
different_host_path=$(get_deploy_key_basename github.com my-user server-info qnap)
different_repository_path=$(get_deploy_key_basename github.com my-user other-repository netcup-server)
assert_equal "$actual_basename" "$same_path" 'Same repository and hostname changed path'
if [ "$actual_basename" = "$different_host_path" ]; then
    printf 'Different hostnames generated the same key path.\n' >&2
    exit 1
fi

first_alias=$(get_deploy_key_ssh_alias github.com first-owner shared-repository)
second_alias=$(get_deploy_key_ssh_alias github.com second-owner shared-repository)
if [ "$first_alias" = "$second_alias" ]; then
    printf 'Repositories with the same name under different owners generated the same SSH alias.\n' >&2
    exit 1
fi
if [ "$actual_basename" = "$different_repository_path" ]; then
    printf 'Different repositories generated the same key path.\n' >&2
    exit 1
fi

export DEV_TOOLS_LOCALE=en
initialize_deploy_key_messages "$REPOSITORY_ROOT"
collect_deploy_key_repository_input "" <<< $'origin  https://github.com/my-user/server-info.git (fetch)\norigin  https://github.com/my-user/server-info.git (push)' >/dev/null
assert_equal \
    $'origin  https://github.com/my-user/server-info.git (fetch)\norigin  https://github.com/my-user/server-info.git (push)' \
    "$DEPLOY_KEY_REPOSITORY_INPUT" \
    'Multiline paste collection changed'

prepare_managed_deploy_key_directory "$TEST_SSH_DIRECTORY"
managed_directory=$(get_managed_deploy_key_directory "$TEST_SSH_DIRECTORY")
private_key_path="${managed_directory}/${actual_basename}"
key_comment='dev-tools deploy key | github.com/my-user/server-info | netcup-server'

ensure_managed_deploy_key "$private_key_path" "$key_comment"
assert_equal 'CREATED' "$DEPLOY_KEY_STATUS" 'Initial key status changed'
assert_file_exists "$private_key_path" 'Private key creation failed'
assert_file_exists "${private_key_path}.pub" 'Public key creation failed'
original_public_material=$(derive_deploy_key_public_material "$private_key_path")
assert_contains 'ssh-ed25519 ' "$original_public_material" 'Generated key is not ED25519'

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) ;;
    *)
        assert_equal '700' "$(stat -c '%a' "$TEST_SSH_DIRECTORY")" 'SSH directory permissions changed'
        assert_equal '700' "$(stat -c '%a' "$managed_directory")" 'Managed directory permissions changed'
        assert_equal '600' "$(stat -c '%a' "$private_key_path")" 'Private key permissions changed'
        assert_equal '644' "$(stat -c '%a' "${private_key_path}.pub")" 'Public key permissions changed'
        ;;
esac

ensure_managed_deploy_key "$private_key_path" "$key_comment"
assert_equal 'ALREADY EXISTS' "$DEPLOY_KEY_STATUS" 'Existing key was not reused'
reused_public_material=$(derive_deploy_key_public_material "$private_key_path")
assert_equal "$original_public_material" "$reused_public_material" 'Existing private key changed'

rm -- "${private_key_path}.pub"
ensure_managed_deploy_key "$private_key_path" "$key_comment"
assert_equal 'ALREADY EXISTS' "$DEPLOY_KEY_STATUS" 'Recovered key status changed'
assert_equal 'true' "$DEPLOY_KEY_PUBLIC_RECOVERED" 'Missing public key was not reported as recovered'
assert_file_exists "${private_key_path}.pub" 'Missing public key was not recovered'
recovered_public_material=$(derive_deploy_key_public_material "$private_key_path")
assert_equal "$original_public_material" "$recovered_public_material" 'Recovered public key changed'
if ! deploy_key_pair_matches "$private_key_path" "${private_key_path}.pub"; then
    printf 'Recovered public key does not match its private key.\n' >&2
    exit 1
fi

orphan_path="${managed_directory}/orphan"
cp "${private_key_path}.pub" "${orphan_path}.pub"
if ensure_managed_deploy_key "$orphan_path" "$key_comment"; then
    printf 'A public-key-only state unexpectedly created a new private key.\n' >&2
    exit 1
else
    orphan_status=$?
fi
assert_equal '10' "$orphan_status" 'Public-key-only state returned the wrong status'
if [ -e "$orphan_path" ]; then
    printf 'A private key was created for an incomplete managed state.\n' >&2
    exit 1
fi

invocation_home="${TEST_ROOT}/invocation-home"
invocation_output=$(printf '%s\n%s\n' \
    'origin  https://github.com/my-user/server-info.git (fetch)' \
    'origin  https://github.com/my-user/server-info.git (push)' | \
    HOME="$invocation_home" DEV_TOOLS_LOCALE=en \
        bash "${FEATURE_DIRECTORY}/deploy_key_manager.sh")
assert_contains 'Repository detected:' "$invocation_output" 'Entrypoint omitted repository detection'
assert_contains 'github.com/my-user/server-info' "$invocation_output" 'Entrypoint omitted canonical identity'
assert_contains 'Status     : CREATED' "$invocation_output" 'Entrypoint omitted creation status'
assert_contains 'PUBLIC KEY' "$invocation_output" 'Entrypoint omitted the public key section'
assert_contains 'Allow write access' "$invocation_output" 'Entrypoint omitted read-only GitHub guidance'
assert_contains 'git remote set-url origin git@' "$invocation_output" 'Entrypoint omitted existing-checkout command'
assert_contains 'ssh -T git@' "$invocation_output" 'Entrypoint omitted connection-test command'
if [[ "$invocation_output" == *'BEGIN OPENSSH PRIVATE KEY'* ]]; then
    printf 'Entrypoint exposed private key material.\n' >&2
    exit 1
fi
if [ -e "${invocation_home}/.ssh/config" ]; then
    printf 'Entrypoint unexpectedly modified SSH configuration.\n' >&2
    exit 1
fi

reused_invocation_output=$(printf '%s\n' \
    'https://github.com/my-user/server-info.git' | \
    HOME="$invocation_home" DEV_TOOLS_LOCALE=en \
        bash "${FEATURE_DIRECTORY}/deploy_key_manager.sh")
assert_contains 'Status     : ALREADY EXISTS' "$reused_invocation_output" 'Repeated invocation did not reuse the key'
initial_public_line=$(grep '^ssh-ed25519 ' <<< "$invocation_output")
reused_public_line=$(grep '^ssh-ed25519 ' <<< "$reused_invocation_output")
assert_equal "$initial_public_line" "$reused_public_line" 'Repeated invocation changed the public key'

launcher_home="${TEST_ROOT}/launcher-home"
launcher_output=$(printf '%s\n%s\n%s\n' \
    '15' \
    'origin  https://github.com/my-user/server-info.git (fetch)' \
    'origin  https://github.com/my-user/server-info.git (push)' | \
    HOME="$launcher_home" DEV_TOOLS_LOCALE=en DEV_TOOLS_UPDATE_REPLAYED=1 \
        bash "${REPOSITORY_ROOT}/start.sh")
assert_contains 'Repository detected:' "$launcher_output" 'Interactive launcher did not dispatch the manager'
assert_contains 'github.com/my-user/server-info' "$launcher_output" 'Launcher paste lost the repository identity'
assert_contains 'Status     : CREATED' "$launcher_output" 'Launcher flow did not create the deploy key'

english_keys=$(grep -E '^deploy_key\.' "$REPOSITORY_ROOT/locales/en.properties" | cut -d= -f1)
german_keys=$(grep -E '^deploy_key\.' "$REPOSITORY_ROOT/locales/de.properties" | cut -d= -f1)
assert_equal "$english_keys" "$german_keys" 'Deploy-key locale key sets differ'

printf 'Bash Deploy Key Manager tests passed.\n'
