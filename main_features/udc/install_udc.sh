# shellcheck shell=bash
# Paste this block into Bash on the Ubuntu server.
#
# The installer stages a self-contained udc executable and activates its PATH
# entry in the shell that receives the block.
bash <<'DEV_TOOLS_UDC_INSTALL' &&
set -euo pipefail

bin_dir="$HOME/.local/bin"
mkdir -p -- "$bin_dir"
udc_file=$(mktemp -- "$bin_dir/.udc.XXXXXX")
trap 'rm -f -- "$udc_file"' EXIT

cat > "$udc_file" <<'DEV_TOOLS_UDC'
#!/bin/bash
#
# Installs or updates the current user's Docker Scout CLI plugin from Docker's
# release assets after verifying the selected archive against its checksum.
#
set -euo pipefail

locale=${DEV_TOOLS_LOCALE:-${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}}
case "${locale,,}" in de|de[_@.-]*) language=de ;; *) language=en ;; esac
declare -A messages=()
while IFS='=' read -r key message; do
    if [[ "$key" == "$language.udc."* ]]; then
        messages["${key#"$language.udc."}"]=$message
    fi
done <<'DEV_TOOLS_UDC_MESSAGES'
# UDC_MESSAGES
DEV_TOOLS_UDC_MESSAGES

# Formats a catalog message using the arguments after its key.
udc_message() {
    local key=$1
    shift
    # shellcheck disable=SC2059
    printf "${messages[$key]}\n" "$@"
}

# Installs the staged executable and persists PATH for interactive Bash.
# The caller locks the bin directory to serialize installs for this account.
install_udc() {
    local staged_file=$1 bin_dir=$2
    local destination="$bin_dir/udc" profile="$HOME/.bashrc" path_line

    if [[ -e "$destination" || -L "$destination" ]]; then
        if [[ -L "$destination" || ! -f "$destination" || ! -x "$destination" ]] || ! cmp -s -- "$staged_file" "$destination"; then
            udc_message conflict "$destination" >&2
            return 1
        fi
    else
        chmod 0755 -- "$staged_file"
        ln -T -- "$staged_file" "$destination"
    fi

    case ":${PATH:-}:" in
        *":$bin_dir:"*) ;;
        *)
            # shellcheck disable=SC2016
            path_line='case ":${PATH:-}:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin${PATH:+:$PATH}" ;; esac # dev-tools udc'
            if ! grep -Fqx -- "$path_line" "$profile" 2>/dev/null; then
                printf '\n%s\n' "$path_line" >> "$profile"
            fi
            ;;
    esac
    udc_message installed "$destination"
}

# Downloads the current release into the plugin directory and replaces the
# installed binary only after verification and successful extraction.
update_docker_scout() {
    local arch dependency releases url tag answer version asset source_url plugins checksum
    local https=(--proto '=https' --proto-redir '=https' -fsSL)

    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=arm64 ;;
        *) udc_message unsupported_arch >&2; return 1 ;;
    esac
    for dependency in curl docker; do
        if ! command -v "$dependency" >/dev/null; then
            udc_message missing_command "$dependency" >&2
            return 1
        fi
    done

    releases=https://github.com/docker/scout-cli/releases
    url=$(curl -q "${https[@]}" -o /dev/null -w '%{url_effective}' "$releases/latest")
    tag=${url##*/}
    if [[ "$url" != "$releases/tag/$tag" || ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        udc_message invalid_release >&2
        return 1
    fi

    if ! read -r -p "$(udc_message prompt "$tag" "$(id -un)") " answer || [[ "$answer" != [yYjJ] ]]; then
        return 0
    fi

    version=${tag#v}
    asset="docker-scout_${version}_linux_${arch}.tar.gz"
    source_url="$releases/download/$tag"
    plugins=${DOCKER_CONFIG:-"$HOME/.docker"}/cli-plugins
    mkdir -p -- "$plugins"
    work=$(mktemp -d -- "$plugins/.udc.XXXXXX")
    trap 'rm -rf -- "$work"' EXIT

    curl -q "${https[@]}" "$source_url/$asset" -o "$work/$asset"
    curl -q "${https[@]}" "$source_url/docker-scout_${version}_checksums.txt" -o "$work/checksums.txt"
    if ! checksum=$(awk -v asset="$asset" '$2 == asset || $2 == "*" asset { count++; line=$0 } END { if (count != 1) exit 1; print line }' "$work/checksums.txt"); then
        udc_message invalid_checksum "$asset" >&2
        return 1
    fi
    (cd -- "$work" && sha256sum --check --strict <<< "$checksum")
    tar -xOzf "$work/$asset" -- docker-scout > "$work/docker-scout"
    test -s "$work/docker-scout"
    chmod 0755 -- "$work/docker-scout"
    mv -fT -- "$work/docker-scout" "$plugins/docker-scout"
    docker scout version
}

case "${1:-}" in
    --install)
        # The directory descriptor is used only for the lock.
        # shellcheck disable=SC2094
        (
            flock -x 9
            install_udc "${BASH_SOURCE[0]}" "$HOME/.local/bin"
        ) 9< "$HOME/.local/bin"
        ;;
    --help|-h|help) udc_message usage ;;
    '') update_docker_scout ;;
    *) udc_message usage >&2; exit 2 ;;
esac
DEV_TOOLS_UDC

bash -n "$udc_file"
bash "$udc_file" --install
DEV_TOOLS_UDC_INSTALL
case ":${PATH:-}:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin${PATH:+:$PATH}" ;;
esac
