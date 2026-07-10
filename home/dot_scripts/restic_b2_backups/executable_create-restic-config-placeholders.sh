#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# create-restic-config-placeholders.sh
#
# Purpose:
#   Creates the required restic configuration files under /etc/restic:
#
#     /etc/restic/password
#     /etc/restic/restic.env
#     /etc/restic/excludes
#
#   If any file already exists, the script asks whether to overwrite it.
#   It also locks down permissions so only root can read the secrets.
#
# Usage:
#   chmod +x create-restic-config-placeholders.sh
#   sudo ./create-restic-config-placeholders.sh
#
# After running:
#   sudo nano /etc/restic/restic.env
#   sudo nano /etc/restic/password
#   sudo nano /etc/restic/excludes
#
# Important:
#   The generated files contain placeholders. Replace them before running
#   the systemd setup script.
###############################################################################

RESTIC_DIR="/etc/restic"
RESTIC_PASSWORD_FILE="${RESTIC_DIR}/password"
RESTIC_ENV_FILE="${RESTIC_DIR}/restic.env"
RESTIC_EXCLUDES_FILE="${RESTIC_DIR}/excludes"

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

write_password_file() {
  local file_path="$1"

  cat > "${file_path}" <<'EOF'
CHANGE_ME_TO_A_LONG_RANDOM_RESTIC_REPOSITORY_PASSWORD
EOF
}

write_env_file() {
  local file_path="$1"

  cat > "${file_path}" <<'EOF'
# Restic environment file for Backblaze B2 using the S3-compatible API.
#
# Replace all CHANGE_ME values before using the backup service.
#
# Backblaze example:
#   AWS_ACCESS_KEY_ID=your_backblaze_key_id
#   AWS_SECRET_ACCESS_KEY=your_backblaze_application_key
#   RESTIC_REPOSITORY=s3:s3.eu-central-003.backblazeb2.com/my-bucket/my-server-repo
#   RESTIC_PASSWORD_FILE=/etc/restic/password
#
# Notes:
#   AWS_ACCESS_KEY_ID is your Backblaze key ID.
#   AWS_SECRET_ACCESS_KEY is your Backblaze application key.
#   RESTIC_REPOSITORY is the restic repo location inside your bucket.
#   RESTIC_PASSWORD_FILE points to the local restic encryption password file.

AWS_ACCESS_KEY_ID=CHANGE_ME_BACKBLAZE_KEY_ID
AWS_SECRET_ACCESS_KEY=CHANGE_ME_BACKBLAZE_APPLICATION_KEY
RESTIC_REPOSITORY=s3:CHANGE_ME_BACKBLAZE_S3_ENDPOINT/CHANGE_ME_BUCKET_NAME/CHANGE_ME_REPOSITORY_PREFIX
RESTIC_PASSWORD_FILE=/etc/restic/password
EOF
}

write_excludes_file() {
  local file_path="$1"

  cat > "${file_path}" <<'EOF'
# General temporary/cache excludes.
# Edit this file if any of these paths are important for your backup.

*.tmp
*.temp
*.swp
*.swo
*~
.DS_Store
Thumbs.db

.cache/
cache/
tmp/
node_modules/
__pycache__/
.git/
EOF
}

write_file_with_prompt() {
  local file_path="$1"
  local description="$2"
  local writer_function="$3"

  if [[ -f "${file_path}" ]]; then
    echo "Found existing ${description}: ${file_path}"

    if yes_or_no "Overwrite ${file_path}?"; then
      "${writer_function}" "${file_path}"
      echo "Overwritten: ${file_path}"
    else
      echo "Kept existing: ${file_path}"
    fi
  else
    "${writer_function}" "${file_path}"
    echo "Created: ${file_path}"
  fi
}

###############################################################################
# Main
###############################################################################

[[ "${EUID}" -eq 0 ]] || die "Run this script as root, for example: sudo $0"

install -d -m 700 -o root -g root "${RESTIC_DIR}"

write_file_with_prompt "${RESTIC_PASSWORD_FILE}" "restic password file" write_password_file
write_file_with_prompt "${RESTIC_ENV_FILE}" "restic environment file" write_env_file
write_file_with_prompt "${RESTIC_EXCLUDES_FILE}" "restic excludes file" write_excludes_file

chown root:root "${RESTIC_PASSWORD_FILE}" "${RESTIC_ENV_FILE}" "${RESTIC_EXCLUDES_FILE}"
chmod 600 "${RESTIC_PASSWORD_FILE}" "${RESTIC_ENV_FILE}" "${RESTIC_EXCLUDES_FILE}"
chmod 700 "${RESTIC_DIR}"

echo
echo "Restic config files are present and locked:"
echo "  ${RESTIC_PASSWORD_FILE}"
echo "  ${RESTIC_ENV_FILE}"
echo "  ${RESTIC_EXCLUDES_FILE}"
echo
echo "Next steps:"
echo "  sudo nano ${RESTIC_ENV_FILE}"
echo "  sudo nano ${RESTIC_PASSWORD_FILE}"
echo "  sudo nano ${RESTIC_EXCLUDES_FILE}"
echo
echo "After replacing placeholders, run the systemd setup script."
