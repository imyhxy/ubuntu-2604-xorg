#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/preupdate-session-stack"
OUT_DIR="${ROOT_DIR}/out"

download_entries() {
  mkdir -p "${DOWNLOAD_DIR}" "${OUT_DIR}"

  download_if_missing \
    "https://launchpadlibrarian.net/837687732/gdm3_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/gdm3_49.2-1ubuntu4_amd64.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/837687733/libgdm1_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/libgdm1_49.2-1ubuntu4_amd64.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/837687729/gir1.2-gdm-1.0_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/gir1.2-gdm-1.0_49.2-1ubuntu4_amd64.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/850772750/xdg-desktop-portal-gnome_50~rc-0ubuntu1_amd64.deb" \
    "${DOWNLOAD_DIR}/xdg-desktop-portal-gnome_50~rc-0ubuntu1_amd64.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/848064387/libgtk-4-1_4.21.5+ds-5_amd64.deb" \
    "${DOWNLOAD_DIR}/libgtk-4-1_4.21.5+ds-5_amd64.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/848064381/libgtk-4-common_4.21.5+ds-5_all.deb" \
    "${DOWNLOAD_DIR}/libgtk-4-common_4.21.5+ds-5_all.deb"
  download_if_missing \
    "https://launchpadlibrarian.net/848064374/gir1.2-gtk-4.0_4.21.5+ds-5_amd64.deb" \
    "${DOWNLOAD_DIR}/gir1.2-gtk-4.0_4.21.5+ds-5_amd64.deb"
}

download_if_missing() {
  local url="$1"
  local dest="$2"
  if [[ -f "${dest}" ]]; then
    return 0
  fi

  echo "Downloading $(basename "${dest}")"
  curl -fsSL -o "${dest}" "${url}"
}

collect_deb_paths() {
  printf '%s\n' \
    "${DOWNLOAD_DIR}/gdm3_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/libgdm1_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/gir1.2-gdm-1.0_49.2-1ubuntu4_amd64.deb" \
    "${DOWNLOAD_DIR}/xdg-desktop-portal-gnome_50~rc-0ubuntu1_amd64.deb" \
    "${DOWNLOAD_DIR}/libgtk-4-1_4.21.5+ds-5_amd64.deb" \
    "${DOWNLOAD_DIR}/libgtk-4-common_4.21.5+ds-5_all.deb" \
    "${DOWNLOAD_DIR}/gir1.2-gtk-4.0_4.21.5+ds-5_amd64.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-session_49.2-3ubuntu1_all.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-session-bin_49.2-3ubuntu1_amd64.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-session-common_49.2-3ubuntu1_all.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/ubuntu-session_49.2-3ubuntu1_all.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-shell_49.2-1ubuntu2_amd64.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-shell-common_49.2-1ubuntu2_all.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-shell-extension-prefs_49.2-1ubuntu2_amd64.deb" \
    "${ROOT_DIR}/out/gnome49-downgrade/gnome-shell-ubuntu-extensions_49.26.04.2ubuntu_all.deb" \
    "${OUT_DIR}/libmutter-17-0_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb" \
    "${OUT_DIR}/mutter-common_49.2-1ubuntu1+ubuntu2604xorg1_all.deb" \
    "${OUT_DIR}/mutter-common-bin_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb" \
    "${OUT_DIR}/gir1.2-mutter-17_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb" \
    "${OUT_DIR}/ubuntu-xorg-session_1.0_all.deb"
}
