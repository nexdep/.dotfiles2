#!/usr/bin/env bash
# Install the OpenAI Codex CLI from GitHub release binaries into ~/.local/bin
# (user-level, like Claude Code). The official install script resolves the
# version through the GitHub API, which gets rate-limited in CI, so the
# fixed-name release assets are fetched directly via the latest/download
# redirect instead.
set -euo pipefail

LOG_TAG=codex
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v codex >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/codex" ]]; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) target=x86_64-unknown-linux-musl ;;
  aarch64) target=aarch64-unknown-linux-musl ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/openai/codex/releases/latest/download/codex-${target}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "downloading $url"
curl -fsSL "$url" | tar -xz -C "$tmp"
[[ -f "$tmp/codex-$target" ]] || die "codex binary not found in release archive"

install -D -m 0755 "$tmp/codex-$target" "$HOME/.local/bin/codex"
log "installed $("$HOME/.local/bin/codex" --version 2>/dev/null | head -n1 || echo codex)"
