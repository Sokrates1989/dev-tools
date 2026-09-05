#!/bin/bash
# shellcheck disable=SC2034
#
# Core repository parsing and managed deploy-key operations.
#
# This module owns deterministic identities, paths, and key lifecycle behavior.
# It does not print private key material or modify SSH client configuration.
#

DEPLOY_KEY_PROVIDER=""
DEPLOY_KEY_OWNER=""
DEPLOY_KEY_REPOSITORY=""
DEPLOY_KEY_REPOSITORY_ID=""
DEPLOY_KEY_STATUS=""
DEPLOY_KEY_PUBLIC_RECOVERED="false"

# Parses a supported HTTPS, SSH URI, or SCP-style Git repository URL.
#
# Arguments:
#   $1 - candidate: one URL-shaped input token.
#
# Global state:
#   Populates the normalized repository identity variables on success.
#
# Returns:
#   0 for a valid host/owner/repository URL; 1 otherwise.
normalize_deploy_key_repository_url() {
    local candidate="$1"
    local authority path host owner repository

    candidate="${candidate%$'\r'}"
    candidate="${candidate%%\#*}"
    candidate="${candidate%%\?*}"

    while [[ "$candidate" == */ ]]; do
        candidate="${candidate%/}"
    done

    case "$candidate" in
        http://*|https://*|ssh://*|git://*)
            authority="${candidate#*://}"
            if [[ "$authority" != */* ]]; then
                return 1
            fi
            path="${authority#*/}"
            authority="${authority%%/*}"
            host="${authority##*@}"
            if [[ "$host" == *:* ]]; then
                return 1
            fi
            ;;
        *@*:*)
            authority="${candidate%%:*}"
            path="${candidate#*:}"
            host="${authority##*@}"
            ;;
        *)
            return 1
            ;;
    esac

    path="${path#/}"
    while [[ "$path" == */ ]]; do
        path="${path%/}"
    done
    path="${path%.git}"

    if [[ "$path" != */* ]]; then
        return 1
    fi

    owner="${path%%/*}"
    repository="${path#*/}"
    if [[ "$repository" == */* ]]; then
        return 1
    fi

    if [[ ! "$host" =~ ^[A-Za-z0-9.-]+$ ]] ||
        [[ ! "$owner" =~ ^[A-Za-z0-9._-]+$ ]] ||
        [[ ! "$repository" =~ ^[A-Za-z0-9._-]+$ ]]; then
        return 1
    fi

    if [[ "$owner" == "." || "$owner" == ".." ||
        "$repository" == "." || "$repository" == ".." ]]; then
        return 1
    fi

    host="${host,,}"
    if [ "$host" = "github.com" ]; then
        owner="${owner,,}"
        repository="${repository,,}"
    fi

    DEPLOY_KEY_PROVIDER="$host"
    DEPLOY_KEY_OWNER="$owner"
    DEPLOY_KEY_REPOSITORY="$repository"
    DEPLOY_KEY_REPOSITORY_ID="${host}/${owner}/${repository}"
}

# Finds the first valid repository URL in pasted text such as git remote output.
#
# Arguments:
#   $1 - input_block: one or more pasted lines.
#
# Global state:
#   Populates the normalized repository identity variables on success.
#
# Returns:
#   0 when a valid repository URL is found; 1 otherwise.
extract_deploy_key_repository() {
    local input_block="$1"
    local line token
    local -a fields=()

    while IFS= read -r line || [ -n "$line" ]; do
        fields=()
        read -r -a fields <<< "$line"
        for token in "${fields[@]}"; do
            if normalize_deploy_key_repository_url "$token"; then
                return 0
            fi
        done
    done <<< "$input_block"

    return 1
}

# Encodes one identity component for collision-safe managed filenames.
#
# Underscores and unsafe bytes use reserved escape sequences so the double
# underscore separator cannot occur inside an encoded component.
#
# Arguments:
#   $1 - value: non-empty identity component.
#
# Outputs:
#   A filesystem-safe component that preserves case distinctions.
#
# Returns:
#   0 for non-empty input; 1 otherwise.
encode_deploy_key_filename_component() {
    local value="$1"
    local output=""
    local character hex index
    local LC_ALL=C

    if [ -z "$value" ]; then
        return 1
    fi

    for ((index = 0; index < ${#value}; index++)); do
        character="${value:index:1}"
        case "$character" in
            [a-z0-9.-]) output+="$character" ;;
            [A-Z]) output+="_c${character,,}" ;;
            _) output+="_u" ;;
            *)
                printf -v hex '%02x' "'$character"
                output+="_x${hex}"
                ;;
        esac
    done

    printf '%s' "$output"
}

# Builds the deterministic filename for one repository and hostname pair.
#
# Arguments:
#   $1 - provider: normalized Git host.
#   $2 - owner: normalized repository owner.
#   $3 - repository: normalized repository name.
#   $4 - hostname: detected server hostname.
#
# Outputs:
#   The filename without a directory or public-key suffix.
get_deploy_key_basename() {
    local provider owner repository hostname
    provider=$(encode_deploy_key_filename_component "$1") || return 1
    owner=$(encode_deploy_key_filename_component "$2") || return 1
    repository=$(encode_deploy_key_filename_component "$3") || return 1
    hostname=$(encode_deploy_key_filename_component "$4") || return 1

    printf '%s__%s__%s__%s' "$provider" "$owner" "$repository" "$hostname"
}

# Builds a readable SSH alias with component lengths to prevent collisions.
#
# Arguments:
#   $1 - provider: normalized Git host.
#   $2 - owner: normalized repository owner.
#   $3 - repository: normalized repository name.
#
# Outputs:
#   A deterministic SSH Host alias.
get_deploy_key_ssh_alias() {
    local provider owner repository
    provider=$(encode_deploy_key_filename_component "$1") || return 1
    owner=$(encode_deploy_key_filename_component "$2") || return 1
    repository=$(encode_deploy_key_filename_component "$3") || return 1

    printf '%s-%s-%s--p%s-o%s-r%s' \
        "$provider" "$owner" "$repository" \
        "${#provider}" "${#owner}" "${#repository}"
}

# Detects and returns the current machine hostname.
#
# Outputs:
#   The real hostname as reported by hostname(1).
#
# Returns:
#   0 for a non-empty hostname; 1 otherwise.
detect_deploy_key_hostname() {
    local detected_hostname
    detected_hostname=$(hostname 2>/dev/null) || return 1
    detected_hostname="${detected_hostname%$'\r'}"
    if [ -z "$detected_hostname" ] || [[ "$detected_hostname" == *$'\n'* ]]; then
        return 1
    fi

    printf '%s' "$detected_hostname"
}

# Returns the default dev-tools managed deploy-key directory.
#
# Arguments:
#   $1 - ssh_directory: the current user's SSH directory.
#
# Outputs:
#   The deploy-key directory below the supplied SSH directory.
get_managed_deploy_key_directory() {
    printf '%s/dev-tools/deploy-keys' "$1"
}

# Creates the managed directory hierarchy with restrictive permissions.
#
# Arguments:
#   $1 - ssh_directory: the current user's SSH directory.
#
# Returns:
#   0 when all directories are safe and ready; 1 otherwise.
prepare_managed_deploy_key_directory() {
    local ssh_directory="$1"
    local dev_tools_directory="${ssh_directory}/dev-tools"
    local deploy_key_directory
    deploy_key_directory=$(get_managed_deploy_key_directory "$ssh_directory")

    if [ -L "$dev_tools_directory" ] || [ -L "$deploy_key_directory" ]; then
        return 1
    fi
    if { [ -e "$dev_tools_directory" ] && [ ! -d "$dev_tools_directory" ]; } ||
        { [ -e "$deploy_key_directory" ] && [ ! -d "$deploy_key_directory" ]; }; then
        return 1
    fi

    (
        umask 077
        mkdir -p "$deploy_key_directory"
    ) || return 1
    chmod 700 "$ssh_directory" "$dev_tools_directory" "$deploy_key_directory" || return 1
}

# Derives public key material from one unencrypted private key.
#
# Arguments:
#   $1 - private_key_path: existing private key path.
#
# Outputs:
#   The OpenSSH key type and base64 public key fields.
#
# Returns:
#   The ssh-keygen exit status.
derive_deploy_key_public_material() {
    local raw_material key_type key_body remainder
    raw_material=$(ssh-keygen -y -P "" -f "$1") || return 1
    IFS=' ' read -r key_type key_body remainder <<< "$raw_material"
    if [ -z "$key_type" ] || [ -z "$key_body" ]; then
        return 1
    fi

    printf '%s %s' "$key_type" "$key_body"
}

# Verifies that existing public and private key files form the same pair.
#
# Arguments:
#   $1 - private_key_path: existing private key path.
#   $2 - public_key_path: existing public key path.
#
# Returns:
#   0 when both key-material fields match; 1 otherwise.
deploy_key_pair_matches() {
    local private_key_path="$1"
    local public_key_path="$2"
    local derived_material public_type public_body remainder

    derived_material=$(derive_deploy_key_public_material "$private_key_path" 2>/dev/null) || return 1
    IFS=' ' read -r public_type public_body remainder < "$public_key_path" || return 1
    [ "$derived_material" = "${public_type} ${public_body}" ]
}

# Restores a missing public key from an existing managed private key.
#
# Arguments:
#   $1 - private_key_path: existing private key path.
#   $2 - public_key_path: public key path to create.
#   $3 - key_comment: comment appended to the recovered public key.
#
# Returns:
#   0 when recovery and permissions succeed; 1 otherwise.
recover_deploy_key_public_file() {
    local private_key_path="$1"
    local public_key_path="$2"
    local key_comment="$3"
    local public_material

    public_material=$(derive_deploy_key_public_material "$private_key_path" 2>/dev/null) || return 1
    (
        umask 077
        printf '%s %s\n' "$public_material" "$key_comment" > "$public_key_path"
    ) || return 1
    chmod 644 "$public_key_path"
}

# Ensures one deterministic managed deploy key exists without overwriting it.
#
# Arguments:
#   $1 - private_key_path: deterministic private key path.
#   $2 - key_comment: identifying comment for a new or recovered public key.
#
# Global state:
#   Sets DEPLOY_KEY_STATUS and DEPLOY_KEY_PUBLIC_RECOVERED.
#
# Returns:
#   0 when a key is created or safely reused.
#   10 when only the public key exists.
#   11 when either path is a symlink or non-regular file.
#   12 when the existing key pair does not match.
#   13 when key creation fails.
#   14 when public-key recovery fails.
ensure_managed_deploy_key() {
    local private_key_path="$1"
    local key_comment="$2"
    local public_key_path="${private_key_path}.pub"
    local private_exists="false"
    local public_exists="false"

    DEPLOY_KEY_STATUS=""
    DEPLOY_KEY_PUBLIC_RECOVERED="false"

    if [ -e "$private_key_path" ] || [ -L "$private_key_path" ]; then
        private_exists="true"
    fi
    if [ -e "$public_key_path" ] || [ -L "$public_key_path" ]; then
        public_exists="true"
    fi

    if { [ "$private_exists" = "true" ] && { [ -L "$private_key_path" ] || [ ! -f "$private_key_path" ]; }; } ||
        { [ "$public_exists" = "true" ] && { [ -L "$public_key_path" ] || [ ! -f "$public_key_path" ]; }; }; then
        return 11
    fi

    if [ "$private_exists" = "false" ] && [ "$public_exists" = "true" ]; then
        return 10
    fi

    if [ "$private_exists" = "true" ] && [ "$public_exists" = "true" ]; then
        if ! deploy_key_pair_matches "$private_key_path" "$public_key_path"; then
            return 12
        fi
        chmod 600 "$private_key_path" || return 11
        chmod 644 "$public_key_path" || return 11
        DEPLOY_KEY_STATUS="ALREADY EXISTS"
        return 0
    fi

    if [ "$private_exists" = "true" ]; then
        if ! recover_deploy_key_public_file "$private_key_path" "$public_key_path" "$key_comment"; then
            return 14
        fi
        chmod 600 "$private_key_path" || return 11
        DEPLOY_KEY_STATUS="ALREADY EXISTS"
        DEPLOY_KEY_PUBLIC_RECOVERED="true"
        return 0
    fi

    if ! (
        umask 077
        ssh-keygen -q -t ed25519 -N "" -C "$key_comment" -f "$private_key_path" </dev/null
    ); then
        return 13
    fi

    chmod 600 "$private_key_path" || return 13
    chmod 644 "$public_key_path" || return 13
    DEPLOY_KEY_STATUS="CREATED"
}
