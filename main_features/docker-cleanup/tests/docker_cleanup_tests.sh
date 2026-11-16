#!/bin/bash
#
# Checks cleanup flags and failure handling using a fake Docker executable.
#
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
export DEV_TOOLS_LOCALE=en DEV_TOOLS_UPDATE_REPLAYED=1
export DOCKER_CLEANUP_TEST_LOG="$test_dir/commands" DOCKER_CLEANUP_TEST_FAIL=''

cat > "$test_dir/docker" <<'DOCKER'
#!/bin/bash
printf '%s\n' "$*" >> "$DOCKER_CLEANUP_TEST_LOG"
if [[ "$2" == "$DOCKER_CLEANUP_TEST_FAIL" ]]; then
    exit 17
fi
DOCKER
chmod +x "$test_dir/docker"
export PATH="$test_dir:$PATH"
[[ "$(command -v docker)" == "$test_dir/docker" ]]

for answer in '' n y Y; do
    : > "$DOCKER_CLEANUP_TEST_LOG"
    printf '\n%s\n' "$answer" | bash "$root_dir/start.sh" --dc 2> "$test_dir/prompt"
    prompt=$(< "$test_dir/prompt")
    [[ "$prompt" == *'several minutes to finish. Continue? [Y/n]'*'permanently delete data. [y/N]'* ]]
    prune='system prune -a'
    if [[ "$answer" == [yY] ]]; then
        prune+=' --volumes'
    fi
    printf '%s\n' 'system df' "$prune" 'system df' | diff - "$DOCKER_CLEANUP_TEST_LOG"
done

: > "$DOCKER_CLEANUP_TEST_LOG"
[[ "$(bash "$root_dir/start.sh" --dc <<< n 2> "$test_dir/prompt")" == 'Docker cleanup canceled.' ]]
[[ "$(< "$test_dir/prompt")" == 'Docker cleanup may take several minutes to finish. Continue? [Y/n] ' ]]
DEV_TOOLS_LOCALE=de bash "$root_dir/start.sh" --docker-cleanup -h | grep -q '^Verwendung:'
result=0
bash "$root_dir/start.sh" --dc --volumes 2>/dev/null || result=$?
[[ "$result" == 2 ]]
result=0
bash "$root_dir/start.sh" --dc </dev/null 2>/dev/null || result=$?
[[ "$result" == 1 ]]
result=0
bash "$root_dir/start.sh" --dc <<< y 2>/dev/null || result=$?
[[ "$result" == 1 ]]
[[ ! -s "$DOCKER_CLEANUP_TEST_LOG" ]]

for failing_step in df prune; do
    : > "$DOCKER_CLEANUP_TEST_LOG"
    result=0
    DOCKER_CLEANUP_TEST_FAIL=$failing_step bash "$root_dir/start.sh" --dc <<< $'Y\n' 2>/dev/null || result=$?
    [[ "$result" == 17 ]]
    {
        printf '%s\n' 'system df'
        if [[ "$failing_step" == prune ]]; then
            printf '%s\n' 'system prune -a'
        fi
    } | diff - "$DOCKER_CLEANUP_TEST_LOG"
done
printf 'Bash Docker cleanup tests passed.\n'
