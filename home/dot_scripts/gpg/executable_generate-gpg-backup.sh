#!/usr/bin/env bash
# Regenerate the encrypted key backup committed at gpg/private-key.asc.gpg.
# Deployed to ~/.scripts/gpg/ but never run by bootstrap: run it manually on a
# machine whose keyring holds the secret key (e.g. after rotating the key), then
# commit the new blob. Prompts twice: the key's own passphrase (export) and a
# backup passphrase (symmetric encryption).
#
# Self-contained on purpose (no lib/common.sh) since it lives outside the repo
# once deployed. Run it from the repo root: it writes the backup to ./gpg/ so
# you can `git commit` the new blob right there.
set -euo pipefail

log() { printf '\033[1;34m[gpg-backup]\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m[gpg-backup]\033[0m %s\n' "$*" >&2
  exit 1
}

# Long key id of the personal key ("marco (dotfiles key)", Ed25519, 2026-05-19);
# gopass stores must be initialized to this key.
KEY_ID="${GPG_KEY_ID:-6F43032151FFADD6}"

# The backup belongs in this repo's gpg/ dir so it can be committed. Default to
# ./gpg/ under the current directory (run this from the repo root); override the
# destination with GPG_BACKUP_OUT.
if [[ -n "${GPG_BACKUP_OUT:-}" ]]; then
  OUT="$GPG_BACKUP_OUT"
else
  [[ -d "gpg" ]] ||
    die "no ./gpg dir here; run from the dotfiles repo root or set GPG_BACKUP_OUT"
  OUT="$PWD/gpg/private-key.asc.gpg"
fi

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
