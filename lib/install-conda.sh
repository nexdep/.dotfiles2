#!/usr/bin/env bash
# Install conda (Miniforge3, conda-forge's community installer) per-user into
# $HOME/miniforge3, matching the current system. Not a single binary or apt
# package, so this downloads the official constructor-generated installer
# script and runs it in batch mode, same pattern as bootstrap.sh uses for
# chezmoi itself. Shell integration is wired up separately by chezmoi
# (home/.chezmoitemplates/zshrc-workstation.zsh), not by this script.
set -euo pipefail

log() { printf '\033[1;34m[conda]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[conda]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
  log "already installed, skipping"
  exit 0
fi

case "$(uname -m)" in
  x86_64) arch=x86_64 ;;
  aarch64) arch=aarch64 ;;
  *) die "unsupported architecture: $(uname -m)" ;;
esac

url="https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${arch}.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
installer="$tmp/miniforge.sh"

log "downloading $url"
curl -fsSL "$url" -o "$installer"

log "installing to $HOME/miniforge3"
bash "$installer" -b -p "$HOME/miniforge3"
log "installed $("$HOME/miniforge3/bin/conda" --version)"
