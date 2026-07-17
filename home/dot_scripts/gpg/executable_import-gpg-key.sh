#!/usr/bin/env bash
# Import the personal GPG key (the one the gopass store is encrypted to) from
# the passphrase-encrypted backup committed at gpg/private-key.asc.gpg.
# Deployed to ~/.scripts/gpg/ but never run by bootstrap: run it manually once
# per machine, after bootstrap, to unlock the gopass store. Prompts for the
# backup passphrase; the passphrase is read by this script and handed to gpg
# over a pipe with --pinentry-mode loopback, so no pinentry program has to
# render (GUI pinentries time out on WSL — the reason this step left
# bootstrap).
#
# Self-contained on purpose (no lib/common.sh) since it lives outside the repo
# once deployed. Run it from the repo root: it reads the backup from ./gpg/
# (override the source with GPG_BACKUP_FILE).
set -euo pipefail

log() { printf '\033[1;34m[gpg-import]\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31m[gpg-import]\033[0m %s\n' "$*" >&2
  exit 1
}

# Long key id of the personal key ("marco (dotfiles key)", Ed25519, 2026-05-19);
# gopass stores must be initialized to this key.
KEY_ID="${GPG_KEY_ID:-6F43032151FFADD6}"

if gpg --list-secret-keys "$KEY_ID" >/dev/null 2>&1; then
  log "key $KEY_ID already in keyring, skipping"
  exit 0
fi

# The backup lives in this repo's gpg/ dir. Default to ./gpg/ under the
# current directory (run this from the repo root); override with
# GPG_BACKUP_FILE.
if [[ -n "${GPG_BACKUP_FILE:-}" ]]; then
  BACKUP_FILE="$GPG_BACKUP_FILE"
else
  [[ -f "gpg/private-key.asc.gpg" ]] ||
    die "no ./gpg/private-key.asc.gpg here; run from the dotfiles repo root or set GPG_BACKUP_FILE"
  BACKUP_FILE="$PWD/gpg/private-key.asc.gpg"
fi
[[ -f "$BACKUP_FILE" ]] || die "encrypted key backup not found: $BACKUP_FILE"

[[ -t 0 ]] || die "no TTY: this script prompts for the backup passphrase"

export GPG_TTY="${GPG_TTY:-$(tty)}"
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

umask 077
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Decrypt with the passphrase fed over a pipe (--passphrase-fd 0) under
# loopback pinentry: gpg never asks the agent/pinentry for it, and it never
# appears in argv.
attempts=3
for ((i = 1; i <= attempts; i++)); do
  read -rsp "Backup passphrase (attempt $i/$attempts): " pass
  printf '\n'
  if printf '%s' "$pass" | gpg --batch --yes --pinentry-mode loopback \
    --passphrase-fd 0 --decrypt --output "$tmp/private-key.asc" "$BACKUP_FILE" \
    2>"$tmp/gpg-err"; then
    break
  fi
  if ((i == attempts)); then
    sed 's/^/  /' "$tmp/gpg-err" >&2 || true
    die "decryption failed after $attempts attempts"
  fi
  log "decryption failed, try again"
done
unset pass

gpg --import "$tmp/private-key.asc"

fpr="$(gpg --list-secret-keys --with-colons "$KEY_ID" | awk -F: '/^fpr:/ {print $10; exit}')"
[[ -n "$fpr" ]] || die "key $KEY_ID not found in keyring after import"
echo "$fpr:6:" | gpg --import-ownertrust

log "imported and trusted key $fpr"
