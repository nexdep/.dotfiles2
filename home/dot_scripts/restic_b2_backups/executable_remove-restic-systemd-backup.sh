#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# remove-restic-systemd-backup.sh
#
# Purpose:
#   Removes a systemd-based restic backup service and timer.
#
#   This script:
#     1. Checks that it is running as root.
#     2. Checks whether the configured service or timer exists.
#     3. Stops the timer and service if they exist.
#     4. Disables the timer and service if they exist.
#     5. Deletes only the systemd unit files:
#
#          /etc/systemd/system/<BACKUP_OPERATION_NAME>.service
#          /etc/systemd/system/<BACKUP_OPERATION_NAME>.timer
#
#     6. Reloads systemd.
#     7. Resets failed unit state.
#
# Important:
#   This script does NOT delete:
#
#     /etc/restic
#     /etc/restic/password
#     /etc/restic/restic.env
#     /etc/restic/excludes
#
#   It also does NOT delete your Backblaze bucket or restic repository.
#
# Usage:
#   1. Set BACKUP_OPERATION_NAME below to the same value used when creating
#      the backup service.
#
#   2. Run:
#
#        chmod +x remove-restic-systemd-backup.sh
#        sudo ./remove-restic-systemd-backup.sh
#
# Example:
#   If your setup script used:
#
#        BACKUP_OPERATION_NAME="restic-backblaze-backup"
#
#   then this script will remove:
#
#        /etc/systemd/system/restic-backblaze-backup.service
#        /etc/systemd/system/restic-backblaze-backup.timer
###############################################################################

###############################################################################
# User-editable setting
###############################################################################

BACKUP_OPERATION_NAME="restic-backblaze-backup"

###############################################################################
# Internal paths
###############################################################################

SYSTEMD_DIR="/etc/systemd/system"

SERVICE_UNIT="${BACKUP_OPERATION_NAME}.service"
TIMER_UNIT="${BACKUP_OPERATION_NAME}.timer"

SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_UNIT}"
TIMER_FILE="${SYSTEMD_DIR}/${TIMER_UNIT}"

###############################################################################
# Helpers
###############################################################################

die() {
  echo "ERROR: $*" >&2
  exit 1
}

unit_exists_in_systemd() {
  local unit_name="$1"

  systemctl list-unit-files --no-legend --no-pager "${unit_name}" 2>/dev/null | grep -q "^${unit_name}"
}

file_exists() {
  local file_path="$1"

  [[ -f "${file_path}" ]]
}

###############################################################################
# Pre-flight checks
###############################################################################

[[ "${EUID}" -eq 0 ]] || die "Run this script as root, for example: sudo $0"

[[ "${BACKUP_OPERATION_NAME}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "BACKUP_OPERATION_NAME contains invalid characters."

SERVICE_EXISTS=false
TIMER_EXISTS=false

if file_exists "${SERVICE_FILE}" || unit_exists_in_systemd "${SERVICE_UNIT}"; then
  SERVICE_EXISTS=true
fi

if file_exists "${TIMER_FILE}" || unit_exists_in_systemd "${TIMER_UNIT}"; then
  TIMER_EXISTS=true
fi

if [[ "${SERVICE_EXISTS}" == false && "${TIMER_EXISTS}" == false ]]; then
  echo "No matching systemd service or timer found for:"
  echo "  ${BACKUP_OPERATION_NAME}"
  echo
  echo "Checked:"
  echo "  ${SERVICE_FILE}"
  echo "  ${TIMER_FILE}"
  echo
  echo "Nothing to remove."
  exit 0
fi

###############################################################################
# Stop and disable units
###############################################################################

echo "Removing restic systemd backup units for:"
echo "  ${BACKUP_OPERATION_NAME}"
echo

if [[ "${TIMER_EXISTS}" == true ]]; then
  echo "Stopping timer if active:"
  echo "  ${TIMER_UNIT}"
  systemctl stop "${TIMER_UNIT}" 2>/dev/null || true

  echo "Disabling timer if enabled:"
  echo "  ${TIMER_UNIT}"
  systemctl disable "${TIMER_UNIT}" 2>/dev/null || true
fi

if [[ "${SERVICE_EXISTS}" == true ]]; then
  echo "Stopping service if active:"
  echo "  ${SERVICE_UNIT}"
  systemctl stop "${SERVICE_UNIT}" 2>/dev/null || true

  echo "Disabling service if enabled:"
  echo "  ${SERVICE_UNIT}"
  systemctl disable "${SERVICE_UNIT}" 2>/dev/null || true
fi

###############################################################################
# Remove systemd unit files only
###############################################################################

if [[ -f "${TIMER_FILE}" ]]; then
  echo "Deleting timer file:"
  echo "  ${TIMER_FILE}"
  rm -f "${TIMER_FILE}"
fi

if [[ -f "${SERVICE_FILE}" ]]; then
  echo "Deleting service file:"
  echo "  ${SERVICE_FILE}"
  rm -f "${SERVICE_FILE}"
fi

###############################################################################
# Reload systemd
###############################################################################

systemctl daemon-reload
systemctl reset-failed "${TIMER_UNIT}" 2>/dev/null || true
systemctl reset-failed "${SERVICE_UNIT}" 2>/dev/null || true

###############################################################################
# Final status
###############################################################################

echo
echo "Removed systemd backup units for:"
echo "  ${BACKUP_OPERATION_NAME}"
echo
echo "Kept restic configuration untouched:"
echo "  /etc/restic"
echo "  /etc/restic/password"
echo "  /etc/restic/restic.env"
echo "  /etc/restic/excludes"
echo
echo "Verify removal:"
echo "  systemctl list-timers | grep ${BACKUP_OPERATION_NAME} || true"
echo "  systemctl status ${TIMER_UNIT}"
echo "  systemctl status ${SERVICE_UNIT}"
