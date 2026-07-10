#!/usr/bin/env bash
# Install lazygit from GitHub release binaries. Not packaged for apt. Release
# assets embed the version, so it is resolved from the releases/latest redirect
# instead of the GitHub API (rate limits in CI).
set -euo pipefail

LOG_TAG=lazygit
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v lazygit >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) arch=Linux_x86_64 ;;
  aarch64) arch=Linux_arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
  https://github.com/jesseduffield/lazygit/releases/latest)"
ver="${latest##*/v}"
[[ -n "$ver" && "$ver" != "$latest" ]] || die "could not resolve latest lazygit version"

url="https://github.com/jesseduffield/lazygit/releases/download/v${ver}/lazygit_${ver}_${arch}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp" lazygit
$SUDO install -m 0755 "$tmp/lazygit" /usr/local/bin/lazygit
log "installed $(lazygit --version | head -n1)"
