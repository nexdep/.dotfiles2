#!/usr/bin/env bash
# Clone the personal gopass password store into gopass's default root-store
# path. The GitHub repo is public, so the clone is keyless over HTTPS and
# safe to run unattended (CI included); the push URL is switched to SSH so
# `gopass sync` can push once an SSH key is set up. Decrypting the secrets
# needs the personal GPG key (lib/install-gpg-key.sh), imported separately.
set -euo pipefail

LOG_TAG=gopass-store
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

STORE_URL="${GOPASS_STORE_URL:-https://github.com/nexdep/.gopass.git}"
STORE_PUSH_URL="${GOPASS_STORE_PUSH_URL:-git@github.com:nexdep/.gopass.git}"
STORE_DIR="$HOME/.local/share/gopass/stores/root"

if [[ -d "$STORE_DIR/.git" ]]; then
  log "store already present, skipping"
  exit 0
fi

log "cloning $STORE_URL"
mkdir -p "$(dirname "$STORE_DIR")"
git clone --quiet "$STORE_URL" "$STORE_DIR" || die "failed to clone gopass store from $STORE_URL"
git -C "$STORE_DIR" remote set-url --push origin "$STORE_PUSH_URL"
chmod 700 "$STORE_DIR"

gpg_id="$(cat "$STORE_DIR/.gpg-id" 2>/dev/null || true)"
if [[ -n "$gpg_id" ]] && ! gpg --list-secret-keys "$gpg_id" >/dev/null 2>&1; then
  log "warning: no secret key for $gpg_id in the keyring; secrets stay unreadable until the GPG key is imported"
fi

log "store cloned to $STORE_DIR (push url: $STORE_PUSH_URL)"
