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
# shellcheck source=lib/onedrive.sh
source "$LIB_DIR/onedrive.sh"

# Keep a complete transcript of every run while preserving the colored live
# output. The logger reads from a FIFO so the EXIT trap can close the stream
# and wait until the plain-text log is fully flushed before bootstrap returns.
LOG_FILE="$(mktemp "$HOME/bootstrap-$(date '+%Y%m%d-%H%M%S')-XXXXXX.log")"
LOG_PIPE_DIR="$(mktemp -d)"
LOG_PIPE="$LOG_PIPE_DIR/output"
DOTFILES_WINDOWS_WARNINGS_FILE="$LOG_PIPE_DIR/windows-warnings"
export DOTFILES_WINDOWS_WARNINGS_FILE
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
  if [[ -s "$DOTFILES_WINDOWS_WARNINGS_FILE" ]]; then
    printf '\033[1;33m[bootstrap] WARNING: Windows-side configuration updates were not completed:\033[0m\n' >&2
    while IFS= read -r warning; do
      printf '\033[1;33m[bootstrap] WARNING:\033[0m %s\n' "$warning" >&2
    done <"$DOTFILES_WINDOWS_WARNINGS_FILE"
  fi

  # Restoring stdout/stderr closes the FIFO writer. Wait for the logger before
  # reporting the path so callers can read a complete log immediately.
  exec 1>&3 2>&4
  exec 3>&- 4>&-
  wait "$LOG_WRITER_PID" || true
  rm -f "$LOG_PIPE"
  rm -f "$DOTFILES_WINDOWS_WARNINGS_FILE"
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

# Finish configuration left behind by an interrupted apt/dpkg run before apt
# reads package metadata. This is a no-op on healthy systems; keeping it after
# block_daemon_starts also prevents resumed postinst scripts from trying to
# start daemons through an unavailable systemd bus on WSL.
log "finishing any interrupted dpkg configuration"
$SUDO dpkg --configure -a

read_packages() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -vE '^$' || true; }

# --- apt packages per tier ---------------------------------------------------
# Prefer valid Deb822 sources from vendor packages or older installers. Do this
# before the first apt-get update so a partial earlier bootstrap that left
# duplicate sources or an empty signing key can repair itself instead of
# failing immediately.
for repo in gopass github-cli docker mozilla wezterm vscode spotify; do
  reconcile_apt_repo_source "$repo"
done
if [[ "$MACHINE" == laptop ]]; then
  cleanup_legacy_onedrive
  reconcile_apt_repo_source onedrive
fi

# curl is needed to fetch third-party repo keys but isn't present in a bare
# system, so install it (and ca-certificates) before adding repos; the
# second update then picks up the new sources.
apt_update
$SUDO apt-get install -y --no-install-recommends curl ca-certificates

add_apt_repo gopass https://packages.gopass.pw/repos/gopass/gopass-archive-keyring.gpg \
  "" "https://packages.gopass.pw/repos/gopass stable main"

github_cli_arch="$(dpkg --print-architecture)"
add_apt_repo github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  "arch=$github_cli_arch" "https://cli.github.com/packages stable main"

if [[ "$MACHINE" == server || "$MACHINE" == laptop ]]; then
  docker_arch="$(dpkg --print-architecture)"
  docker_codename="$(
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  )"
  add_apt_repo docker https://download.docker.com/linux/ubuntu/gpg \
    "arch=$docker_arch" "https://download.docker.com/linux/ubuntu $docker_codename stable"
fi

if [[ "$MACHINE" == laptop ]]; then
  register_onedrive_repo
fi

packages=()
mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-core.txt")
if [[ "$MACHINE" != server ]]; then
  mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-extra.txt")
fi
if [[ "$MACHINE" == laptop ]]; then
  mapfile -t -O "${#packages[@]}" packages < <(read_packages "$LIB_DIR/packages-gui.txt")
  packages+=(onedrive)
fi
if [[ "$MACHINE" == server || "$MACHINE" == laptop ]]; then
  packages+=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
  )
fi

log "installing apt packages: ${packages[*]}"
apt_update
$SUDO apt-get install -y --no-install-recommends --no-install-suggests "${packages[@]}"

# Give Ubuntu administrative users non-interactive root access. Validate the
# tracked policy before installing it so a malformed update cannot replace
# the active sudoers drop-in. The compare keeps reruns idempotent while the
# install command sets the ownership and permissions sudo requires.
sudoers_source="$LIB_DIR/90-dotfiles-nopasswd"
sudoers_target="/etc/sudoers.d/90-dotfiles-nopasswd"
visudo -cf "$sudoers_source" >/dev/null \
  || die "invalid passwordless sudo policy: $sudoers_source"
if ! $SUDO cmp -s "$sudoers_source" "$sudoers_target"; then
  log "enabling passwordless sudo for the sudo group"
  $SUDO install -o root -g root -m 0440 "$sudoers_source" "$sudoers_target"
fi

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
login_user="$(id -un)"
zsh_path="$(command -v zsh)"
current_shell="$(getent passwd "$login_user" | cut -d: -f7)"
if [[ "$current_shell" != "$zsh_path" ]]; then
  log "setting default shell to $zsh_path"
  # Use the administrative account tool instead of chsh: chsh consults PAM
  # and refuses the change when the account requires an immediate password
  # update, even when invoked through sudo.
  $SUDO usermod --shell "$zsh_path" "$login_user"
fi

# --- clear forced password changes -----------------------------------------------
# Hetzner cloud images ship accounts with shadow last-change = 0 ("password
# must be changed at next login"). PAM's account stage then demands the change
# on every authentication, which breaks tools that cannot complete it: chsh
# (the reason usermod is used above), and nested sudo — root running `sudo`
# inside `sudo make ...` aborts with "PAM error: Authentication token
# manipulation error". Reset only the change date; the password itself stays
# untouched (locked accounts stay locked).
for account in root "$login_user"; do
  lstchg="$($SUDO getent shadow "$account" | cut -d: -f3)"
  if [[ "$lstchg" == "0" ]]; then
    log "clearing forced password change for $account"
    $SUDO chage -d "$(date +%F)" "$account"
  fi
done

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
