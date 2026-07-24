#!/usr/bin/env bash
# Write ~/.hermes/.env with the OpenRouter API key pulled from gopass.
# Deployed to ~/.scripts/deploy_secrets/ but never run by bootstrap: run it manually
# whenever the key rotates or on a fresh machine. Needs an unlocked gopass store,
# so run ~/.scripts/gpg/import-gpg-key.sh first if the personal GPG key isn't in
# the keyring yet.
#
# Self-contained on purpose (no lib/common.sh) since it lives outside the repo
# once deployed.
set -euo pipefail

install -d -m 700 "$HOME/.hermes"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
  printf 'OPENROUTER_API_KEY=%s\n' "$(gopass show --password api/marco-openrouter-key-1)"
} >"$tmp"

install -m 600 "$tmp" "$HOME/.hermes/.env"
