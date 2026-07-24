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

# Keep a complete transcript of every run while preserving the colored live
# output. The logger reads from a FIFO so the EXIT trap can close the stream
# and wait until the plain-text log is fully flushed before bootstrap returns.
LOG_FILE="$(mktemp "$HOME/bootstrap-$(date '+%Y%m%d-%H%M%S')-XXXXXX.log")"
LOG_PIPE_DIR="$(mktemp -d)"
LOG_PIPE="$LOG_PIPE_DIR/output"
mkfifo "$LOG_PIPE"
exec 3>&1 4>&2
tee /dev/fd/3 <"$LOG_PIPE" |
  LC_ALL=C sed -u -E $'s/\033\\[[0-?]*[ -/]*[@-~]//g' >"$LOG_FILE" &
LOG_WRITER_PID=$!
exec >"$LOG_PIPE" 2>&1

cleanup() {
  local status=$?
  trap - EXIT
  set +e

  if ((status != 0)); then
    log "failed with exit status $status"
  fi
  unblock_daemon_starts || true

  # Restoring stdout/stderr closes the FIFO writer. Wait for the logger before
  # reporting the path so callers can read a complete log immediately.
  exec 1>&3 2>&4
  exec 3>&- 4>&-
  wait "$LOG_WRITER_PID" || true
  rm -f "$LOG_PIPE"
  rmdir "$LOG_PIPE_DIR"
  printf '[bootstrap] install log saved to %s\n' "$LOG_FILE"

  exit "$status"
}
trap cleanup EXIT

log "saving install log to $LOG_FILE"

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

# Keep apt postinst scripts from starting daemons via the systemd bus (flaky on
# WSL); armed before the first apt-get so it covers the whole run, removed on
# exit even if bootstrap fails. See lib/common.sh.
block_daemon_starts

read_packages() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -vE '^$' || true; }

# --- apt packages per tier ---------------------------------------------------
# curl is needed to fetch third-party repo keys but isn't present in a bare
# system, so install it (and ca-certificates) before adding repos; the
# second update then picks up the new sources.
apt_update
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
apt_update
$SUDO apt-get install -y --no-install-recommends "${packages[@]}"

# Ubuntu ships bat's binary as batcat; expose the upstream name for scripts
# that call `bat` (e.g. yazi's fg plugin previews).
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  log "symlinking bat -> batcat"
  $SUDO ln -s "$(command -v batcat)" /usr/local/bin/bat
fi

# Same story for fd: Ubuntu ships it as fdfind (LazyVim and friends call `fd`).
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  log "symlinking fd -> fdfind"
  $SUDO ln -s "$(command -v fdfind)" /usr/local/bin/fd
fi

# --- non-apt installers per tier ----------------------------------------------
"$LIB_DIR/install-starship.sh"
"$LIB_DIR/install-ubuntu-mono-nerd-font.sh"
"$LIB_DIR/install-neovim.sh"
"$LIB_DIR/install-gopass-store.sh" # personal password store (public repo, keyless clone)
"$LIB_DIR/install-tailscale.sh"
"$LIB_DIR/install-rclone.sh"
"$LIB_DIR/install-rust.sh" # rustup + tree-sitter-cli (user-level, ~/.cargo)
"$LIB_DIR/install-claude-code.sh" # user-level, ~/.local/bin
"$LIB_DIR/install-codex.sh" # user-level, ~/.local/bin
"$LIB_DIR/install-cursor-agent.sh" # user-level, ~/.local/bin
"$LIB_DIR/install-copilot.sh" # GitHub Copilot CLI via npm -g
"$LIB_DIR/install-pi.sh" # pi.dev coding agent via npm -g
"$LIB_DIR/install-opencode.sh" # opencode agent from GitHub release binaries
"$LIB_DIR/install-herdr.sh" # user-level, ~/.local/bin
"$LIB_DIR/install-uv.sh" # user-level, ~/.local/bin
"$LIB_DIR/install-lazygit.sh"
"$LIB_DIR/install-bw.sh" # bitwarden CLI via npm
if [[ "$MACHINE" != server ]]; then
  "$LIB_DIR/install-gomi.sh"
  "$LIB_DIR/install-conda.sh"
  "$LIB_DIR/install-yazi.sh"
  "$LIB_DIR/install-rga.sh"
  "$LIB_DIR/install-dezoomify-rs.sh"
fi
if [[ "$MACHINE" == wsl ]]; then
  "$LIB_DIR/install-onedrive-links.sh" # symlink Windows OneDrive folders into ~; self-skips without /mnt/c
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

# --- start ssh in this session ---------------------------------------------------
# Daemon auto-start was suppressed during install, so ssh.socket is enabled but
# not yet running; start it now so ssh works without a reboot. Best effort —
# never fatal, and a no-op where systemd isn't the init (CI containers).
if [[ -d /run/systemd/system ]] && command -v systemctl >/dev/null 2>&1; then
  log "starting ssh (best effort)"
  $SUDO systemctl start ssh.socket 2>/dev/null \
    || $SUDO systemctl start ssh.service 2>/dev/null \
    || log "could not start ssh now; it will start on next boot"
fi

# The personal GPG key is imported manually, not by bootstrap (the decrypt
# prompt is interactive); just point at the script when the key is missing.
if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec'; then
  log "personal GPG key not imported; run ~/.scripts/gpg/import-gpg-key.sh to unlock the gopass store"
fi

log "cleaning apt cache"
$SUDO apt-get clean

log "done"
