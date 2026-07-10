#!/usr/bin/env bash
# Install the OpenAI Codex CLI via the official installer (user-level,
# ~/.local/bin).
set -euo pipefail

LOG_TAG=codex
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v codex >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/codex" ]]; then
  log "already installed, skipping"
  exit 0
fi

log "running the official Codex install script"
curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
log "installed $("$HOME/.local/bin/codex" --version 2>/dev/null | head -n1 || echo codex)"
