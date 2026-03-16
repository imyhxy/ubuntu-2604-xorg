#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/gnome49-downgrade"
OUT_DIR="${ROOT_DIR}/out"

"${ROOT_DIR}/scripts/download-gnome49-downgrade-debs.sh"

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

echo "Simulating downgrade/install with apt:"
printf '  %s\n' "${debs[@]}"
echo

apt-get -s install --allow-downgrades --reinstall "${debs[@]}"
