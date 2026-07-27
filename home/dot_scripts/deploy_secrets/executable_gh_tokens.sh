#!/usr/bin/env bash
# Authenticate GitHub CLI for the marco-de-pietri and nexdep accounts with
# tokens pulled from gopass. The credentials are intentionally stored in gh's
# plaintext config because --insecure-storage is required here.
#
# Deployed to ~/.scripts/deploy_secrets/ but never run by bootstrap. Run it
# manually as the normal user whenever either token rotates or on a fresh
# machine, after importing the personal GPG key that unlocks the gopass store.
#
# Self-contained on purpose (no lib/common.sh) since it runs outside the repo.
set -uo pipefail

GH_TARGET_HOST="github.com"
NEXDEP_ACCOUNT="nexdep"

log() {
  printf '\033[1;34m[gh-tokens]\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;31m[gh-tokens]\033[0m %s\n' "$*" >&2
}

die() {
  warn "$*"
  exit 1
}

authenticate() {
  local entry="$1"
  local account="$2"

  log "authenticating ${account} from gopass entry ${entry}"
  if gopass show --password "$entry" |
    gh auth login \
      --hostname "$GH_TARGET_HOST" \
      --git-protocol ssh \
      --with-token \
      --insecure-storage \
      --skip-ssh-key; then
    log "authenticated ${account}"
    return 0
  fi

  warn "failed to authenticate ${account} from ${entry}"
  return 1
}

[[ "${EUID}" -ne 0 ]] || die "run this script as your normal user, without sudo"

for dependency in gopass gh; do
  command -v "$dependency" >/dev/null 2>&1 ||
    die "required command not found: ${dependency}"
done

log "warning: gh credentials will be stored in plaintext (--insecure-storage)"

successes=0
failures=0
nexdep_authenticated=0

if authenticate "gh/mdp-token-1" "marco-de-pietri"; then
  ((successes += 1))
else
  ((failures += 1))
fi

if authenticate "gh/nexdep-token-1" "$NEXDEP_ACCOUNT"; then
  ((successes += 1))
  nexdep_authenticated=1
else
  ((failures += 1))
fi

if ((nexdep_authenticated)); then
  if gh auth switch --hostname "$GH_TARGET_HOST" --user "$NEXDEP_ACCOUNT"; then
    log "active account for ${GH_TARGET_HOST}: ${NEXDEP_ACCOUNT}"
  else
    warn "authenticated ${NEXDEP_ACCOUNT}, but could not make it active"
    ((failures += 1))
  fi
else
  warn "${NEXDEP_ACCOUNT} was not authenticated; active account was not changed"
fi

log "completed: ${successes} account(s) authenticated, ${failures} failure(s)"
((failures == 0))
