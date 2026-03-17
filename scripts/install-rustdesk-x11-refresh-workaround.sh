#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES=0
TARGET_USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES=1
      shift
      ;;
    --user)
      TARGET_USER="${2:-}"
      shift 2
      ;;
    --help|-h)
      cat <<EOF
Install a systemd workaround that restarts rustdesk.service when the chosen
user gets an active X11 desktop session.

Usage:
  sudo ${ROOT_DIR}/scripts/install-rustdesk-x11-refresh-workaround.sh --yes [--user USERNAME]

Default user:
  If --user is omitted, the script uses \$SUDO_USER.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${YES}" != "1" ]]; then
  cat <<EOF
This script installs a root systemd path/service workaround and requires sudo.

Preview:
  sudo ${ROOT_DIR}/scripts/install-rustdesk-x11-refresh-workaround.sh --yes [--user USERNAME]
EOF
  exit 0
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

if [[ -z "${TARGET_USER}" ]]; then
  TARGET_USER="${SUDO_USER:-}"
fi

if [[ -z "${TARGET_USER}" ]]; then
  echo "Could not determine target user. Pass --user USERNAME." >&2
  exit 1
fi

TARGET_UID="$(id -u "${TARGET_USER}")"
INSTALL_ROOT="/usr/local/lib/ubuntu-2604-xorg"
HELPER_DEST="${INSTALL_ROOT}/rustdesk-x11-refresh-helper.sh"
SERVICE_PATH="/etc/systemd/system/rustdesk-x11-refresh.service"
PATH_UNIT_PATH="/etc/systemd/system/rustdesk-x11-refresh.path"

install -d -m 0755 "${INSTALL_ROOT}"
install -m 0755 "${ROOT_DIR}/scripts/rustdesk-x11-refresh-helper.sh" "${HELPER_DEST}"

cat > "${SERVICE_PATH}" <<EOF
[Unit]
Description=Restart RustDesk after ${TARGET_USER} enters an X11 session
After=rustdesk.service

[Service]
Type=oneshot
ExecStart=${HELPER_DEST} ${TARGET_USER}
EOF

cat > "${PATH_UNIT_PATH}" <<EOF
[Unit]
Description=Watch for ${TARGET_USER} X11 session readiness to refresh RustDesk

[Path]
PathExists=/run/user/${TARGET_UID}/gdm/Xauthority
PathChanged=/run/user/${TARGET_UID}/gdm/Xauthority
Unit=rustdesk-x11-refresh.service

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now rustdesk-x11-refresh.path

echo
echo "Installed rustdesk X11 refresh workaround for user ${TARGET_USER} (uid ${TARGET_UID})."
echo "The path unit is now active:"
echo "  systemctl status rustdesk-x11-refresh.path"
