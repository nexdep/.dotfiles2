# shellcheck shell=bash
# Shared helpers for bootstrap.sh and lib/install-*.sh. Sourced, not executed;
# callers set LOG_TAG before sourcing and keep their own `set -euo pipefail`.

SUDO=""
if [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
fi
export DEBIAN_FRONTEND=noninteractive

log() { printf '\033[1;34m[%s]\033[0m %s\n' "${LOG_TAG:-setup}" "$*"; }
die() {
  printf '\033[1;31m[%s]\033[0m %s\n' "${LOG_TAG:-setup}" "$*" >&2
  exit 1
}

POLICY_RC_D=/usr/sbin/policy-rc.d
# Stop package postinst scripts from starting their daemons during apt: on a
# systemd host deb-systemd-invoke/invoke-rc.d honor a policy-rc.d that exits
# 101 and skip the start (the unit is still enabled, so it starts on next
# boot). On WSL the systemd D-Bus bus is often unavailable, so a start attempt
# fails and aborts bootstrap under `set -e`; this sidesteps it. Idempotent, and
# records whether we created the file so the matching remove only deletes our
# own (a pre-existing environment policy-rc.d is left untouched).
block_daemon_starts() {
  if [[ -e "$POLICY_RC_D" ]]; then _CREATED_POLICY_RC_D=0; return; fi
  printf '#!/bin/sh\nexit 101\n' | $SUDO tee "$POLICY_RC_D" >/dev/null
  $SUDO chmod 0755 "$POLICY_RC_D"
  _CREATED_POLICY_RC_D=1
}
# shellcheck disable=SC2317,SC2329  # invoked via `trap ... EXIT` in bootstrap.sh
unblock_daemon_starts() {
  # An `if` (not `&&`) so the function returns 0 when we didn't create the file
  # — otherwise a false test would be the last command and, as an EXIT trap,
  # would make bootstrap exit non-zero (the ubuntu container ships its own
  # policy-rc.d, so this path is hit there).
  if [[ "${_CREATED_POLICY_RC_D:-0}" == 1 ]]; then
    $SUDO rm -f "$POLICY_RC_D"
  fi
}

# add_apt_repo <name> <key_url> <options> <repo-and-suites>
# Writes the signing key to /etc/apt/keyrings/<name>.{asc,gpg} and the source
# to /etc/apt/sources.list.d/<name>.list. apt decides armored-vs-binary key
# format by file EXTENSION, so it is chosen from the downloaded content.
# <options> is extra bracket options like "arch=amd64" ("" for none). Does NOT
# run apt-get update — callers batch one update after adding all their repos.
add_apt_repo() {
  local name="$1" key_url="$2" options="$3" repo="$4"
  local keydir=/etc/apt/keyrings keyring
  if [[ -f "$keydir/$name.asc" ]]; then
    keyring="$keydir/$name.asc"
  elif [[ -f "$keydir/$name.gpg" ]]; then
    keyring="$keydir/$name.gpg"
  else
    log "adding $name apt repository"
    local tmpkey
    tmpkey="$(mktemp)"
    curl -fsSL "$key_url" -o "$tmpkey"
    case "$(head -c 14 "$tmpkey")" in
      "-----BEGIN PGP") keyring="$keydir/$name.asc" ;;
      *) keyring="$keydir/$name.gpg" ;;
    esac
    $SUDO install -D -m 0644 "$tmpkey" "$keyring"
    rm -f "$tmpkey"
  fi
  echo "deb [signed-by=${keyring}${options:+ $options}] $repo" |
    $SUDO tee "/etc/apt/sources.list.d/${name}.list" >/dev/null
}

# install_deb <name> <url>
# Download an official .deb and install it via apt so its declared
# dependencies resolve from the configured repos. Callers keep their own
# already-installed guard and architecture check (those vary per app).
install_deb() {
  local name="$1" url="$2"
  local tmp
  tmp="$(mktemp -d)"
  log "downloading $name"
  curl -fsSL "$url" -o "$tmp/$name.deb"
  $SUDO apt-get install -y "$tmp/$name.deb"
  rm -rf "$tmp"
}
