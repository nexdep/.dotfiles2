#!/usr/bin/env bash
# Install rclone via its official install script into /usr/bin. No apt repo is
# published; re-running bootstrap.sh only reinstalls if the command is missing.
set -euo pipefail

LOG_TAG=rclone
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v rclone >/dev/null 2>&1; then
  log "already installed, skipping"
  exit 0
fi

log "running the official rclone install script"
# The script exits 3 when rclone is already up to date; tolerate that.
curl -fsSL https://rclone.org/install.sh | $SUDO bash || [[ $? -eq 3 ]]
log "installed $(rclone version | head -n1)"
