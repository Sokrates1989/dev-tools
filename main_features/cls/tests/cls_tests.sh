#!/bin/bash
#
# Disposable regression tests for Unix cls setup and launcher wiring.
#
# Every profile used here lives below a guarded temporary directory.
#

set -euo pipefail

TEST_SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURE_DIRECTORY="$(cd "${TEST_SCRIPT_DIRECTORY}/.." && pwd)"
REPOSITORY_ROOT="$(cd "${FEATURE_DIRECTORY}/../.." && pwd)"

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=cls_core.sh
source "${FEATURE_DIRECTORY}/cls_core.sh"
# shellcheck source=cls_ui.sh
source "${FEATURE_DIRECTORY}/cls_ui.sh"

TEST_TEMP_PARENT="${TMPDIR:-/tmp}"
TEST_ROOT="$(mktemp -d "${TEST_TEMP_PARENT%/}/dev-tools-cls-tests.XXXXXX")"

# Removes only the guarded disposable test directory.
cleanup_cls_tests() {
    case "$TEST_ROOT" in
        "${TEST_TEMP_PARENT%/}"/dev-tools-cls-tests.*) rm -rf -- "$TEST_ROOT" ;;
    esac
}
trap cleanup_cls_tests EXIT

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

# Fails when a text block does not contain an expected literal value.
assert_contains() {
    local expected="$1"
    local actual="$2"
    local context="$3"
    if [[ "$actual" != *"$expected"* ]]; then
        printf '%s. Missing text: %q.\n' "$context" "$expected" >&2
        return 1
    fi
}

# Fails when a file's complete text differs from the expected value.
assert_file_content() {
    local path="$1"
    local expected="$2"
    local context="$3"
    local actual
    actual=$(cat -- "$path")
    assert_equal "$expected" "$actual" "$context"
}

assert_equal bash "$(normalize_cls_shell /bin/bash)" 'Bash shell normalization changed'
assert_equal zsh "$(normalize_cls_shell /usr/local/bin/zsh)" 'Zsh shell normalization changed'
assert_equal ash "$(normalize_cls_shell /bin/ash)" 'ash shell normalization changed'
assert_equal sh "$(normalize_cls_shell /bin/dash)" 'dash normalization changed'
if normalize_cls_shell /usr/bin/fish >/dev/null 2>&1; then
    printf 'Unsupported fish shell was accepted.\n' >&2
    exit 1
fi

assert_equal "${TEST_ROOT}/home/.bashrc" "$(resolve_cls_profile bash "${TEST_ROOT}/home")" 'Bash profile detection changed'
assert_equal "${TEST_ROOT}/home/.zshrc" "$(resolve_cls_profile zsh "${TEST_ROOT}/home")" 'Zsh profile detection changed'
assert_equal "${TEST_ROOT}/home/.profile" "$(resolve_cls_profile sh "${TEST_ROOT}/home")" 'POSIX sh profile detection changed'
assert_equal "${TEST_ROOT}/home/.profile" "$(resolve_cls_profile ash "${TEST_ROOT}/home")" 'BusyBox ash profile detection changed'
if resolve_cls_profile fish "${TEST_ROOT}/home" >/dev/null 2>&1; then
    printf 'Unsupported shell resolved an automatic profile.\n' >&2
    exit 1
fi

assert_equal 'source ~/.bashrc' "$(get_cls_reload_command bash)" 'Bash reload command changed'
assert_equal 'source ~/.zshrc' "$(get_cls_reload_command zsh)" 'Zsh reload command changed'
assert_equal '. ~/.profile' "$(get_cls_reload_command sh)" 'POSIX sh reload command changed'
assert_equal '. ~/.profile' "$(get_cls_reload_command ash)" 'BusyBox ash reload command changed'
assert_equal 'alias cls="printf '\''\033[H\033[2J\033[3J'\''"' "$CLS_ALIAS_LINE" 'Unix cls alias changed'

missing_profile="${TEST_ROOT}/missing/nested/.bashrc"
get_cls_profile_state "$missing_profile"
assert_equal absent "$CLS_PROFILE_STATE" 'Missing profile state changed'
install_cls_managed_block "$missing_profile"
get_cls_profile_state "$missing_profile"
assert_equal current "$CLS_PROFILE_STATE" 'Installed profile block was not current'
first_install_content=$(cat -- "$missing_profile")
install_cls_managed_block "$missing_profile"
assert_file_content "$missing_profile" "$first_install_content" 'Repeated install changed the profile'
assert_equal 1 "$(grep -Fxc "$CLS_MANAGED_BEGIN" "$missing_profile")" 'Repeated install duplicated the block'

preserved_profile="${TEST_ROOT}/preserved/.bashrc"
mkdir -p -- "$(dirname "$preserved_profile")"
printf '%s\r\n' 'export EXISTING_VALUE="keep-me"' > "$preserved_profile"
install_cls_managed_block "$preserved_profile"
preserved_content=$(cat -- "$preserved_profile")
assert_contains 'export EXISTING_VALUE="keep-me"' "$preserved_content" 'Unrelated profile content was changed'
if awk '{ if (sub(/\r$/, "") == 0) exit 1 }' "$preserved_profile"; then
    :
else
    printf 'CRLF profile line endings were not preserved.\n' >&2
    exit 1
fi

stale_profile="${TEST_ROOT}/stale/.zshrc"
mkdir -p -- "$(dirname "$stale_profile")"
printf '%s\n' \
    'before="keep"' \
    "$CLS_MANAGED_BEGIN" \
    'alias cls="clear"' \
    "$CLS_MANAGED_END" \
    'after="keep"' > "$stale_profile"
get_cls_profile_state "$stale_profile"
assert_equal stale "$CLS_PROFILE_STATE" 'Stale managed block was not detected'
install_cls_managed_block "$stale_profile"
updated_content=$(cat -- "$stale_profile")
assert_contains 'before="keep"' "$updated_content" 'Content before the managed block was removed'
assert_contains 'after="keep"' "$updated_content" 'Content after the managed block was removed'
assert_contains "$CLS_ALIAS_LINE" "$updated_content" 'Managed block was not updated'
assert_equal 1 "$(grep -Fxc "$CLS_MANAGED_BEGIN" "$stale_profile")" 'Managed block update duplicated markers'

combined_profile="${TEST_ROOT}/combined/.bashrc"
mkdir -p -- "$(dirname "$combined_profile")"
get_cls_managed_block > "$combined_profile"
printf '\n%s\n' 'alias cls="user-cleaner"' >> "$combined_profile"
detect_existing_cls "$combined_profile"
assert_equal profile "$CLS_EXISTING_KIND" 'A cls definition outside the managed block was not detected'
install_cls_managed_block "$combined_profile" true
combined_content=$(cat -- "$combined_profile")
assert_contains 'alias cls="user-cleaner"' "$combined_content" 'Confirmed override deleted the user cls definition'
assert_equal 1 "$(grep -Fxc "$CLS_MANAGED_BEGIN" "$combined_profile")" 'Confirmed override duplicated the managed block'
assert_equal "$CLS_MANAGED_END" "$(tail -n 1 "$combined_profile")" 'Confirmed override did not move the managed block to the end'

conflict_profile="${TEST_ROOT}/conflict/.bashrc"
mkdir -p -- "$(dirname "$conflict_profile")"
printf '%s\n' 'alias cls="my-cleaner"' > "$conflict_profile"
detect_existing_cls "$conflict_profile"
assert_equal profile "$CLS_EXISTING_KIND" 'Existing profile alias was not detected'

malformed_profile="${TEST_ROOT}/malformed/.profile"
mkdir -p -- "$(dirname "$malformed_profile")"
printf '%s\n' "$CLS_MANAGED_END" 'keep="all-content"' "$CLS_MANAGED_BEGIN" > "$malformed_profile"
get_cls_profile_state "$malformed_profile"
assert_equal malformed "$CLS_PROFILE_STATE" 'Reversed managed markers were not rejected'
malformed_original=$(cat -- "$malformed_profile")
if install_cls_managed_block "$malformed_profile"; then
    printf 'Malformed managed markers were modified automatically.\n' >&2
    exit 1
fi
assert_file_content "$malformed_profile" "$malformed_original" 'Malformed marker handling changed profile content'

declined_profile="${TEST_ROOT}/declined/.bashrc"
mkdir -p -- "$(dirname "$declined_profile")"
printf '%s\n' 'export UNRELATED="unchanged"' > "$declined_profile"
declined_original=$(cat -- "$declined_profile")
export DEV_TOOLS_LOCALE=en
export DEV_TOOLS_CLS_SHELL=bash
export DEV_TOOLS_CLS_PROFILE_PATH="$declined_profile"
initialize_cls_messages "$FEATURE_DIRECTORY"
read_cls_yes_no_choice() { return 1; }
declined_output=$(invoke_cls_setup)
assert_file_content "$declined_profile" "$declined_original" 'Declining installation changed the profile'
assert_contains 'No profile changes were made.' "$declined_output" 'Decline output changed'
assert_contains "$CLS_MANAGED_BEGIN" "$declined_output" 'Manual block was not printed after decline'
assert_contains 'source ~/.bashrc' "$declined_output" 'Manual reload command was not printed'
unset DEV_TOOLS_CLS_PROFILE_PATH

export DEV_TOOLS_CLS_SHELL=fish
assert_equal unknown "$(detect_cls_shell)" 'Unsupported shell detection did not remain manual-only'
unknown_output=$(invoke_cls_setup)
assert_contains 'does not have a safely supported automatic profile target' "$unknown_output" 'Unknown shell guidance changed'
assert_contains "$CLS_PRINTF_COMMAND" "$unknown_output" 'Unknown shell output omitted the safe one-shot command'
if [[ "$unknown_output" == *"$CLS_MANAGED_BEGIN"* ]]; then
    printf 'Unknown shell output suggested incompatible persistent alias syntax.\n' >&2
    exit 1
fi

launcher_content=$(cat -- "$REPOSITORY_ROOT/start.sh")
assert_contains 'bash "$ROOT_DIR/main_features/cls/cls_installer.sh" "${@:2}"' "$launcher_content" '--cls argument routing is missing'
assert_contains 'bash "$ROOT_DIR/main_features/cls/cls_installer.sh"' "$launcher_content" 'Interactive cls menu routing is missing'
assert_equal 2 "$(grep -Fc 'bash "$ROOT_DIR/main_features/cls/cls_installer.sh"' "$REPOSITORY_ROOT/start.sh")" 'Bash launcher routes do not share one cls implementation'
assert_contains '--help|-h|help)' "$launcher_content" 'Bash help routing is missing'

english_keys=$(grep -E '^[^#].*=' "$FEATURE_DIRECTORY/locales/en.properties" | cut -d= -f1)
german_keys=$(grep -E '^[^#].*=' "$FEATURE_DIRECTORY/locales/de.properties" | cut -d= -f1)
assert_equal "$english_keys" "$german_keys" 'cls locale key sets differ'

root_english_keys=$(grep -E '^[^#].*=' "$REPOSITORY_ROOT/locales/en.properties" | cut -d= -f1)
root_german_keys=$(grep -E '^[^#].*=' "$REPOSITORY_ROOT/locales/de.properties" | cut -d= -f1)
assert_equal "$root_english_keys" "$root_german_keys" 'Launcher locale key sets differ'

printf 'Bash cls terminal cleaner tests passed.\n'
