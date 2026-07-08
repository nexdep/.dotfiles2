#!/usr/bin/env bash
# Install starship (cross-shell prompt) from GitHub release binaries.
# Not reliably available via apt. No aarch64-unknown-linux-gnu asset is
# published, so aarch64 uses the musl build (works fine on glibc systems).
set -euo pipefail

LOG_TAG=starship
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v starship >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) target=x86_64-unknown-linux-gnu ;;
  aarch64) target=aarch64-unknown-linux-musl ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/starship/starship/releases/latest/download/starship-${target}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
binary="$(find "$tmp" -type f -name starship | head -n1)"
[[ -n "$binary" ]] || die "starship binary not found in release archive"

$SUDO install -m 0755 "$binary" /usr/local/bin/starship
log "installed $(starship --version 2>/dev/null | head -n1 || echo starship)"
