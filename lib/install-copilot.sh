#!/usr/bin/env bash
# Install the GitHub Copilot CLI globally via npm (core apt package). There is
# no apt package; npm-global is the vendor's documented primary method and
# matches install-bw.sh. Requires Node.js 22+ (satisfied by the core `nodejs`
# apt package). Command is `copilot`.
set -euo pipefail

LOG_TAG=copilot
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v copilot >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "installing @github/copilot with npm"
$SUDO npm install -g @github/copilot
log "installed copilot $(copilot --version 2>/dev/null | head -n1 || true)"
