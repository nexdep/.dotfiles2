#!/usr/bin/env bash
# Install Herdr (agent-aware terminal multiplexer) via its official installer.
# The binary lives user-level in ~/.local/bin and self-updates with
# `herdr update`.
set -euo pipefail

LOG_TAG=herdr
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ -x "$HOME/.local/bin/herdr" ]] || command -v herdr >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "running the official Herdr install script"
curl -fsSL https://herdr.dev/install.sh | sh

binary="$HOME/.local/bin/herdr"
[[ -x "$binary" ]] || die "installer did not create $binary"
log "installed $("$binary" --version 2>/dev/null | head -n1 || echo herdr)"
