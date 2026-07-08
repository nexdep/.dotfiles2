#!/usr/bin/env bash
# Install gomi (trash-can replacement for rm) from GitHub release binaries.
# Not packaged for apt. Release assets have version-independent names, so the
# latest/download redirect works without hitting the GitHub API.
set -euo pipefail

log() { printf '\033[1;34m[gomi]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[gomi]\033[0m %s\n' "$*" >&2; exit 1; }

if command -v gomi >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi

case "$(uname -m)" in
  x86_64) arch=x86_64 ;;
  aarch64) arch=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/babarot/gomi/releases/latest/download/gomi_Linux_${arch}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
binary="$(find "$tmp" -type f -name gomi | head -n1)"
[[ -n "$binary" ]] || die "gomi binary not found in release archive"

$SUDO install -m 0755 "$binary" /usr/local/bin/gomi
log "installed $(gomi --version 2>/dev/null || echo gomi)"
