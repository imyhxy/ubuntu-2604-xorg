#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <username>" >&2
  exit 1
fi

target_user="$1"
target_uid="$(id -u "${target_user}")"
target_bus="/run/user/${target_uid}/bus"
target_xauth="/run/user/${target_uid}/gdm/Xauthority"

if [[ ! -S "${target_bus}" ]]; then
  echo "Skip: ${target_bus} not ready"
  exit 0
fi

if [[ ! -f "${target_xauth}" ]]; then
  echo "Skip: ${target_xauth} not ready"
  exit 0
fi

if ! loginctl list-sessions --no-legend | awk -v user="${target_user}" '$3 == user && $5 == "user" { print $1 }' \
  | while read -r sid; do
      loginctl show-session "${sid}" -p Type --value
    done \
  | grep -qx 'x11'; then
  echo "Skip: no active X11 session for ${target_user}"
  exit 0
fi

echo "Restarting rustdesk.service for ${target_user} X11 session"
systemctl restart rustdesk.service
