#!/usr/bin/env bash
# Install uv (Python package/tool manager) via the official installer
# (user-level, ~/.local/bin). Needed by
# ~/.scripts/openmc_scripts/neutronics_tools_setup.sh among others.
set -euo pipefail

LOG_TAG=uv
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ -x "$HOME/.local/bin/uv" ]] || command -v uv >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "running the official uv install script"
curl -fsSL https://astral.sh/uv/install.sh | sh
log "installed $("$HOME/.local/bin/uv" --version 2>/dev/null | head -n1 || echo uv)"
