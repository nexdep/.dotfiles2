#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# setup-restic-systemd-backup.sh
#
# Purpose:
#   Sets up a regular systemd-based restic backup job.
#
#   This script:
#     1. Checks that restic is installed.
#     2. Checks that BACKUP_PATH exists.
#     3. Checks that these files already exist:
#
#          /etc/restic/password
#          /etc/restic/restic.env
#          /etc/restic/excludes
#
#     4. Locks down permissions on those files.
#     5. Loads /etc/restic/restic.env.
#     6. Checks whether the restic repository is already initialized.
#     7. Runs `restic init` automatically if the repository is not initialized.
#     8. Creates a systemd service and timer.
#     9. Enables and starts the timer.
#
# Usage:
#   1. First run:
#
#        sudo ./create-restic-config-placeholders.sh
#
#   2. Edit the generated files:
#
#        sudo nano /etc/restic/restic.env
#        sudo nano /etc/restic/password
#        sudo nano /etc/restic/excludes
#
#   3. Edit the variables below in this script:
#
#        BACKUP_PATH
#        BACKUP_OPERATION_NAME
#        KEEP_DAILY
#        KEEP_WEEKLY
#        KEEP_MONTHLY
#        ON_CALENDAR
#
#   4. Run:
#
#        chmod +x setup-restic-systemd-backup.sh
#        sudo ./setup-restic-systemd-backup.sh
#
# Important:
#   This script does NOT generate /etc/restic config files.
#   It only checks that they already exist.
###############################################################################

###############################################################################
# User-editable settings
###############################################################################

# Folder to back up.
# The script stops if this folder does not exist.
BACKUP_PATH="/path/to/folder/to/backup"

# Operation name.
# This becomes:
#
#   /etc/systemd/system/<BACKUP_OPERATION_NAME>.service
#   /etc/systemd/system/<BACKUP_OPERATION_NAME>.timer
#
# Use only letters, numbers, dots, underscores, @, and hyphens.
BACKUP_OPERATION_NAME="restic-backblaze-backup"

# Restic retention policy.
# These values are passed to:
#
#   restic forget --keep-daily ... --keep-weekly ... --keep-monthly ... --prune
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

# Timer schedule.
# This example runs every day at 03:00.
ON_CALENDAR="*-*-* 03:00:00"

# Random delay before backup starts.
# Useful when multiple servers might run backups at the same time.
RANDOMIZED_DELAY_SEC="1h"

###############################################################################
# Internal paths
###############################################################################

RESTIC_DIR="/etc/restic"
RESTIC_PASSWORD_FILE="${RESTIC_DIR}/password"
RESTIC_ENV_FILE="${RESTIC_DIR}/restic.env"
RESTIC_EXCLUDES_FILE="${RESTIC_DIR}/excludes"

SYSTEMD_DIR="/etc/systemd/system"
SERVICE_UNIT="${BACKUP_OPERATION_NAME}.service"
TIMER_UNIT="${BACKUP_OPERATION_NAME}.timer"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_UNIT}"
TIMER_FILE="${SYSTEMD_DIR}/${TIMER_UNIT}"

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

escape_systemd_env_value() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/}"

  printf '%s' "${value}"
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

validate_required_env_value() {
  local variable_name="$1"
  local variable_value="$2"

  [[ -n "${variable_value}" ]] || die "${variable_name} is missing in ${RESTIC_ENV_FILE}"
  [[ "${variable_value}" != *CHANGE_ME* ]] || die "${variable_name} still contains a CHANGE_ME placeholder in ${RESTIC_ENV_FILE}"
}

validate_restic_password_file() {
  local password

  [[ -f "${RESTIC_PASSWORD_FILE}" ]] || die "RESTIC_PASSWORD_FILE points to a missing file: ${RESTIC_PASSWORD_FILE}"
  [[ -r "${RESTIC_PASSWORD_FILE}" ]] || die "RESTIC_PASSWORD_FILE is not readable: ${RESTIC_PASSWORD_FILE}"

  password=""
  IFS= read -r password < "${RESTIC_PASSWORD_FILE}" || true

  [[ -n "${password}" ]] || die "Restic password file is empty: ${RESTIC_PASSWORD_FILE}"
  [[ "${password}" != "CHANGE_ME_TO_A_LONG_RANDOM_RESTIC_REPOSITORY_PASSWORD" ]] \
    || die "Restic password file still contains the generated placeholder: ${RESTIC_PASSWORD_FILE}"
}

validate_restic_env() {
  # These are required for the Backblaze B2 S3-compatible restic setup.

  validate_required_env_value "AWS_ACCESS_KEY_ID" "${AWS_ACCESS_KEY_ID:-}"
  validate_required_env_value "AWS_SECRET_ACCESS_KEY" "${AWS_SECRET_ACCESS_KEY:-}"
  validate_required_env_value "RESTIC_REPOSITORY" "${RESTIC_REPOSITORY:-}"
  [[ -n "${RESTIC_PASSWORD_FILE:-}" ]] || die "RESTIC_PASSWORD_FILE is missing in ${RESTIC_ENV_FILE}"

  validate_restic_password_file
}

repo_looks_uninitialized_error() {
  # restic's exact error text can vary depending on backend/version.
  # These patterns cover the common cases where the remote repo exists as a
  # location, but restic's config file has not been created yet.

  local output="$1"

  grep -Eiq \
    'Is there a repository|repository does not exist|config file does not exist|specified key does not exist|NoSuchKey|not found|does not exist' \
    <<< "${output}"
}

ensure_restic_repo_initialized() {
  local output
  local status

  echo "Checking whether the restic repository is initialized..."

  set +e
  output="$(restic cat config 2>&1)"
  status=$?
  set -e

  if [[ "${status}" -eq 0 ]]; then
    echo "Restic repository is already initialized."
    return 0
  fi

  if repo_looks_uninitialized_error "${output}"; then
    echo "Restic repository does not appear to be initialized."
    echo "Running: restic init"
    restic init
    echo "Restic repository initialized."
    return 0
  fi

  echo
  echo "restic cat config failed, but the error does not look like an uninitialized repository."
  echo "Not running restic init automatically, because this may be a credentials, network, password, or bucket problem."
  echo
  echo "restic output:"
  echo "${output}"
  echo

  die "Cannot verify restic repository state."
}

###############################################################################
# Pre-flight checks
###############################################################################

[[ "${EUID}" -eq 0 ]] || die "Run this script as root, for example: sudo $0"

command -v restic >/dev/null 2>&1 || die "restic is not installed or not in PATH."

[[ -d "${BACKUP_PATH}" ]] || die "Backup folder does not exist: ${BACKUP_PATH}"

[[ "${BACKUP_OPERATION_NAME}" =~ ^[A-Za-z0-9_.@-]+$ ]] || die "BACKUP_OPERATION_NAME contains invalid characters."

[[ "${KEEP_DAILY}" =~ ^[0-9]+$ ]] || die "KEEP_DAILY must be a number."
[[ "${KEEP_WEEKLY}" =~ ^[0-9]+$ ]] || die "KEEP_WEEKLY must be a number."
[[ "${KEEP_MONTHLY}" =~ ^[0-9]+$ ]] || die "KEEP_MONTHLY must be a number."

check_required_file "${RESTIC_PASSWORD_FILE}"
check_required_file "${RESTIC_ENV_FILE}"
check_required_file "${RESTIC_EXCLUDES_FILE}"

chown root:root "${RESTIC_PASSWORD_FILE}" "${RESTIC_ENV_FILE}" "${RESTIC_EXCLUDES_FILE}"
chmod 600 "${RESTIC_PASSWORD_FILE}" "${RESTIC_ENV_FILE}" "${RESTIC_EXCLUDES_FILE}"
chmod 700 "${RESTIC_DIR}"

###############################################################################
# Load restic config and initialize repo if needed
###############################################################################

load_restic_env
validate_restic_env
ensure_restic_repo_initialized

###############################################################################
# Handle existing systemd service/timer
###############################################################################

if [[ -e "${SERVICE_FILE}" || -e "${TIMER_FILE}" ]]; then
  echo
  echo "Existing systemd files found:"
  [[ -e "${SERVICE_FILE}" ]] && echo "  ${SERVICE_FILE}"
  [[ -e "${TIMER_FILE}" ]] && echo "  ${TIMER_FILE}"
  echo

  if yes_or_no "Replace the existing service and timer?"; then
    echo "Stopping and disabling existing units..."

    systemctl stop "${TIMER_UNIT}" 2>/dev/null || true
    systemctl stop "${SERVICE_UNIT}" 2>/dev/null || true

    systemctl disable "${TIMER_UNIT}" 2>/dev/null || true
    systemctl disable "${SERVICE_UNIT}" 2>/dev/null || true

    rm -f "${SERVICE_FILE}" "${TIMER_FILE}"

    systemctl daemon-reload
    systemctl reset-failed "${TIMER_UNIT}" 2>/dev/null || true
    systemctl reset-failed "${SERVICE_UNIT}" 2>/dev/null || true

    echo "Old service and timer removed."
  else
    echo "Leaving existing systemd files unchanged."
    exit 0
  fi
fi

###############################################################################
# Generate systemd service
###############################################################################

BACKUP_PATH_ESCAPED="$(escape_systemd_env_value "${BACKUP_PATH}")"
BACKUP_OPERATION_NAME_ESCAPED="$(escape_systemd_env_value "${BACKUP_OPERATION_NAME}")"
RESTIC_EXCLUDES_FILE_ESCAPED="$(escape_systemd_env_value "${RESTIC_EXCLUDES_FILE}")"

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Restic backup: ${BACKUP_OPERATION_NAME}
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot

# Load Backblaze/restic credentials and repository settings.
EnvironmentFile=${RESTIC_ENV_FILE}

# Backup-specific variables.
Environment="BACKUP_PATH=${BACKUP_PATH_ESCAPED}"
Environment="BACKUP_OPERATION_NAME=${BACKUP_OPERATION_NAME_ESCAPED}"
Environment="RESTIC_EXCLUDES_FILE=${RESTIC_EXCLUDES_FILE_ESCAPED}"
Environment="KEEP_DAILY=${KEEP_DAILY}"
Environment="KEEP_WEEKLY=${KEEP_WEEKLY}"
Environment="KEEP_MONTHLY=${KEEP_MONTHLY}"

# Fail early if the backup path disappeared.
ExecStartPre=/bin/bash -lc 'test -d "\${BACKUP_PATH}"'

# Create a new snapshot.
ExecStart=/bin/bash -lc 'restic backup "\${BACKUP_PATH}" --tag "\${BACKUP_OPERATION_NAME}" --exclude-file="\${RESTIC_EXCLUDES_FILE}"'

# Apply retention policy and prune unused data.
ExecStart=/bin/bash -lc 'restic forget --tag "\${BACKUP_OPERATION_NAME}" --keep-daily "\${KEEP_DAILY}" --keep-weekly "\${KEEP_WEEKLY}" --keep-monthly "\${KEEP_MONTHLY}" --prune'

# Verify repository consistency.
ExecStart=/bin/bash -lc 'restic check'

Nice=10
IOSchedulingClass=best-effort
TimeoutStartSec=0
EOF

chmod 644 "${SERVICE_FILE}"
chown root:root "${SERVICE_FILE}"

###############################################################################
# Generate systemd timer
###############################################################################

cat > "${TIMER_FILE}" <<EOF
[Unit]
Description=Run Restic backup timer: ${BACKUP_OPERATION_NAME}

[Timer]
OnCalendar=${ON_CALENDAR}
RandomizedDelaySec=${RANDOMIZED_DELAY_SEC}
Persistent=true
Unit=${SERVICE_UNIT}

[Install]
WantedBy=timers.target
EOF

chmod 644 "${TIMER_FILE}"
chown root:root "${TIMER_FILE}"

###############################################################################
# Enable and start timer
###############################################################################

systemctl daemon-reload
systemctl enable --now "${TIMER_UNIT}"

echo
echo "Restic systemd backup timer installed and started."
echo
echo "Service:"
echo "  ${SERVICE_UNIT}"
echo
echo "Timer:"
echo "  ${TIMER_UNIT}"
echo
echo "Check timer:"
echo "  systemctl list-timers ${TIMER_UNIT}"
echo
echo "Run backup manually:"
echo "  systemctl start ${SERVICE_UNIT}"
echo
echo "View logs:"
echo "  journalctl -u ${SERVICE_UNIT} -n 100 --no-pager"
