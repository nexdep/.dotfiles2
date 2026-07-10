#!/usr/bin/env bash
set -euo pipefail

# =========================
# Edit these values
# =========================

STORAGE_ALIAS="marco-hetzner-storage-1"
REMOTE_PATH="/home"
MOUNT_POINT="/mnt/hetzner-storage-1"

SERVICE_NAME="hetzner-storagebox.service"

# Usually keep this "no" for user mounts.
USE_ALLOW_OTHER="no"

# =========================
# Do not edit below unless needed
# =========================

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script with sudo."
  echo "Run it as your normal user:"
  echo "  ./setup_hetzner_storagebox_user_service.sh"
  exit 1
fi

LOCAL_USER="$(id -un)"
LOCAL_UID="$(id -u)"
LOCAL_GID="$(id -g)"
USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${USER_SYSTEMD_DIR}/${SERVICE_NAME}"

echo "User:           ${LOCAL_USER}"
echo "Mount point:    ${MOUNT_POINT}"
echo "Service file:   ${SERVICE_FILE}"
echo "SSH alias:      ${STORAGE_ALIAS}"
echo "UID:GID:        ${LOCAL_UID}:${LOCAL_GID}"

# =========================
# Validate SSH config
# =========================

if [[ ! -f "${HOME}/.ssh/config" ]]; then
  echo "Missing SSH config: ${HOME}/.ssh/config"
  exit 1
fi

if ! grep -qE "^[[:space:]]*Host[[:space:]]+.*\b${STORAGE_ALIAS}\b" "${HOME}/.ssh/config"; then
  echo "Could not find Host ${STORAGE_ALIAS} in ${HOME}/.ssh/config"
  exit 1
fi

# =========================
# Install dependency
# =========================

if ! command -v sshfs >/dev/null 2>&1; then
  echo "Installing sshfs..."
  sudo apt update
  sudo apt install -y sshfs
fi

if ! command -v fusermount3 >/dev/null 2>&1; then
  echo "fusermount3 not found. Install fuse3/sshfs."
  exit 1
fi

# =========================
# Create and own mount point
# =========================

sudo mkdir -p "$MOUNT_POINT"
sudo chown "${LOCAL_UID}:${LOCAL_GID}" "$MOUNT_POINT"

# =========================
# Optional allow_other support
# =========================

SSHFS_OPTIONS="reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,default_permissions,uid=${LOCAL_UID},gid=${LOCAL_GID},BatchMode=yes"

if [[ "$USE_ALLOW_OTHER" == "yes" ]]; then
  if [[ -f /etc/fuse.conf ]]; then
    if grep -qE '^[#[:space:]]*user_allow_other' /etc/fuse.conf; then
      sudo sed -i 's/^[#[:space:]]*user_allow_other/user_allow_other/' /etc/fuse.conf
    else
      echo "user_allow_other" | sudo tee -a /etc/fuse.conf >/dev/null
    fi
  else
    echo "user_allow_other" | sudo tee /etc/fuse.conf >/dev/null
  fi

  SSHFS_OPTIONS="${SSHFS_OPTIONS},allow_other"
fi

# =========================
# Remove old failed automount/mount units
# =========================

OLD_MOUNT_UNIT="$(systemd-escape --path --suffix=mount "$MOUNT_POINT")"
OLD_AUTOMOUNT_UNIT="${OLD_MOUNT_UNIT%.mount}.automount"

systemctl --user disable --now "$OLD_AUTOMOUNT_UNIT" 2>/dev/null || true
systemctl --user stop "$OLD_MOUNT_UNIT" 2>/dev/null || true
systemctl --user reset-failed "$OLD_AUTOMOUNT_UNIT" 2>/dev/null || true
systemctl --user reset-failed "$OLD_MOUNT_UNIT" 2>/dev/null || true

rm -f "${USER_SYSTEMD_DIR}/${OLD_AUTOMOUNT_UNIT}"
rm -f "${USER_SYSTEMD_DIR}/${OLD_MOUNT_UNIT}"

# =========================
# Unmount if already mounted
# =========================

if mountpoint -q "$MOUNT_POINT"; then
  fusermount3 -u "$MOUNT_POINT" || sudo umount "$MOUNT_POINT" || true
fi

# =========================
# Write user systemd service
# =========================

mkdir -p "$USER_SYSTEMD_DIR"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Mount Hetzner Storage Box via SSHFS
After=default.target

[Service]
Type=simple
ExecStart=/usr/bin/sshfs -f ${STORAGE_ALIAS}:${REMOTE_PATH} ${MOUNT_POINT} -o ${SSHFS_OPTIONS}
ExecStop=/usr/bin/fusermount3 -u ${MOUNT_POINT}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

# =========================
# Enable lingering for boot persistence
# =========================

sudo loginctl enable-linger "$LOCAL_USER"

# =========================
# Reload and enable service
# =========================

systemctl --user daemon-reload
systemctl --user enable --now "$SERVICE_NAME"

# =========================
# Test
# =========================

echo
echo "Service enabled."
echo "Testing access to ${MOUNT_POINT}..."
ls "$MOUNT_POINT" >/dev/null

echo
echo "Success."
findmnt "$MOUNT_POINT" || true

echo
echo "Useful commands:"
echo "  systemctl --user status ${SERVICE_NAME}"
echo "  journalctl --user -u ${SERVICE_NAME} -n 100 --no-pager"
echo "  systemctl --user restart ${SERVICE_NAME}"
echo "  systemctl --user stop ${SERVICE_NAME}"
echo "  fusermount3 -u ${MOUNT_POINT}"
