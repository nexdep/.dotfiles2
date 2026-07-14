#!/usr/bin/env bash
# Install the Pi coding agent (pi.dev / earendil-works) globally via npm (core
# apt package). The vendor's `curl | sh` installer is a full interactive TUI
# and unusable in a non-interactive bootstrap, so the documented npm package is
# used instead. `--ignore-scripts` is the vendor's own recommended flag (Pi
# needs no lifecycle scripts for a normal install). Command is `pi`.
set -euo pipefail

LOG_TAG=pi
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v pi >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "installing @earendil-works/pi-coding-agent with npm"
$SUDO npm install -g --ignore-scripts @earendil-works/pi-coding-agent
log "installed pi $(pi --version 2>/dev/null | head -n1 || true)"
