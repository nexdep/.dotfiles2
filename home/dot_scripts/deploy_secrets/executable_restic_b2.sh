#!/usr/bin/env bash
# Replace the generated /etc/restic credential placeholders with secrets
# pulled from gopass.
#
# Run this as your normal user, not with sudo. The script needs the user's
# unlocked gopass store and asks for sudo only when installing the root-owned
# files.
#
# Required gopass entries:
#
#   backup/restic-b2/backblaze-key-id
#   backup/restic-b2/backblaze-application-key
#   backup/restic-b2/repository-base
#   backup/restic-b2/repository-password
#
# Run create-restic-config-placeholders.sh first so /etc/restic/excludes
# exists. This script replaces only /etc/restic/restic.env and
# /etc/restic/password; it never changes the excludes file.
#
# Self-contained on purpose (no lib/common.sh) since it is deployed to
# ~/.scripts/deploy_secrets/ and run outside the repo.
set -Eeuo pipefail

RESTIC_DIR="/etc/restic"
RESTIC_ENV_FILE="${RESTIC_DIR}/restic.env"
RESTIC_PASSWORD_FILE="${RESTIC_DIR}/password"
RESTIC_EXCLUDES_FILE="${RESTIC_DIR}/excludes"

KEY_ID_ENTRY="backup/restic-b2/backblaze-key-id"
APPLICATION_KEY_ENTRY="backup/restic-b2/backblaze-application-key"
REPOSITORY_BASE_ENTRY="backup/restic-b2/repository-base"
REPOSITORY_PASSWORD_ENTRY="backup/restic-b2/repository-password"

log() {
  printf '\033[1;34m[restic-secrets]\033[0m %s\n' "$*"
}

die() {
  printf '\033[1;31m[restic-secrets]\033[0m %s\n' "$*" >&2
  exit 1
}

yes_or_no() {
  local prompt="$1"
  local answer

  [[ -t 0 ]] || die "existing Restic credentials require confirmation, but no TTY is available"
  read -r -p "${prompt} [y/N]: " answer

  case "$answer" in
    y|Y|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

fetch_secret() {
  local entry="$1"
  local destination="$2"

  log "fetching ${entry}"
  if ! gopass show --password --nosync "$entry" >"$destination"; then
    die "could not fetch gopass entry: ${entry}"
  fi

  [[ -s "$destination" ]] || die "gopass entry is empty: ${entry}"
}

read_secret() {
  local entry="$1"
  local file_path="$2"
  local value

  value=""
  IFS= read -r value <"$file_path" || true

  [[ -n "$value" ]] || die "gopass entry is empty: ${entry}"
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] \
    || die "gopass entry must contain a single-line value: ${entry}"

  printf '%s' "$value"
}

validate_env_value() {
  local variable_name="$1"
  local value="$2"

  [[ "$value" =~ ^[A-Za-z0-9._:/@%+=,-]+$ ]] \
    || die "${variable_name} contains characters that are unsafe in ${RESTIC_ENV_FILE}"
}

[[ "${EUID}" -ne 0 ]] || die "run this script as your normal user, without sudo"

for dependency in gopass sudo; do
  command -v "$dependency" >/dev/null 2>&1 || die "required command not found: ${dependency}"
done

umask 077
TMP_DIR="$(mktemp -d)" || die "could not create a temporary directory"
trap 'rm -rf -- "$TMP_DIR"' EXIT

KEY_ID_FILE="${TMP_DIR}/backblaze-key-id"
APPLICATION_KEY_FILE="${TMP_DIR}/backblaze-application-key"
REPOSITORY_BASE_FILE="${TMP_DIR}/repository-base"
REPOSITORY_PASSWORD_FILE="${TMP_DIR}/repository-password"
ENV_TMP="${TMP_DIR}/restic.env"
PASSWORD_TMP="${TMP_DIR}/password"

fetch_secret "$KEY_ID_ENTRY" "$KEY_ID_FILE"
fetch_secret "$APPLICATION_KEY_ENTRY" "$APPLICATION_KEY_FILE"
fetch_secret "$REPOSITORY_BASE_ENTRY" "$REPOSITORY_BASE_FILE"
fetch_secret "$REPOSITORY_PASSWORD_ENTRY" "$REPOSITORY_PASSWORD_FILE"

AWS_ACCESS_KEY_ID="$(read_secret "$KEY_ID_ENTRY" "$KEY_ID_FILE")"
AWS_SECRET_ACCESS_KEY="$(read_secret "$APPLICATION_KEY_ENTRY" "$APPLICATION_KEY_FILE")"
RESTIC_REPOSITORY_BASE="$(read_secret "$REPOSITORY_BASE_ENTRY" "$REPOSITORY_BASE_FILE")"
RESTIC_REPOSITORY_PASSWORD="$(read_secret "$REPOSITORY_PASSWORD_ENTRY" "$REPOSITORY_PASSWORD_FILE")"

validate_env_value "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
validate_env_value "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
validate_env_value "RESTIC_REPOSITORY_BASE" "$RESTIC_REPOSITORY_BASE"
[[ "$RESTIC_REPOSITORY_BASE" == s3:* ]] \
  || die "RESTIC_REPOSITORY_BASE must start with s3:"

{
  printf 'AWS_ACCESS_KEY_ID=%s\n' "$AWS_ACCESS_KEY_ID"
  printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$AWS_SECRET_ACCESS_KEY"
  printf 'RESTIC_REPOSITORY_BASE=%s\n' "$RESTIC_REPOSITORY_BASE"
  printf 'RESTIC_PASSWORD_FILE=%s\n' "$RESTIC_PASSWORD_FILE"
} >"$ENV_TMP"

printf '%s\n' "$RESTIC_REPOSITORY_PASSWORD" >"$PASSWORD_TMP"

SUDO="sudo"
# Front-load the sudo prompt so the install steps below don't stop to ask
# midway. `sudo -v` always authenticates interactively, even for a user who has
# NOPASSWD for commands — and cloud images ship a locked account password, so
# that prompt can never succeed there (it just burns three attempts and aborts).
# Probe with a real, NOPASSWD-eligible command first; only fall back to
# interactive validation when a password is genuinely required.
if ! $SUDO -n true 2>/dev/null; then
  $SUDO -v || die "sudo authentication failed; this script needs root to write ${RESTIC_DIR}"
fi

$SUDO test -d "$RESTIC_DIR" \
  || die "${RESTIC_DIR} is missing; run create-restic-config-placeholders.sh first"
$SUDO test -f "$RESTIC_EXCLUDES_FILE" \
  || die "${RESTIC_EXCLUDES_FILE} is missing; run create-restic-config-placeholders.sh first"

if $SUDO test -e "$RESTIC_ENV_FILE" || $SUDO test -e "$RESTIC_PASSWORD_FILE"; then
  if ! yes_or_no "Replace ${RESTIC_ENV_FILE} and ${RESTIC_PASSWORD_FILE}?"; then
    log "cancelled; existing Restic credentials were not changed"
    exit 0
  fi
fi

log "installing root-owned Restic credentials"
$SUDO install -T -m 600 -o root -g root "$ENV_TMP" "$RESTIC_ENV_FILE"
$SUDO install -T -m 600 -o root -g root "$PASSWORD_TMP" "$RESTIC_PASSWORD_FILE"
$SUDO chown root:root "$RESTIC_DIR"
$SUDO chmod 700 "$RESTIC_DIR"

log "installed ${RESTIC_ENV_FILE}"
log "installed ${RESTIC_PASSWORD_FILE}"
log "kept ${RESTIC_EXCLUDES_FILE} unchanged"
log "next: run setup-restic-systemd-backup.sh"
