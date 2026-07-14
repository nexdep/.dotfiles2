#!/usr/bin/env bash
# Install the Cursor Agent CLI via the official installer (user-level,
# ~/.local/bin — it self-updates there via `cursor-agent update`, so no root
# install). The installer downloads from the Cursor CDN (downloads.cursor.com),
# not the GitHub API, so it is safe in CI. It symlinks both `cursor-agent` and
# `agent` into ~/.local/bin.
set -euo pipefail

LOG_TAG=cursor-agent
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v cursor-agent >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/cursor-agent" ]]; then
  log "already installed, skipping"
  exit 0
fi

log "running the official Cursor Agent install script"
curl -fsSL https://cursor.com/install | bash
log "installed $("$HOME/.local/bin/cursor-agent" --version 2>/dev/null | head -n1 || echo cursor-agent)"
