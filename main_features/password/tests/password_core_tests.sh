#!/bin/bash
#
# Focused regression tests for password presets and complexity guarantees.
#
# Exercises every special-character preset, verifies generated character
# classes and allowed alphabets, checks menu aliases, and validates English and
# German catalog selection without printing generated passwords.
#

set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD_FEATURE_DIR="$(cd "${TEST_SCRIPT_DIR}/.." && pwd)"

# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=password_core.sh
source "${PASSWORD_FEATURE_DIR}/password_core.sh"
export PASSWORD_GENERATOR_LOCALE="en"
# The runtime-resolved sibling path is exercised by this test.
# shellcheck disable=SC1091
source "${PASSWORD_FEATURE_DIR}/password_ui.sh"

assert_equal() {
    local expected="$1"
    local actual="$2"
    local context="$3"

    if [ "$expected" != "$actual" ]; then
        printf '%s. Expected %q, received %q.\n' "$context" "$expected" "$actual" >&2
        return 1
    fi
}

assert_password_policy() {
    local preset="$1"
    local special_characters alphabet password character sample index
    special_characters=$(get_special_character_set "$preset")
    alphabet=$(get_password_alphabet "$special_characters")

    for ((sample = 0; sample < 12; sample++)); do
        password=$(new_safe_password "$MINIMUM_PASSWORD_LENGTH" "$preset")

        if [ "${#password}" -ne "$MINIMUM_PASSWORD_LENGTH" ]; then
            printf '%s produced the wrong length.\n' "$preset" >&2
            return 1
        fi

        if ! test_safe_password_complexity "$password" "$special_characters"; then
            printf '%s missed a required character class.\n' "$preset" >&2
            return 1
        fi

        for ((index = 0; index < ${#password}; index++)); do
            character="${password:index:1}"
            if ! contains_character_from_set "$character" "$alphabet"; then
                printf '%s produced a character outside its alphabet.\n' "$preset" >&2
                return 1
            fi
        done
    done
}

presets=(none minimum balanced high all)
expected_sets=(
    ""
    "_.-"
    "@%+-_:,."
    '@%+-_:,.!#$^&*?~=()'
    $'!"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~'
)

for ((index = 0; index < ${#presets[@]}; index++)); do
    preset="${presets[index]}"
    actual_set=$(get_special_character_set "$preset")
    assert_equal "${expected_sets[index]}" "$actual_set" "${preset} preset characters changed"
    assert_password_policy "$preset"
done

password_set=()
generated_passwords=$(new_safe_password_set 24 3 balanced)
while IFS= read -r password; do
    password_set+=("$password")
done <<< "$generated_passwords"
assert_equal "3" "${#password_set[@]}" "Password set count changed"

terminal_output=$(printf '3\n16\n2\n3\n' | invoke_safe_password_generator 2>/dev/null)
terminal_count=$(awk '/^Generated password\(s\):$/ { found = 1; next }
    found && length($0) == 16 { count++ }
    END { print count + 0 }' <<< "$terminal_output")
assert_equal '2' "$terminal_count" 'Terminal delivery did not preserve both passwords'

menu_answers=("" 1 n none 2 m minimum 3 b balanced 4 h high 5 a all)
menu_presets=(balanced none none none minimum minimum minimum balanced balanced balanced high high high all all all)
for ((index = 0; index < ${#menu_answers[@]}; index++)); do
    selection=$(read_special_character_preset <<< "${menu_answers[index]}" 2>/dev/null)
    assert_equal "${menu_presets[index]}" "$selection" "Menu alias '${menu_answers[index]}' changed"
done

PASSWORD_GENERATOR_LOCALE="de"
load_password_messages
assert_equal "Sicherer Passwortgenerator" "$(get_password_message title)" "German locale selection failed"

PASSWORD_GENERATOR_LOCALE="en"
load_password_messages
assert_equal "Safe Password Generator" "$(get_password_message title)" "English locale selection failed"

printf 'Bash password tests passed.\n'
