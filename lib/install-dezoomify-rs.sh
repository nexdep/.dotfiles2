#!/usr/bin/env bash
# Install dezoomify-rs (zoomable-image downloader) from GitHub release
# binaries. Not packaged for apt. The linux asset has a version-independent
# name, so the latest/download redirect works without hitting the GitHub API.
set -euo pipefail

LOG_TAG=dezoomify-rs
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v dezoomify-rs >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) ;; # only x86_64 linux binaries are published
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/lovasoa/dezoomify-rs/releases/latest/download/dezoomify-rs-linux.tgz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
binary="$(find "$tmp" -type f -name dezoomify-rs | head -n1)"
[[ -n "$binary" ]] || die "dezoomify-rs binary not found in release archive"

$SUDO install -m 0755 "$binary" /usr/local/bin/dezoomify-rs
log "installed $(dezoomify-rs --version 2>/dev/null | head -n1 || echo dezoomify-rs)"
