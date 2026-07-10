#!/usr/bin/env bash
# Install yazi (terminal file manager) and its ya CLI from GitHub release
# binaries. Not packaged for apt. Release assets have version-independent
# names, so the latest/download redirect works without hitting the GitHub API.
set -euo pipefail

LOG_TAG=yazi
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v yazi >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) target=x86_64-unknown-linux-gnu ;;
  aarch64) target=aarch64-unknown-linux-gnu ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${target}.zip"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL -o "$tmp/yazi.zip" "$url"
unzip -q "$tmp/yazi.zip" -d "$tmp"

# The zip holds both the file manager (yazi) and its CLI (ya, used by the
# chezmoi run script to install the plugins pinned in package.toml).
for bin in yazi ya; do
  binary="$(find "$tmp" -type f -name "$bin" | head -n1)"
  [[ -n "$binary" ]] || die "$bin binary not found in release archive"
  $SUDO install -m 0755 "$binary" "/usr/local/bin/$bin"
done
log "installed $(yazi --version 2>/dev/null || echo yazi)"
