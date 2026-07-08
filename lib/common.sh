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
