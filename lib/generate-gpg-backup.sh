#!/usr/bin/env bash
# Regenerate the encrypted key backup committed at gpg/private-key.asc.gpg.
# Maintenance tool, never called by bootstrap: run it manually on a machine
# whose keyring holds the secret key (e.g. after rotating the key), then
# commit the new blob. Prompts twice: the key's own passphrase (export) and
# a backup passphrase (symmetric encryption).
set -euo pipefail

LOG_TAG=gpg-backup
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

# Long key id of the personal key ("marco (dotfiles key)", Ed25519, 2026-05-19);
# gopass stores must be initialized to this key.
KEY_ID="${GPG_KEY_ID:-6F43032151FFADD6}"
OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/gpg/private-key.asc.gpg"

gpg --list-secret-keys "$KEY_ID" >/dev/null 2>&1 ||
  die "secret key $KEY_ID is not in this machine's keyring"

export GPG_TTY="${GPG_TTY:-$(tty)}"
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

umask 077
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gpg --armor --export-secret-keys --output "$tmp/private-key.asc" "$KEY_ID"
[[ -s "$tmp/private-key.asc" ]] || die "secret key export produced no data"

mkdir -p "$(dirname "$OUT")"
gpg --symmetric --cipher-algo AES256 --yes --output "$OUT" "$tmp/private-key.asc"
chmod 644 "$OUT"

log "wrote $OUT — commit it to update the deployed key"
