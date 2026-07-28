#!/usr/bin/env bash
# Install Claude Code via the official installer (user-level, ~/.local/bin —
# it self-updates there, so no root install). bubblewrap (core apt package)
# provides its Linux sandbox.
set -euo pipefail

LOG_TAG=claude-code
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v claude >/dev/null 2>&1 || [[ -x "$HOME/.local/bin/claude" ]]; then
  log "already installed, skipping"
  exit 0
fi

max_attempts=3
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  log "running the official Claude Code install script (attempt $attempt/$max_attempts)"
  if curl -fsSL https://claude.ai/install.sh | bash; then
    break
  else
    status=$?
  fi

  if ((attempt == max_attempts)); then
    log "official Claude Code installer failed after $max_attempts attempts"
    exit "$status"
  fi

  delay=$((10 * (1 << (attempt - 1))))
  log "official installer failed (exit $status); retrying in ${delay}s"
  sleep "$delay"
done

log "installed $("$HOME/.local/bin/claude" --version 2>/dev/null | head -n1 || echo claude)"
