#!/usr/bin/env bash
set -euo pipefail

# =========================
# Must match original script
# =========================

MOUNT_POINT="/mnt/hetzner-storage-1"
SERVICE_NAME="hetzner-storagebox.service"

# =========================
# Do not edit below unless needed
# =========================

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script with sudo."
  echo "Run it as your normal user:"
  echo "  ./undo_hetzner_storagebox_user_service.sh"
  exit 1
fi

USER_SYSTEMD_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${USER_SYSTEMD_DIR}/${SERVICE_NAME}"

echo "Stopping user systemd service..."
systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null || true
systemctl --user reset-failed "$SERVICE_NAME" 2>/dev/null || true

echo "Unmounting ${MOUNT_POINT} if mounted..."
if mountpoint -q "$MOUNT_POINT"; then
  fusermount3 -u "$MOUNT_POINT" 2>/dev/null || fusermount -u "$MOUNT_POINT" 2>/dev/null || sudo umount "$MOUNT_POINT" || true
fi

echo "Removing systemd service file..."
rm -f "$SERVICE_FILE"

echo "Removing old mount/automount unit files if present..."
OLD_MOUNT_UNIT="$(systemd-escape --path --suffix=mount "$MOUNT_POINT")"
OLD_AUTOMOUNT_UNIT="${OLD_MOUNT_UNIT%.mount}.automount"

systemctl --user disable --now "$OLD_AUTOMOUNT_UNIT" 2>/dev/null || true
systemctl --user stop "$OLD_MOUNT_UNIT" 2>/dev/null || true
systemctl --user reset-failed "$OLD_AUTOMOUNT_UNIT" 2>/dev/null || true
systemctl --user reset-failed "$OLD_MOUNT_UNIT" 2>/dev/null || true

rm -f "${USER_SYSTEMD_DIR}/${OLD_AUTOMOUNT_UNIT}"
rm -f "${USER_SYSTEMD_DIR}/${OLD_MOUNT_UNIT}"

echo "Reloading user systemd..."
systemctl --user daemon-reload
systemctl --user reset-failed 2>/dev/null || true

echo "Removing mount directory..."
if [[ -d "$MOUNT_POINT" ]]; then
  if mountpoint -q "$MOUNT_POINT"; then
    echo "Still mounted, refusing to remove ${MOUNT_POINT}"
    exit 1
  fi

  if [[ -z "$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    sudo rmdir "$MOUNT_POINT"
  else
    echo "Mount point is not empty: ${MOUNT_POINT}"
    echo "Not removing it automatically."
    echo "Inspect it first, then remove manually if safe:"
    echo "  sudo rm -rf ${MOUNT_POINT}"
    exit 1
  fi
fi

echo
echo "Undo complete."
echo
echo "Optional cleanup you may still want to do:"
echo "  sudo loginctl disable-linger $(id -un)"
echo "  sudo apt remove sshfs"
echo "  Check /etc/fuse.conf if you enabled user_allow_other"
