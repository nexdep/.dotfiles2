#!/usr/bin/env bash
# Install Neovim from the official GitHub release tarball into /opt/nvim.
# Ubuntu's apt package lags far behind upstream. Release assets have
# version-independent names, so the latest/download redirect works without
# hitting the GitHub API.
set -euo pipefail

LOG_TAG=neovim
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ -x /opt/nvim/bin/nvim ]]; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) arch=x86_64 ;;
  aarch64) arch=arm64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${arch}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -x "$extracted/bin/nvim" ]] || die "nvim binary not found in release archive"

$SUDO rm -rf /opt/nvim
$SUDO mv "$extracted" /opt/nvim
$SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
log "installed $(/usr/local/bin/nvim --version | head -n1)"
