#!/usr/bin/env bash
# Install rustup (user-level, ~/.cargo) and build tree-sitter-cli with cargo.
# tree-sitter is needed by nvim-treesitter; built from source by explicit
# choice over the prebuilt binary. --no-modify-path keeps rustup from editing
# the chezmoi-managed shell profiles; ~/.cargo/bin is on PATH via the zshrc.
set -euo pipefail

LOG_TAG=rust
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ -x "$HOME/.cargo/bin/tree-sitter" ]]; then
  log "tree-sitter already installed, skipping"
  exit 0
fi

if [[ ! -x "$HOME/.cargo/bin/cargo" ]]; then
  log "installing rustup"
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

# shellcheck disable=SC1091
. "$HOME/.cargo/env"

log "building tree-sitter-cli with cargo"
cargo install --locked tree-sitter-cli
log "installed $("$HOME/.cargo/bin/tree-sitter" --version)"
