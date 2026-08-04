#!/usr/bin/env bash
# Verify that repository setup preserves valid Deb822 sources, removes only a
# redundant one-line source, and rejects a Deb822 source with a broken keyring.
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir "$tmp_dir/sources" "$tmp_dir/keyrings"

export LOG_TAG=apt-repo-test
# shellcheck disable=SC1091  # path is resolved from this repository at runtime
source "$repo_dir/lib/common.sh"

# Keep the test entirely inside its temporary directory even when it runs as a
# non-root user.
export SUDO=""
APT_SOURCES_DIR="$tmp_dir/sources"
APT_KEYRINGS_DIR="$tmp_dir/keyrings"

printf '%s\n' \
  'Types: deb' \
  "Signed-By: $APT_KEYRINGS_DIR/gopass.gpg" \
  >"$APT_SOURCES_DIR/gopass.sources"
printf '%s\n' 'test keyring content' >"$APT_KEYRINGS_DIR/gopass.gpg"
printf '%s\n' 'deb https://example.invalid stable main' >"$APT_SOURCES_DIR/gopass.list"

reconcile_apt_repo_source gopass
test -f "$APT_SOURCES_DIR/gopass.sources"
test ! -e "$APT_SOURCES_DIR/gopass.list"

# add_apt_repo must return before downloading a key or writing a replacement
# .list when a Deb822 source already owns the repository configuration.
add_apt_repo gopass https://example.invalid/key.gpg "" \
  "https://example.invalid stable main"
test -f "$APT_SOURCES_DIR/gopass.sources"
test ! -e "$APT_SOURCES_DIR/gopass.list"
mapfile -t keyrings < <(find "$APT_KEYRINGS_DIR" -mindepth 1 -type f -printf '%f\n')
[[ "${keyrings[*]}" == 'gopass.gpg' ]]

# A script-managed .list without a Deb822 counterpart remains untouched.
printf '%s\n' 'deb https://example.invalid stable main' >"$APT_SOURCES_DIR/docker.list"
reconcile_apt_repo_source docker
test -f "$APT_SOURCES_DIR/docker.list"

# An interrupted package postinst can create the Deb822 source and truncate its
# keyring before writing the key. Keep a usable managed source in that case so
# apt can update and add_apt_repo can rebuild the vendor setup later.
printf '%s\n' \
  'Types: deb' \
  'URIs: https://packages.microsoft.com/repos/code' \
  "Signed-By: $APT_KEYRINGS_DIR/microsoft.gpg" \
  >"$APT_SOURCES_DIR/vscode.sources"
: >"$APT_KEYRINGS_DIR/microsoft.gpg"
printf '%s\n' 'deb https://packages.microsoft.com/repos/code stable main' \
  >"$APT_SOURCES_DIR/vscode.list"

reconcile_apt_repo_source vscode
test ! -e "$APT_SOURCES_DIR/vscode.sources"
test -f "$APT_SOURCES_DIR/vscode.list"

printf 'apt repository reconciliation smoke test passed\n'
