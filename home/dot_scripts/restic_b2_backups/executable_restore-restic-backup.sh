#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# restore-restic-backup.sh
#
# Purpose:
#   Restores a folder backed up by setup-restic-systemd-backup.sh, typically
#   after redeploying a system.
#
#   This script:
#     1. Checks that restic is installed.
#     2. Checks that these files already exist:
#
#          /etc/restic/password
#          /etc/restic/restic.env
#
#     3. Loads /etc/restic/restic.env.
#     4. Lists the snapshots tagged with BACKUP_OPERATION_NAME.
#     5. Asks for confirmation.
#     6. Restores the chosen snapshot and verifies the restored files.
#
# Usage (on a freshly redeployed system):
#   1. Recreate the restic config files:
#
#        sudo ./create-restic-config-placeholders.sh
#
#   2. Fill in the real values (same credentials and repository password
#      the backups were made with):
#
#        sudo nano /etc/restic/restic.env
#        sudo nano /etc/restic/password
#
#   3. Check the variables below in this script:
#
#        BACKUP_OPERATION_NAME
#        SNAPSHOT_ID
#        RESTORE_TARGET
#
#   4. Run:
#
#        chmod +x restore-restic-backup.sh
#        sudo ./restore-restic-backup.sh
#
#   5. Re-run setup-restic-systemd-backup.sh to resume scheduled backups.
#
# Important:
#   With RESTORE_TARGET="/" the folder is restored at its original absolute
#   path, overwriting any files already there that differ from the snapshot.
###############################################################################

###############################################################################
# User-editable settings
###############################################################################

# Must match the BACKUP_OPERATION_NAME used by the setup script.
# Snapshots are selected by this tag.
BACKUP_OPERATION_NAME="restic-backblaze-backup"

# Snapshot to restore: "latest", or a specific snapshot ID from the list
# this script prints.
SNAPSHOT_ID="latest"

# Where to restore. "/" puts the folder back at its original absolute path
# (the redeploy case). Point somewhere else (e.g. /restore) to inspect the
# files first; the original path is then recreated underneath it.
RESTORE_TARGET="/"

###############################################################################
# Internal paths
###############################################################################

RESTIC_DIR="/etc/restic"
RESTIC_PASSWORD_FILE="${RESTIC_DIR}/password"
RESTIC_ENV_FILE="${RESTIC_DIR}/restic.env"

###############################################################################
# Helper functions
###############################################################################

die() {
  echo "ERROR: $*" >&2
  exit 1
}

yes_or_no() {
  local prompt="$1"
  local answer

  read -r -p "${prompt} [y/N]: " answer

  case "${answer}" in
    y|Y|yes|YES|Yes)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_required_file() {
  local file_path="$1"

  [[ -f "${file_path}" ]] || die "Required file missing: ${file_path}"
}

load_restic_env() {
  # Loads /etc/restic/restic.env into the current shell and exports the values
  # so restic can use them.
  #
  # The generated restic.env file is intentionally shell-compatible:
  #
  #   KEY=value
  #
  # Do not put `export KEY=value` in /etc/restic/restic.env.

  set -a
  # shellcheck disable=SC1090
  . "${RESTIC_ENV_FILE}"
  set +a
}

validate_restic_env() {
  # These are required for the Backblaze B2 S3-compatible restic setup.

  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || die "AWS_ACCESS_KEY_ID is missing in ${RESTIC_ENV_FILE}"
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || die "AWS_SECRET_ACCESS_KEY is missing in ${RESTIC_ENV_FILE}"
  [[ -n "${RESTIC_REPOSITORY:-}" ]] || die "RESTIC_REPOSITORY is missing in ${RESTIC_ENV_FILE}"
  [[ -n "${RESTIC_PASSWORD_FILE:-}" ]] || die "RESTIC_PASSWORD_FILE is missing in ${RESTIC_ENV_FILE}"

  [[ -f "${RESTIC_PASSWORD_FILE}" ]] || die "RESTIC_PASSWORD_FILE points to a missing file: ${RESTIC_PASSWORD_FILE}"
}

###############################################################################
# Pre-flight checks
###############################################################################

[[ "${EUID}" -eq 0 ]] || die "Run this script as root, for example: sudo $0"

command -v restic >/dev/null 2>&1 || die "restic is not installed or not in PATH."

[[ "${BACKUP_OPERATION_NAME}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "BACKUP_OPERATION_NAME contains invalid characters."

check_required_file "${RESTIC_PASSWORD_FILE}"
check_required_file "${RESTIC_ENV_FILE}"

if grep -q "CHANGE_ME" "${RESTIC_PASSWORD_FILE}" "${RESTIC_ENV_FILE}"; then
  die "Placeholder CHANGE_ME values found in ${RESTIC_PASSWORD_FILE} or ${RESTIC_ENV_FILE}. Replace them before running this script."
fi

load_restic_env
validate_restic_env

###############################################################################
# Show the snapshots this tag has in the repository
###############################################################################

echo "Snapshots tagged '${BACKUP_OPERATION_NAME}' in ${RESTIC_REPOSITORY}:"
echo

restic snapshots --tag "${BACKUP_OPERATION_NAME}" || die "Could not list snapshots. Check the credentials, repository, and password in ${RESTIC_ENV_FILE}."

if ! restic snapshots --tag "${BACKUP_OPERATION_NAME}" --json | grep -q '"id"'; then
  die "No snapshots carry the tag '${BACKUP_OPERATION_NAME}'. Check BACKUP_OPERATION_NAME, or whether backups ever ran against this repository."
fi

###############################################################################
# Confirm and restore
###############################################################################

echo
echo "About to restore:"
echo "  Snapshot: ${SNAPSHOT_ID} (tag: ${BACKUP_OPERATION_NAME})"
echo "  Target:   ${RESTORE_TARGET}"
echo

if [[ "${RESTORE_TARGET}" == "/" ]]; then
  echo "The folder will be restored at its ORIGINAL absolute path."
  echo "Files already there that differ from the snapshot will be OVERWRITTEN."
  echo
fi

if ! yes_or_no "Proceed with restore?"; then
  echo "Restore cancelled. Nothing was changed."
  exit 0
fi

echo
echo "Restoring (files are verified against the repository afterwards)..."
restic restore "${SNAPSHOT_ID}" --tag "${BACKUP_OPERATION_NAME}" --target "${RESTORE_TARGET}" --verify

echo
echo "Restore complete."
echo
echo "Next steps:"
echo "  - Check the restored folder."
echo "  - Re-run setup-restic-systemd-backup.sh to resume scheduled backups."
