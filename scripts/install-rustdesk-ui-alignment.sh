#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES=0

for arg in "$@"; do
  case "${arg}" in
    --yes)
      YES=1
      ;;
    --help|-h)
      cat <<EOF
Install the GTK/GNOME helper alignment rollback packages.

This downgrades:
  - libgtk-4-1
  - libgtk-4-common
  - gir1.2-gtk-4.0
  - gnome-settings-daemon
  - gnome-settings-daemon-common

Use --yes to perform the install.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

if [[ "${YES}" != "1" ]]; then
  cat <<EOF
This script installs rollback packages on the host and requires sudo.

Preview first:
  ${ROOT_DIR}/scripts/simulate-rustdesk-ui-alignment.sh

To proceed:
  ${ROOT_DIR}/scripts/install-rustdesk-ui-alignment.sh --yes
EOF
  exit 0
fi

# shellcheck source=./rustdesk-ui-alignment-packages.sh
source "${ROOT_DIR}/scripts/rustdesk-ui-alignment-packages.sh"

"${ROOT_DIR}/scripts/simulate-rustdesk-ui-alignment.sh"

mapfile -t debs < <(collect_deb_paths)

sudo apt install -y --allow-downgrades --reinstall "${debs[@]}"

echo
echo "UI-alignment install complete."
echo "Next:"
echo "  1. Log out and back in"
echo "  2. Re-test RustDesk tray/UI startup time"
echo "  3. If needed, reboot once so the downgraded GTK stack is fully reused"
