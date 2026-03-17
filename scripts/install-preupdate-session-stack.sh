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
Install the exact login/session stack that was present immediately before the
2026-03-16 09:09:48 apt dist-upgrade.

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
This script installs packages on the host and requires sudo.

Preview first:
  ${ROOT_DIR}/scripts/simulate-preupdate-session-stack.sh

To proceed:
  ${ROOT_DIR}/scripts/install-preupdate-session-stack.sh --yes
EOF
  exit 0
fi

# shellcheck source=./preupdate-session-stack-packages.sh
source "${ROOT_DIR}/scripts/preupdate-session-stack-packages.sh"

bash "${ROOT_DIR}/scripts/simulate-preupdate-session-stack.sh"
mapfile -t debs < <(collect_deb_paths)

sudo apt install -y --allow-downgrades --reinstall \
  "${debs[@]}" \
  gnome-settings-daemon=50~beta-0ubuntu2 \
  gnome-settings-daemon-common=50~beta-0ubuntu2

echo
echo "Pre-update session stack restore complete."
echo "Next:"
echo "  1. Reboot"
echo "  2. Log in with Ubuntu on Xorg"
echo "  3. Re-test RustDesk UI/tray startup time"
