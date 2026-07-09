#!/usr/bin/env bash
# Bootstrap an Ubuntu machine: install the programs for its tier and deploy
# the dotfiles with chezmoi.
#
# Usage: ./bootstrap.sh [wsl|server|laptop]
# When the argument is omitted, WSL is auto-detected; otherwise it is required.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$REPO_DIR/lib"

LOG_TAG=bootstrap
# shellcheck source=lib/common.sh
source "$LIB_DIR/common.sh"

MACHINE="${1:-}"
if [[ -z "$MACHINE" ]]; then
  if grep -qi microsoft /proc/version 2>/dev/null; then
    MACHINE=wsl
    log "no machine type given, detected WSL"
  else
    die "usage: $0 <wsl|server|laptop>"
  fi
fi
case "$MACHINE" in
  wsl | server | laptop) ;;
  *) die "unknown machine type '$MACHINE' (expected wsl, server or laptop)" ;;
esac
log "machine type: $MACHINE"

if [[ "$(id -u)" -ne 0 ]]; then
  command -v sudo >/dev/null 2>&1 || die "not root and sudo is not available"
fi

read_packages() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -vE '^$' || true; }

# --- apt packages per tier ---------------------------------------------------
# curl is needed to fetch third-party repo keys but isn't present in a bare
# system, so install it (and ca-certificates) before adding repos; the
# second update then picks up the new sources.
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends curl ca-certificates

add_apt_repo gopass https://packages.gopass.pw/repos/gopass/gopass-archive-keyring.gpg \
  "" "https://packages.gopass.pw/repos/gopass stable main"

packages=()
mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-core.txt")
if [[ "$MACHINE" != server ]]; then
  mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-extra.txt")
fi
if [[ "$MACHINE" == laptop ]]; then
  mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-gui.txt")
fi

log "installing apt packages: ${packages[*]}"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends "${packages[@]}"

# --- non-apt installers per tier ----------------------------------------------
"$LIB_DIR/install-starship.sh"
"$LIB_DIR/install-gpg-key.sh" # personal key for gopass; self-skips without a TTY
if [[ "$MACHINE" != server ]]; then
  "$LIB_DIR/install-gomi.sh"
  "$LIB_DIR/install-conda.sh"
fi
if [[ "$MACHINE" == laptop ]]; then
  "$LIB_DIR/install-gui.sh"
fi

# --- chezmoi -------------------------------------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
  log "installing chezmoi"
  $SUDO sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

log "applying dotfiles with chezmoi (machine=$MACHINE)"
MACHINE_TYPE="$MACHINE" chezmoi init --apply --source "$REPO_DIR"

# --- default shell ---------------------------------------------------------------
zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [[ "$current_shell" != "$zsh_path" ]]; then
  log "setting default shell to $zsh_path"
  $SUDO chsh -s "$zsh_path" "$(id -un)"
fi

log "cleaning apt cache"
$SUDO apt-get clean

log "done"
