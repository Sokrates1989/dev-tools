#!/bin/bash
#
# Safe startup update checks and manual Dev Tools updates.
#
# Loads localized messages, classifies the checkout against its configured
# upstream, caches successful checks, prompts eligible interactive sessions,
# and applies only clean fast-forward updates from the official repository.
#

# Public state variables are consumed by dispatchers after this file is sourced.
# shellcheck disable=SC2034

DEV_TOOLS_EXPECTED_REMOTE_IDENTITY="github.com/sokrates1989/dev-tools"
DEV_TOOLS_EXPECTED_BRANCH="main"
DEV_TOOLS_DEFAULT_CHECK_INTERVAL_SECONDS=300
DEV_TOOLS_UPDATE_LOCALE_FILE=""
DEV_TOOLS_UPDATE_STATE="unavailable"
DEV_TOOLS_UPDATE_BRANCH=""
DEV_TOOLS_UPDATE_UPSTREAM=""
DEV_TOOLS_UPDATE_LOCAL_COMMIT=""
DEV_TOOLS_UPDATE_REMOTE_COMMIT=""
DEV_TOOLS_UPDATE_PERFORMED="false"
DEVTOOLS_UPDATE_AVAILABLE="0"

# initialize_dev_tools_update_messages
#
# Selects the shared English or German launcher catalog.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root containing locales.
#
# Returns:
#   0 when the locale file exists; 1 otherwise.
initialize_dev_tools_update_messages() {
    local root_dir="$1"
    local requested_locale language
    requested_locale="${DEV_TOOLS_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}"

    case "$requested_locale" in
        de|de[_-]*|DE|DE[_-]*) language="de" ;;
        *) language="en" ;;
    esac

    DEV_TOOLS_UPDATE_LOCALE_FILE="${root_dir}/locales/${language}.properties"
    [ -f "$DEV_TOOLS_UPDATE_LOCALE_FILE" ]
}

# get_dev_tools_update_message
#
# Returns one shared localized update message without interpreting percent
# characters.
#
# Arguments:
#   $1 - key: stable locale-catalog key.
#
# Outputs:
#   The localized message.
#
# Returns:
#   0 when the key exists; 1 otherwise.
get_dev_tools_update_message() {
    local key="$1"
    local line message_key message_value

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [ -z "$line" ] || [ "${line#\#}" != "$line" ]; then
            continue
        fi

        message_key="${line%%=*}"
        if [ "$message_key" = "$key" ]; then
            message_value="${line#*=}"
            printf '%s' "$message_value"
            return 0
        fi
    done < "$DEV_TOOLS_UPDATE_LOCALE_FILE"

    printf 'Missing Dev Tools update message key: %s\n' "$key" >&2
    return 1
}

# format_dev_tools_update_message
#
# Formats one localized message with ordered %s placeholders.
#
# Arguments:
#   $1 - key: stable locale-catalog key.
#   Remaining arguments - placeholder values.
#
# Outputs:
#   The formatted localized message.
#
# Returns:
#   0 when the key exists and formatting succeeds; 1 otherwise.
format_dev_tools_update_message() {
    local key="$1" message remaining prefix formatted argument
    shift
    message=$(get_dev_tools_update_message "$key") || return 1
    remaining="$message"
    formatted=""

    for argument in "$@"; do
        if [[ "$remaining" != *"%s"* ]]; then
            printf 'Dev Tools update message key has too few placeholders: %s\n' "$key" >&2
            return 1
        fi

        prefix="${remaining%%\%s*}"
        formatted="${formatted}${prefix}${argument}"
        remaining="${remaining#*%s}"
    done

    printf '%s' "${formatted}${remaining}"
}

# normalize_dev_tools_remote_identity
#
# Normalizes HTTPS, SSH, SCP-style, or local Git remote URLs.
#
# Arguments:
#   $1 - remote_url: Git remote URL to normalize.
#
# Outputs:
#   Lowercase host/path identity without credentials or .git.
normalize_dev_tools_remote_identity() {
    local identity="$1"
    identity="${identity//\\//}"

    if [[ "$identity" != *"://"* && "$identity" == *@*:* ]]; then
        local host_and_path="${identity#*@}"
        identity="${host_and_path/:/\/}"
    else
        identity="${identity#*://}"
        identity="${identity#*@}"
    fi

    identity="${identity%%\?*}"
    identity="${identity%%\#*}"
    identity="${identity%/}"
    identity="${identity%.git}"
    printf '%s' "$identity" | tr '[:upper:]' '[:lower:]'
}

# get_dev_tools_update_check_interval
#
# Outputs:
#   Configured non-negative cache interval in seconds.
get_dev_tools_update_check_interval() {
    local interval="${DEV_TOOLS_UPDATE_CHECK_INTERVAL_SECONDS:-$DEV_TOOLS_DEFAULT_CHECK_INTERVAL_SECONDS}"
    if [[ "$interval" =~ ^[0-9]+$ ]]; then
        printf '%s' "$interval"
    else
        printf '%s' "$DEV_TOOLS_DEFAULT_CHECK_INTERVAL_SECONDS"
    fi
}

# get_file_modified_epoch
#
# Returns a file modification timestamp on GNU and BSD/macOS systems.
#
# Arguments:
#   $1 - path: existing file path.
#
# Outputs:
#   Unix epoch seconds.
#
# Returns:
#   0 when either stat variant succeeds; 1 otherwise.
get_file_modified_epoch() {
    local path="$1"
    stat -c '%Y' "$path" 2>/dev/null || stat -f '%m' "$path" 2>/dev/null
}

# test_dev_tools_update_cache
#
# Tests whether a successful check for the current HEAD remains fresh.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root.
#   $2 - local_commit: current full HEAD identifier.
#
# Returns:
#   0 when the cache is fresh for local_commit; 1 otherwise.
test_dev_tools_update_cache() {
    local root_dir="$1"
    local local_commit="$2"
    local interval cache_path cached_commit modified_epoch current_epoch
    interval=$(get_dev_tools_update_check_interval)
    [ "$interval" -gt 0 ] || return 1

    cache_path="${root_dir}/.git/dev-tools-update-check"
    [ -f "$cache_path" ] || return 1
    cached_commit=""
    IFS= read -r cached_commit < "$cache_path" || [ -n "$cached_commit" ] || return 1
    [ "$cached_commit" = "$local_commit" ] || return 1

    modified_epoch=$(get_file_modified_epoch "$cache_path") || return 1
    current_epoch=$(date +%s)
    [ $((current_epoch - modified_epoch)) -lt "$interval" ]
}

# set_dev_tools_update_cache
#
# Records a successful remote check for the current HEAD. Cache write failures
# are non-fatal so read-only installations can still run commands.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root.
#   $2 - local_commit: full HEAD identifier associated with the check.
set_dev_tools_update_cache() {
    local root_dir="$1"
    local local_commit="$2"
    printf '%s\n' "$local_commit" > "${root_dir}/.git/dev-tools-update-check" 2>/dev/null || true
}

# set_dev_tools_update_state
#
# Stores one structured update classification in shared shell variables.
#
# Arguments:
#   $1 - state.
#   $2 - branch.
#   $3 - upstream.
#   $4 - local_commit.
#   $5 - remote_commit.
set_dev_tools_update_state() {
    DEV_TOOLS_UPDATE_STATE="$1"
    DEV_TOOLS_UPDATE_BRANCH="${2:-}"
    DEV_TOOLS_UPDATE_UPSTREAM="${3:-}"
    DEV_TOOLS_UPDATE_LOCAL_COMMIT="${4:-}"
    DEV_TOOLS_UPDATE_REMOTE_COMMIT="${5:-}"
}

# get_dev_tools_update_state
#
# Validates the checkout and classifies it against the fetched upstream.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root.
#   $2 - use_cache: true to allow a fresh successful-check cache.
#   $3 - expected_remote_identity: optional normalized identity for tests.
#
# Global state:
#   Sets DEV_TOOLS_UPDATE_STATE and related context variables.
#
# Returns:
#   0 after classification. Unavailable Git or network becomes state unavailable.
get_dev_tools_update_state() {
    local root_dir="$1"
    local use_cache="${2:-true}"
    local expected_remote_identity="${3:-$DEV_TOOLS_EXPECTED_REMOTE_IDENTITY}"
    local inside_work_tree local_commit branch working_changes upstream origin_url normalized_origin remote_commit

    set_dev_tools_update_state "unavailable" "" "" "" ""
    command -v git >/dev/null 2>&1 || return 0

    inside_work_tree=$(git -C "$root_dir" rev-parse --is-inside-work-tree 2>/dev/null) || return 0
    [ "$inside_work_tree" = "true" ] || return 0

    local_commit=$(git -C "$root_dir" rev-parse HEAD 2>/dev/null) || return 0
    branch=$(git -C "$root_dir" symbolic-ref --quiet --short HEAD 2>/dev/null) || {
        set_dev_tools_update_state "detached" "" "" "$local_commit" ""
        return 0
    }

    if [ "$branch" != "$DEV_TOOLS_EXPECTED_BRANCH" ]; then
        set_dev_tools_update_state "unexpected-branch" "$branch" "" "$local_commit" ""
        return 0
    fi

    working_changes=$(git -C "$root_dir" status --porcelain --untracked-files=normal 2>/dev/null) || return 0
    if [ -n "$working_changes" ]; then
        set_dev_tools_update_state "dirty" "$branch" "" "$local_commit" ""
        return 0
    fi

    upstream=$(git -C "$root_dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
        set_dev_tools_update_state "missing-upstream" "$branch" "" "$local_commit" ""
        return 0
    }
    if [ "$upstream" != "origin/main" ]; then
        set_dev_tools_update_state "unexpected-upstream" "$branch" "$upstream" "$local_commit" ""
        return 0
    fi

    origin_url=$(git -C "$root_dir" remote get-url origin 2>/dev/null) || {
        set_dev_tools_update_state "unexpected-origin" "$branch" "$upstream" "$local_commit" ""
        return 0
    }
    normalized_origin=$(normalize_dev_tools_remote_identity "$origin_url")
    if [ "$normalized_origin" != "$expected_remote_identity" ]; then
        set_dev_tools_update_state "unexpected-origin" "$branch" "$upstream" "$local_commit" ""
        return 0
    fi

    if [ "$use_cache" = "true" ] && test_dev_tools_update_cache "$root_dir" "$local_commit"; then
        set_dev_tools_update_state "cached" "$branch" "$upstream" "$local_commit" ""
        return 0
    fi

    git -C "$root_dir" fetch --quiet origin 2>/dev/null || return 0
    remote_commit=$(git -C "$root_dir" rev-parse "$upstream" 2>/dev/null) || return 0
    if [ "$local_commit" = "$remote_commit" ]; then
        set_dev_tools_update_cache "$root_dir" "$local_commit"
        set_dev_tools_update_state "equal" "$branch" "$upstream" "$local_commit" "$remote_commit"
    elif git -C "$root_dir" merge-base --is-ancestor "$local_commit" "$remote_commit" 2>/dev/null; then
        set_dev_tools_update_state "behind" "$branch" "$upstream" "$local_commit" "$remote_commit"
    elif git -C "$root_dir" merge-base --is-ancestor "$remote_commit" "$local_commit" 2>/dev/null; then
        set_dev_tools_update_state "ahead" "$branch" "$upstream" "$local_commit" "$remote_commit"
    else
        set_dev_tools_update_state "diverged" "$branch" "$upstream" "$local_commit" "$remote_commit"
    fi
}

# write_dev_tools_update_state_notice
#
# Prints an actionable localized notice for unsafe update states. Cached and
# remote-unavailable states remain silent.
write_dev_tools_update_state_notice() {
    local message_key=""
    case "$DEV_TOOLS_UPDATE_STATE" in
        dirty) message_key="updates.dirty" ;;
        ahead) message_key="updates.ahead" ;;
        diverged) message_key="updates.diverged" ;;
        detached) message_key="updates.detached" ;;
        missing-upstream) message_key="updates.missing_upstream" ;;
        unexpected-upstream) message_key="updates.unexpected_upstream" ;;
        unexpected-origin) message_key="updates.unexpected_origin" ;;
        unexpected-branch) message_key="updates.unexpected_branch" ;;
    esac

    if [ -n "$message_key" ]; then
        printf '%s\n' "$(get_dev_tools_update_message "$message_key")" >&2
    fi
}

# is_dev_tools_interactive_session
#
# Returns:
#   0 only for a terminal session outside common CI environments.
is_dev_tools_interactive_session() {
    case "${CI:-}" in ""|0|false) ;; *) return 1 ;; esac
    case "${TF_BUILD:-}" in ""|0|false) ;; *) return 1 ;; esac
    case "${GITHUB_ACTIONS:-}" in ""|0|false) ;; *) return 1 ;; esac
    [ -t 0 ] && [ -t 1 ]
}

# read_dev_tools_update_confirmation
#
# Prompts whether the available update should be installed. Enter defaults to
# yes; English and German yes/no words are accepted.
#
# Returns:
#   0 for yes; 1 for no.
read_dev_tools_update_confirmation() {
    local answer
    while true; do
        read -r -p "$(get_dev_tools_update_message updates.prompt): " answer
        case "$answer" in
            ""|y|Y|yes|YES|Yes|j|J|ja|JA|Ja) return 0 ;;
            n|N|no|NO|No|nein|NEIN|Nein) return 1 ;;
            *) printf '%s\n' "$(get_dev_tools_update_message updates.invalid)" >&2 ;;
        esac
    done
}

# invoke_dev_tools_update
#
# Applies a clean fast-forward update after a fresh repository classification.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root.
#   $2 - expected_remote_identity: optional normalized identity for tests.
#
# Returns:
#   0 when already current or updated successfully; 1 otherwise.
invoke_dev_tools_update() {
    local root_dir="$1"
    local expected_remote_identity="${2:-$DEV_TOOLS_EXPECTED_REMOTE_IDENTITY}"
    local current_commit working_changes old_short_commit new_short_commit

    # Reclassify immediately before mutation so a stale prompt or cache can
    # never authorize an update after repository state has changed.
    get_dev_tools_update_state "$root_dir" false "$expected_remote_identity"

    if [ "$DEV_TOOLS_UPDATE_STATE" = "equal" ]; then
        printf '%s\n' "$(get_dev_tools_update_message updates.current)"
        return 0
    fi
    if [ "$DEV_TOOLS_UPDATE_STATE" != "behind" ]; then
        write_dev_tools_update_state_notice
        if [ "$DEV_TOOLS_UPDATE_STATE" = "unavailable" ]; then
            printf '%s\n' "$(get_dev_tools_update_message updates.failed)" >&2
        fi
        return 1
    fi

    current_commit=$(git -C "$root_dir" rev-parse HEAD 2>/dev/null) || return 1
    working_changes=$(git -C "$root_dir" status --porcelain --untracked-files=normal 2>/dev/null) || return 1
    if [ "$current_commit" != "$DEV_TOOLS_UPDATE_LOCAL_COMMIT" ] || [ -n "$working_changes" ]; then
        printf '%s\n' "$(get_dev_tools_update_message updates.failed)" >&2
        return 1
    fi

    old_short_commit="${DEV_TOOLS_UPDATE_LOCAL_COMMIT:0:7}"
    new_short_commit="${DEV_TOOLS_UPDATE_REMOTE_COMMIT:0:7}"
    format_dev_tools_update_message updates.performing "$old_short_commit" "$new_short_commit"
    printf '\n'

    if ! git -C "$root_dir" merge --ff-only "$DEV_TOOLS_UPDATE_REMOTE_COMMIT"; then
        printf '%s\n' "$(get_dev_tools_update_message updates.failed)" >&2
        return 1
    fi

    set_dev_tools_update_cache "$root_dir" "$DEV_TOOLS_UPDATE_REMOTE_COMMIT"
    format_dev_tools_update_message updates.complete "$old_short_commit" "$new_short_commit"
    printf '\n'
    return 0
}

# invoke_dev_tools_startup_update_check
#
# Runs the once-per-launch interactive guard and records whether dispatcher
# replay is required.
#
# Arguments:
#   $1 - root_dir: Dev Tools repository root.
#   $2 - is_interactive: optional true/false override for focused tests.
#   $3 - expected_remote_identity: optional normalized identity for tests.
#
# Global state:
#   Sets DEV_TOOLS_UPDATE_PERFORMED and DEVTOOLS_UPDATE_AVAILABLE.
#
# Returns:
#   0 regardless of update availability so normal commands always continue.
invoke_dev_tools_startup_update_check() {
    local root_dir="$1"
    local is_interactive="${2:-auto}"
    local expected_remote_identity="${3:-$DEV_TOOLS_EXPECTED_REMOTE_IDENTITY}"
    local old_short_commit new_short_commit
    DEV_TOOLS_UPDATE_PERFORMED="false"
    DEVTOOLS_UPDATE_AVAILABLE="0"
    initialize_dev_tools_update_messages "$root_dir" || return 0

    if [ "$is_interactive" = "auto" ]; then
        is_dev_tools_interactive_session || return 0
    elif [ "$is_interactive" != "true" ]; then
        return 0
    fi

    get_dev_tools_update_state "$root_dir" true "$expected_remote_identity"
    if [ "$DEV_TOOLS_UPDATE_STATE" != "behind" ]; then
        write_dev_tools_update_state_notice
        return 0
    fi

    old_short_commit="${DEV_TOOLS_UPDATE_LOCAL_COMMIT:0:7}"
    new_short_commit="${DEV_TOOLS_UPDATE_REMOTE_COMMIT:0:7}"
    printf '\n'
    format_dev_tools_update_message updates.available "$old_short_commit" "$new_short_commit"
    printf '\n'

    if ! read_dev_tools_update_confirmation; then
        printf '%s\n' "$(get_dev_tools_update_message updates.declined)"
        DEVTOOLS_UPDATE_AVAILABLE="1"
        return 0
    fi

    if invoke_dev_tools_update "$root_dir" "$expected_remote_identity"; then
        DEV_TOOLS_UPDATE_PERFORMED="true"
    else
        DEVTOOLS_UPDATE_AVAILABLE="1"
    fi
}
