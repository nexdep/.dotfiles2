#!/usr/bin/env bash
# Install opencode (open-source terminal coding agent) from GitHub release
# binaries. Not packaged for apt. Release assets have version-independent
# names, so the latest/download redirect works without hitting the GitHub API.
# The official installer (opencode.ai/install) is not used: it unpacks into
# ~/.opencode/bin and appends a PATH export to the shell rc file, which the
# chezmoi-managed .zshrc would overwrite.
# No version is logged after installing: `opencode --version` hangs forever
# without a TTY (same trap as the GUI apps noted in tests/verify.sh), which
# would wedge bootstrap and CI.
set -euo pipefail

LOG_TAG=opencode
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v opencode >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) arch=x64 ;;
  aarch64) arch=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/anomalyco/opencode/releases/latest/download/opencode-linux-${arch}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
[[ -f "$tmp/opencode" ]] || die "opencode binary not found in release archive"

$SUDO install -m 0755 "$tmp/opencode" /usr/local/bin/opencode
log "installed opencode"
