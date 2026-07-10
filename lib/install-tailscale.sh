#!/usr/bin/env bash
# Install tailscale via its official install script, which registers the
# tailscale apt repo (so it updates with `apt upgrade`) and handles root/sudo
# itself. Joining the tailnet (`tailscale up`) stays a manual step.
set -euo pipefail

LOG_TAG=tailscale
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v tailscale >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "running the official tailscale install script"
curl -fsSL https://tailscale.com/install.sh | sh
log "installed $(tailscale version | head -n1)"
