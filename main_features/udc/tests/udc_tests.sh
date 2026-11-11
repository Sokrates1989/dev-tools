#!/bin/bash
#
# Exercises the rendered installer and updater using a disposable home and
# local Docker Scout release fixtures. No network or Docker daemon is used.
#
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export HOME="$test_dir/test home" DEV_TOOLS_LOCALE=en
export PATH=/usr/bin:/bin
mkdir -p -- "$HOME" "$test_dir/mock-bin" "$test_dir/release"
original_path=$PATH

installer="$test_dir/install-udc.sh"
DEV_TOOLS_UPDATE_REPLAYED=1 bash "$root_dir/start.sh" --udc --print > "$installer"
if [[ $# -gt 0 ]]; then
    cmp -- "$installer" "$1"
    installer=$1
fi
bash -n "$installer"

# Sourcing models pasting a block into an already-running Bash session.
printf '# keep this line\n' > "$HOME/.bashrc"
# shellcheck disable=SC1090
source "$installer"
[[ "$(command -v udc)" == "$HOME/.local/bin/udc" ]]
bash -n "$HOME/.local/bin/udc"
grep -Fxq '# keep this line' "$HOME/.bashrc"
[[ "$(DEV_TOOLS_LOCALE=de udc --help)" == Verwendung:* ]]
PATH=$original_path
DEV_TOOLS_LOCALE=de bash "$installer" >/dev/null
[[ "$(grep -Fc '# dev-tools udc' "$HOME/.bashrc")" == 1 ]]
bash -ic '[[ "$(command -v udc)" == "$HOME/.local/bin/udc" ]]' >/dev/null 2>&1

# The direct launcher also works with ~/.local/bin already on PATH.
original_home=$HOME
export HOME="$test_dir/direct" PATH="$test_dir/direct/.local/bin:$original_path"
DEV_TOOLS_UPDATE_REPLAYED=1 bash "$root_dir/start.sh" --udc >/dev/null
[[ -x "$HOME/.local/bin/udc" && ! -e "$HOME/.bashrc" ]]

export HOME="$test_dir/conflict" PATH=$original_path
mkdir -p -- "$HOME/.local/bin"
ln -s -- "$HOME/missing" "$HOME/.local/bin/udc"
if bash "$installer" >/dev/null 2>&1; then
    printf 'Installer unexpectedly replaced a symlink.\n' >&2
    exit 1
fi
[[ -L "$HOME/.local/bin/udc" && ! -e "$HOME/.bashrc" ]]

export HOME=$original_home
export PATH="$test_dir/mock-bin:$HOME/.local/bin:$original_path"
export UDC_TEST_RELEASE="$test_dir/release" DOCKER_CONFIG="$test_dir/docker-config"
case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) printf 'Updater fixtures require x86-64 or ARM64.\n' >&2; exit 1 ;;
esac
asset="docker-scout_1.2.3_linux_${arch}.tar.gz"
manifest="$UDC_TEST_RELEASE/docker-scout_1.2.3_checksums.txt"
printf '#!/bin/bash\nprintf "Docker Scout fixture\\n"\n' > "$test_dir/docker-scout"
tar -czf "$UDC_TEST_RELEASE/$asset" -C "$test_dir" docker-scout
(cd -- "$UDC_TEST_RELEASE" && sha256sum "$asset") > "$manifest"

cat > "$test_dir/mock-bin/curl" <<'MOCK_CURL'
#!/bin/bash
set -eu
for argument; do
    case "$argument" in
        https://github.com/docker/scout-cli/releases/latest)
            printf '%s' 'https://github.com/docker/scout-cli/releases/tag/v1.2.3'
            exit 0
            ;;
        https://github.com/docker/scout-cli/releases/download/v1.2.3/*)
            cp -- "$UDC_TEST_RELEASE/${argument##*/}" "${@: -1}"
            exit 0
            ;;
    esac
done
exit 1
MOCK_CURL
cat > "$test_dir/mock-bin/docker" <<'MOCK_DOCKER'
#!/bin/bash
set -eu
[[ "$*" == 'scout version' ]]
exec "$DOCKER_CONFIG/cli-plugins/docker-scout"
MOCK_DOCKER
chmod +x -- "$test_dir/mock-bin/curl" "$test_dir/mock-bin/docker"

udc <<< n
[[ ! -e "$DOCKER_CONFIG" ]]
[[ "$(udc <<< y)" == *'Docker Scout fixture' ]]
plugin="$DOCKER_CONFIG/cli-plugins/docker-scout"
cmp -- "$test_dir/docker-scout" "$plugin"

for name in "$asset" unrelated.tar.gz; do
    printf '%064d  %s\n' 0 "$name" > "$manifest"
    if udc <<< y >/dev/null 2>&1; then
        printf 'Updater accepted an invalid or missing checksum.\n' >&2
        exit 1
    fi
    cmp -- "$test_dir/docker-scout" "$plugin"
done

printf 'udc installer and updater tests passed.\n'
