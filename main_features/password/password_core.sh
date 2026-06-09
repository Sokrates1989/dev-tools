#!/bin/bash
#
# Core cryptographic password generation helpers.
#
# Provides shared password alphabets, unbiased CSPRNG-backed character
# selection, complexity checks, and password creation functions.
#
# Dependencies:
#   - Bash
#   - /dev/urandom
#   - od
#

#
# Password policy constants.
# Safe specials avoid quotes, backslashes, whitespace, shell expansion,
# separators, comments, brackets, and equals signs.
#
UPPER_CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
LOWER_CHARS="abcdefghijklmnopqrstuvwxyz"
DIGIT_CHARS="0123456789"
SAFE_SPECIAL_CHARS="_.-"
MINIMUM_PASSWORD_LENGTH=16
DEFAULT_PASSWORD_LENGTH=64
DEFAULT_PASSWORD_COUNT=1

# get_secure_random_integer
#
# Returns an unbiased cryptographic random integer below the provided maximum.
# Rejection sampling avoids modulo bias.
#
# Arguments:
#   $1 - max_exclusive: exclusive upper bound, greater than zero.
#
# Outputs:
#   A base-10 integer in the range [0, max_exclusive).
#
# Returns:
#   0 on success; non-zero when max_exclusive is invalid.
get_secure_random_integer() {
    local max_exclusive="$1"

    if [ "$max_exclusive" -lt 1 ]; then
        echo "max_exclusive must be greater than zero" >&2
        return 1
    fi

    local byte usable_limit
    usable_limit=$((256 - (256 % max_exclusive)))

    while true; do
        byte=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
        if [ "$byte" -lt "$usable_limit" ]; then
            echo $((byte % max_exclusive))
            return 0
        fi
    done
}

# get_secure_random_character
#
# Selects one cryptographically random character from a supplied character set.
#
# Arguments:
#   $1 - characters: non-empty set of allowed characters.
#
# Outputs:
#   A single character from the supplied set.
#
# Returns:
#   0 on success; non-zero when characters is empty.
get_secure_random_character() {
    local characters="$1"
    local length index

    length=${#characters}
    if [ "$length" -lt 1 ]; then
        echo "characters must not be empty" >&2
        return 1
    fi

    index=$(get_secure_random_integer "$length")
    echo "${characters:index:1}"
}

# get_password_alphabet
#
# Builds the allowed alphabet for the selected password policy.
#
# Arguments:
#   $1 - include_special: "true" to include safe special characters.
#
# Outputs:
#   The complete allowed alphabet.
#
# Returns:
#   0 after writing the alphabet.
get_password_alphabet() {
    local include_special="$1"
    local alphabet="${UPPER_CHARS}${LOWER_CHARS}${DIGIT_CHARS}"

    if [ "$include_special" = true ]; then
        alphabet="${alphabet}${SAFE_SPECIAL_CHARS}"
    fi

    echo "$alphabet"
}

# contains_character_from_set
#
# Checks whether a password contains at least one character from a given set.
#
# Arguments:
#   $1 - password: generated password candidate.
#   $2 - characters: required character set.
#
# Returns:
#   0 when password contains a character from the set; 1 otherwise.
contains_character_from_set() {
    local password="$1"
    local characters="$2"
    local index char

    for ((index = 0; index < ${#password}; index++)); do
        char="${password:index:1}"
        case "$characters" in
            *"$char"*) return 0 ;;
        esac
    done

    return 1
}

# test_safe_password_complexity
#
# Verifies required uppercase, lowercase, digit, and optional special classes.
#
# Arguments:
#   $1 - password: generated password candidate.
#   $2 - include_special: "true" when a special character is required.
#
# Returns:
#   0 when the password satisfies policy; 1 otherwise.
test_safe_password_complexity() {
    local password="$1"
    local include_special="$2"

    contains_character_from_set "$password" "$UPPER_CHARS" &&
        contains_character_from_set "$password" "$LOWER_CHARS" &&
        contains_character_from_set "$password" "$DIGIT_CHARS" || return 1

    if [ "$include_special" = true ]; then
        contains_character_from_set "$password" "$SAFE_SPECIAL_CHARS"
        return $?
    fi

    return 0
}

# new_safe_password
#
# Generates one high-entropy password from the selected safe alphabet.
#
# Arguments:
#   $1 - password_length: number of characters to generate, minimum 16.
#   $2 - include_special: "true" to include and require safe specials.
#
# Outputs:
#   A generated password value only.
#
# Returns:
#   0 on success; non-zero when password_length is too short.
new_safe_password() {
    local password_length="$1"
    local include_special="$2"

    if [ "$password_length" -lt "$MINIMUM_PASSWORD_LENGTH" ]; then
        echo "Password length must be at least ${MINIMUM_PASSWORD_LENGTH} characters." >&2
        return 1
    fi

    local alphabet password index
    alphabet=$(get_password_alphabet "$include_special")

    while true; do
        password=""
        for ((index = 0; index < password_length; index++)); do
            password+="$(get_secure_random_character "$alphabet")"
        done

        if test_safe_password_complexity "$password" "$include_special"; then
            echo "$password"
            return 0
        fi
    done
}

# new_safe_password_set
#
# Generates the requested number of password values.
#
# Arguments:
#   $1 - password_length: number of characters in each password.
#   $2 - password_count: number of passwords to generate.
#   $3 - include_special: "true" to include safe specials.
#
# Outputs:
#   One password value per line.
#
# Returns:
#   0 after all passwords are generated.
new_safe_password_set() {
    local password_length="$1"
    local password_count="$2"
    local include_special="$3"
    local index

    for ((index = 0; index < password_count; index++)); do
        new_safe_password "$password_length" "$include_special"
    done
}
