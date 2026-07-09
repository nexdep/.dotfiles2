#!/usr/bin/env bash
# Import the personal GPG key (the one the gopass store is encrypted to) from
# the passphrase-encrypted backup committed at gpg/private-key.asc.gpg.
# Interactive by design — decryption prompts for the backup passphrase — so it
# skips itself when the key is already in the keyring or when there is no TTY
# (CI containers, unattended runs). Runs on every tier: gopass is core.
set -euo pipefail

LOG_TAG=gpg-key
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Long key id of the personal key ("marco (dotfiles key)", Ed25519, 2026-05-19);
# gopass stores must be initialized to this key.
KEY_ID="${GPG_KEY_ID:-6F43032151FFADD6}"
BACKUP_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gpg/private-key.asc.gpg"

if gpg --list-secret-keys "$KEY_ID" >/dev/null 2>&1; then
  log "key $KEY_ID already in keyring, skipping"
  exit 0
fi

if [[ ! -t 0 ]]; then
  log "no TTY (unattended run), skipping key import"
  exit 0
fi

[[ -f "$BACKUP_FILE" ]] || die "encrypted key backup not found: $BACKUP_FILE"

export GPG_TTY="${GPG_TTY:-$(tty)}"
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

log "decrypting key backup (you will be prompted for the backup passphrase)"
gpg --decrypt --output "$tmp/private-key.asc" "$BACKUP_FILE"
gpg --import "$tmp/private-key.asc"

fpr="$(gpg --list-secret-keys --with-colons "$KEY_ID" | awk -F: '/^fpr:/ {print $10; exit}')"
[[ -n "$fpr" ]] || die "key $KEY_ID not found in keyring after import"
echo "$fpr:6:" | gpg --import-ownertrust

log "imported and trusted key $fpr"
