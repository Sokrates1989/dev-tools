#!/bin/bash
#
# Safe production password generator.
#
# Generates secrets.env-compatible passwords with the operating system CSPRNG.
# The default output matches the Docker secrets template used by the Python API
# deployment workflow.
#
# Dependencies:
#   - Bash
#   - /dev/urandom
#   - od
#

set -euo pipefail

#
# Password policy constants.
# The special alphabet avoids quotes, backslashes, whitespace, shell expansion,
# command separators, comment markers, brackets, and equals signs so generated
# values can be pasted directly into unquoted secrets.env lines.
#
UPPER_CHARS="ABCDEFGHIJKLMNOPQRSTUVWXYZ"
LOWER_CHARS="abcdefghijklmnopqrstuvwxyz"
DIGIT_CHARS="0123456789"
SPECIAL_CHARS="@%+-_:,."
SAFE_ALPHABET="${UPPER_CHARS}${LOWER_CHARS}${DIGIT_CHARS}${SPECIAL_CHARS}"
DEFAULT_SECRET_NAMES=(
    "DB_PASSWORD"
    "ADMIN_API_KEY"
    "BACKUP_RESTORE_API_KEY"
    "BACKUP_DELETE_API_KEY"
    "DB_UI_ADMIN_PASSWORD"
)

# show_password_generator_help
#
# Prints direct-script usage for generating default, single, or numbered
# password outputs.
#
# Returns:
#   0 after writing usage text.
show_password_generator_help() {
    echo "Safe Password Generator"
    echo ""
    echo "Usage:"
    echo "  dev-tools --password"
    echo "  generate_safe_passwords.sh [--length 64] [--single]"
    echo "  generate_safe_passwords.sh [--length 64] [--count 3]"
    echo ""
    echo "Defaults:"
    echo "  Length: 48 characters"
    echo "  Output: DB_PASSWORD, ADMIN_API_KEY, BACKUP_RESTORE_API_KEY,"
    echo "          BACKUP_DELETE_API_KEY, DB_UI_ADMIN_PASSWORD"
}

# get_secure_random_integer
#
# Returns an unbiased cryptographic random integer below the provided maximum.
# Rejection sampling avoids modulo bias when mapping random bytes onto the
# password alphabet.
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
# Verifies that a password contains uppercase, lowercase, digit, and approved
# special characters.
#
# Arguments:
#   $1 - password: generated password candidate.
#
# Returns:
#   0 when the password satisfies policy; 1 otherwise.
test_safe_password_complexity() {
    local password="$1"

    contains_character_from_set "$password" "$UPPER_CHARS" &&
        contains_character_from_set "$password" "$LOWER_CHARS" &&
        contains_character_from_set "$password" "$DIGIT_CHARS" &&
        contains_character_from_set "$password" "$SPECIAL_CHARS"
}

# new_safe_password
#
# Generates one high-entropy password from the approved dotenv-safe alphabet.
# The function retries only when a random draw misses one required character
# class, which is rare at the default length.
#
# Arguments:
#   $1 - password_length: number of characters to generate, minimum 16.
#
# Outputs:
#   A generated password that satisfies the complexity policy.
#
# Returns:
#   0 on success; non-zero when password_length is too short.
new_safe_password() {
    local password_length="$1"

    if [ "$password_length" -lt 16 ]; then
        echo "Password length must be at least 16 characters." >&2
        return 1
    fi

    local password index
    while true; do
        password=""
        for ((index = 0; index < password_length; index++)); do
            password+="$(get_secure_random_character "$SAFE_ALPHABET")"
        done

        if test_safe_password_complexity "$password"; then
            echo "$password"
            return 0
        fi
    done
}

# write_generated_passwords
#
# Writes generated passwords as secrets.env-compatible key-value lines.
#
# Arguments:
#   $1 - password_length: number of characters in each password.
#   Remaining arguments - names to emit.
#
# Outputs:
#   A policy header and generated KEY=value lines.
#
# Returns:
#   0 after all requested passwords are generated.
write_generated_passwords() {
    local password_length="$1"
    shift

    echo "# Safe production secrets"
    echo "# Length: $password_length"
    echo "# Alphabet: A-Z a-z 0-9 $SPECIAL_CHARS"
    echo "# Avoided: quotes, backslashes, whitespace, #, $, &, |, ;, <, >, brackets, equals"
    echo ""

    local name password
    for name in "$@"; do
        password=$(new_safe_password "$password_length")
        echo "$name=$password"
    done
}

#
# Argument parsing.
# Direct script invocation can customize length and count; launcher invocation
# uses defaults that match the deploy repository's secrets.env template.
#
PASSWORD_LENGTH=48
REQUESTED_COUNT=0
SINGLE_PASSWORD=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --length)
            PASSWORD_LENGTH="${2:-}"
            shift 2
            ;;
        --count)
            REQUESTED_COUNT="${2:-}"
            shift 2
            ;;
        --single)
            SINGLE_PASSWORD=true
            shift
            ;;
        --help|-h)
            show_password_generator_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_password_generator_help >&2
            exit 1
            ;;
    esac
done

if ! [[ "$PASSWORD_LENGTH" =~ ^[0-9]+$ ]]; then
    echo "Password length must be a number." >&2
    exit 1
fi

if ! [[ "$REQUESTED_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Password count must be a number." >&2
    exit 1
fi

if [ "$SINGLE_PASSWORD" = true ]; then
    OUTPUT_NAMES=("PASSWORD")
elif [ "$REQUESTED_COUNT" -gt 0 ]; then
    OUTPUT_NAMES=()
    for ((index = 1; index <= REQUESTED_COUNT; index++)); do
        OUTPUT_NAMES+=("PASSWORD_${index}")
    done
else
    OUTPUT_NAMES=("${DEFAULT_SECRET_NAMES[@]}")
fi

write_generated_passwords "$PASSWORD_LENGTH" "${OUTPUT_NAMES[@]}"
