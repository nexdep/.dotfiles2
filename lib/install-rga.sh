#!/usr/bin/env bash
# Install ripgrep-all (rga: ripgrep across PDFs, archives, docs via pandoc)
# from GitHub release binaries. Not packaged for apt. Release assets embed the
# version, so it is resolved from the releases/latest redirect instead of the
# GitHub API (rate limits in CI).
set -euo pipefail

LOG_TAG=rga
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v rga >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) target=x86_64-unknown-linux-musl ;;
  aarch64) target=aarch64-unknown-linux-gnu ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

latest="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
  https://github.com/phiresky/ripgrep-all/releases/latest)"
ver="${latest##*/v}"
[[ -n "$ver" && "$ver" != "$latest" ]] || die "could not resolve latest ripgrep-all version"

url="https://github.com/phiresky/ripgrep-all/releases/download/v${ver}/ripgrep_all-v${ver}-${target}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
for bin in rga rga-fzf rga-preproc; do
  binary="$(find "$tmp" -type f -name "$bin" | head -n1)"
  [[ -n "$binary" ]] || die "$bin binary not found in release archive"
  $SUDO install -m 0755 "$binary" "/usr/local/bin/$bin"
done
log "installed $(rga --version | head -n1)"
