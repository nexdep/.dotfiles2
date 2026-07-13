#!/usr/bin/env bash
# Install the Bitwarden CLI (bw) globally via npm (core apt package). There is
# no apt package, and the bitwarden/clients GitHub releases mix per-product
# tags (cli/desktop/web), so the latest/download redirect trick is unreliable.
# Used by the zshrc bw_login/bw_fetch_ssh helpers; to be retired once gopass
# fully replaces it.
set -euo pipefail

LOG_TAG=bw
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v bw >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "installing @bitwarden/cli with npm"
$SUDO npm install -g @bitwarden/cli
log "installed bw $(bw --version 2>/dev/null || true)"
