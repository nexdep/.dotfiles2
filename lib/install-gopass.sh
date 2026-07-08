#!/usr/bin/env bash
# Install gopass from its official apt repository (packages.gopass.pw).
# Ubuntu 26.04 no longer ships gopass in universe, and the official repo
# tracks upstream releases and updates with apt upgrade.
set -euo pipefail

log() { printf '\033[1;34m[gopass]\033[0m %s\n' "$*"; }

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi
export DEBIAN_FRONTEND=noninteractive

keyring=/etc/apt/keyrings/gopass-archive-keyring.gpg
if [[ ! -f "$keyring" ]]; then
  log "adding gopass apt repository"
  $SUDO install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://packages.gopass.pw/repos/gopass/gopass-archive-keyring.gpg | $SUDO tee "$keyring" >/dev/null
fi
echo "deb [signed-by=$keyring] https://packages.gopass.pw/repos/gopass stable main" |
  $SUDO tee /etc/apt/sources.list.d/gopass.list >/dev/null

$SUDO apt-get update
log "installing gopass"
$SUDO apt-get install -y --no-install-recommends gopass
