#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/gnome49-downgrade"
OUT_DIR="${ROOT_DIR}/out"
YES="${1:-}"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script downgrades the host from the current GNOME 50 stack to the
older GNOME 49-compatible package set used by this repo.

It requires sudo. To preview the package plan first, run:
  ${ROOT_DIR}/scripts/simulate-gnome49-downgrade.sh

To proceed, run:
  ${ROOT_DIR}/scripts/install-gnome49-downgrade.sh --yes
EOF
  exit 0
fi

"${ROOT_DIR}/scripts/simulate-gnome49-downgrade.sh"

debs=(
  "${DOWNLOAD_DIR}/gdm3_49.2-1ubuntu3_amd64.deb"
  "${DOWNLOAD_DIR}/libgdm1_49.2-1ubuntu3_amd64.deb"
  "${DOWNLOAD_DIR}/gir1.2-gdm-1.0_49.2-1ubuntu3_amd64.deb"
  "${DOWNLOAD_DIR}/gnome-session_49.2-3ubuntu1_all.deb"
  "${DOWNLOAD_DIR}/gnome-session-bin_49.2-3ubuntu1_amd64.deb"
  "${DOWNLOAD_DIR}/gnome-session-common_49.2-3ubuntu1_all.deb"
  "${DOWNLOAD_DIR}/ubuntu-session_49.2-3ubuntu1_all.deb"
  "${DOWNLOAD_DIR}/gnome-shell_49.2-1ubuntu2_amd64.deb"
  "${DOWNLOAD_DIR}/gnome-shell-common_49.2-1ubuntu2_all.deb"
  "${DOWNLOAD_DIR}/gnome-shell-extension-prefs_49.2-1ubuntu2_amd64.deb"
  "${DOWNLOAD_DIR}/gnome-shell-ubuntu-extensions_49.26.04.2ubuntu_all.deb"
  "${OUT_DIR}/libmutter-17-0_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"
  "${OUT_DIR}/mutter-common_49.2-1ubuntu1+ubuntu2604xorg1_all.deb"
  "${OUT_DIR}/mutter-common-bin_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"
  "${OUT_DIR}/gir1.2-mutter-17_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"
  "${OUT_DIR}/ubuntu-xorg-session_1.0_all.deb"
)

sudo apt install -y --allow-downgrades --reinstall "${debs[@]}"

echo
echo "Downgrade install complete."
echo "Next:"
echo "  1. Log out"
echo "  2. Choose “Ubuntu on Xorg” in GDM"
echo "  3. If it fails, switch to a TTY and run ${ROOT_DIR}/scripts/rollback.sh --yes"
