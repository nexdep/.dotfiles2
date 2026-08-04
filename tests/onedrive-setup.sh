#!/usr/bin/env bash
# Exercise OneDrive's legacy migration and OBS repository registration without
# reading or changing the host's apt configuration.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/apt/sources.list.d" "$tmp_dir/bin" "$tmp_dir/systemd"

export LOG_TAG=onedrive-test
# shellcheck disable=SC1091
source "$repo_dir/lib/common.sh"
# shellcheck disable=SC1091
source "$repo_dir/lib/onedrive.sh"

APT_MAIN_SOURCES_FILE="$tmp_dir/apt/sources.list"
APT_SOURCES_DIR="$tmp_dir/apt/sources.list.d"
ONEDRIVE_USER_SERVICE_LINK="$tmp_dir/systemd/onedrive.service"
export SUDO=""
export ONEDRIVE_TEST_APT_LOG="$tmp_dir/apt-get.log"

# The generated stub must expand its arguments when it runs, not while the
# fixture is written.
# shellcheck disable=SC2016
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\\n" "$*" >>"$ONEDRIVE_TEST_APT_LOG"' \
  >"$tmp_dir/bin/apt-get"
printf '%s\n' '#!/usr/bin/env bash' 'printf "install ok installed"' \
  >"$tmp_dir/bin/dpkg-query"
chmod +x "$tmp_dir/bin/apt-get" "$tmp_dir/bin/dpkg-query"
PATH="$tmp_dir/bin:$PATH"

printf '%s\n' \
  'deb http://archive.ubuntu.com/ubuntu resolute main' \
  'deb http://ppa.launchpad.net/yann1ck/onedrive/ubuntu resolute main' \
  >"$APT_MAIN_SOURCES_FILE"
printf '%s\n' \
  'deb https://ppa.launchpadcontent.net/yann1ck/onedrive/ubuntu resolute main' \
  >"$APT_SOURCES_DIR/yann1ck-ubuntu-onedrive-resolute.list"
printf '%s\n' 'deb https://example.invalid stable main' \
  >"$APT_SOURCES_DIR/unrelated.list"
printf '%s\n' \
  'Types: deb' \
  'URIs: https://example.invalid/onedrive' \
  >"$APT_SOURCES_DIR/onedrive.sources"
ln -s /usr/lib/systemd/user/onedrive.service "$ONEDRIVE_USER_SERVICE_LINK"

cleanup_legacy_onedrive

grep -Fq 'archive.ubuntu.com' "$APT_MAIN_SOURCES_FILE"
if grep -Eq "$ONEDRIVE_LEGACY_PPA_PATTERN" "$APT_MAIN_SOURCES_FILE"; then
  exit 1
fi
test ! -e "$APT_SOURCES_DIR/yann1ck-ubuntu-onedrive-resolute.list"
test -f "$APT_SOURCES_DIR/unrelated.list"
test ! -e "$APT_SOURCES_DIR/onedrive.sources"
test ! -L "$ONEDRIVE_USER_SERVICE_LINK"
grep -Fxq 'remove -y onedrive' "$ONEDRIVE_TEST_APT_LOG"

# Once the supported OBS source exists, a rerun must keep the installed package.
: >"$ONEDRIVE_TEST_APT_LOG"
printf 'deb [arch=amd64] %s ./\n' "$ONEDRIVE_OBS_REPO" \
  >"$APT_SOURCES_DIR/onedrive.list"
cleanup_legacy_onedrive
test -s "$APT_SOURCES_DIR/onedrive.list"
test ! -s "$ONEDRIVE_TEST_APT_LOG"

# Repository registration must retain the exact upstream 26.04 key, source,
# architecture option and flat-repository component.
add_apt_repo() {
  printf '%s\n' "$1" "$2" "$3" "$4" >"$tmp_dir/add-repo.args"
}
register_onedrive_repo
mapfile -t repo_args <"$tmp_dir/add-repo.args"
[[ "${repo_args[0]}" == onedrive ]]
[[ "${repo_args[1]}" == "${ONEDRIVE_OBS_REPO}Release.key" ]]
[[ "${repo_args[2]}" == "arch=$(dpkg --print-architecture)" ]]
[[ "${repo_args[3]}" == "$ONEDRIVE_OBS_REPO ./" ]]

printf 'OneDrive setup smoke test passed\n'
