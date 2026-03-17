#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo." >&2
  exit 1
fi

systemctl disable --now rustdesk-x11-refresh.path >/dev/null 2>&1 || true
rm -f /etc/systemd/system/rustdesk-x11-refresh.path
rm -f /etc/systemd/system/rustdesk-x11-refresh.service
rm -f /usr/local/lib/ubuntu-2604-xorg/rustdesk-x11-refresh-helper.sh
systemctl daemon-reload

echo "Removed rustdesk X11 refresh workaround."
