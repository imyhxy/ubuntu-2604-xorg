#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/gnome49-downgrade"
OUT_DIR="${ROOT_DIR}/out"

mkdir -p "${DOWNLOAD_DIR}" "${OUT_DIR}"

download_if_missing() {
  local url="$1"
  local dest="$2"
  if [[ -f "${dest}" ]]; then
    return 0
  fi

  echo "Downloading $(basename "${dest}")"
  curl -fsSL -o "${dest}" "${url}"
}

download_if_missing \
  "https://launchpadlibrarian.net/837100751/gdm3_49.2-1ubuntu3_amd64.deb" \
  "${DOWNLOAD_DIR}/gdm3_49.2-1ubuntu3_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/837100752/libgdm1_49.2-1ubuntu3_amd64.deb" \
  "${DOWNLOAD_DIR}/libgdm1_49.2-1ubuntu3_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/837100748/gir1.2-gdm-1.0_49.2-1ubuntu3_amd64.deb" \
  "${DOWNLOAD_DIR}/gir1.2-gdm-1.0_49.2-1ubuntu3_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/839617002/gnome-session_49.2-3ubuntu1_all.deb" \
  "${DOWNLOAD_DIR}/gnome-session_49.2-3ubuntu1_all.deb"
download_if_missing \
  "https://launchpadlibrarian.net/839617004/gnome-session-bin_49.2-3ubuntu1_amd64.deb" \
  "${DOWNLOAD_DIR}/gnome-session-bin_49.2-3ubuntu1_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/839617001/gnome-session-common_49.2-3ubuntu1_all.deb" \
  "${DOWNLOAD_DIR}/gnome-session-common_49.2-3ubuntu1_all.deb"
download_if_missing \
  "https://launchpadlibrarian.net/839617003/ubuntu-session_49.2-3ubuntu1_all.deb" \
  "${DOWNLOAD_DIR}/ubuntu-session_49.2-3ubuntu1_all.deb"
download_if_missing \
  "https://launchpadlibrarian.net/844026893/gnome-shell_49.2-1ubuntu2_amd64.deb" \
  "${DOWNLOAD_DIR}/gnome-shell_49.2-1ubuntu2_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/844026889/gnome-shell-common_49.2-1ubuntu2_all.deb" \
  "${DOWNLOAD_DIR}/gnome-shell-common_49.2-1ubuntu2_all.deb"
download_if_missing \
  "https://launchpadlibrarian.net/844026892/gnome-shell-extension-prefs_49.2-1ubuntu2_amd64.deb" \
  "${DOWNLOAD_DIR}/gnome-shell-extension-prefs_49.2-1ubuntu2_amd64.deb"
download_if_missing \
  "https://launchpadlibrarian.net/845250691/gnome-shell-ubuntu-extensions_49.26.04.2ubuntu_all.deb" \
  "${DOWNLOAD_DIR}/gnome-shell-ubuntu-extensions_49.26.04.2ubuntu_all.deb"

download_if_missing \
  "https://github.com/imyhxy/ubuntu-2604-xorg/releases/download/mutter-49.2-1ubuntu1-ubuntu2604xorg1/libmutter-17-0_49.2-1ubuntu1%2Bubuntu2604xorg1_amd64.deb" \
  "${OUT_DIR}/libmutter-17-0_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"
download_if_missing \
  "https://github.com/imyhxy/ubuntu-2604-xorg/releases/download/mutter-49.2-1ubuntu1-ubuntu2604xorg1/mutter-common_49.2-1ubuntu1%2Bubuntu2604xorg1_all.deb" \
  "${OUT_DIR}/mutter-common_49.2-1ubuntu1+ubuntu2604xorg1_all.deb"
download_if_missing \
  "https://github.com/imyhxy/ubuntu-2604-xorg/releases/download/mutter-49.2-1ubuntu1-ubuntu2604xorg1/mutter-common-bin_49.2-1ubuntu1%2Bubuntu2604xorg1_amd64.deb" \
  "${OUT_DIR}/mutter-common-bin_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"
download_if_missing \
  "https://github.com/imyhxy/ubuntu-2604-xorg/releases/download/mutter-49.2-1ubuntu1-ubuntu2604xorg1/gir1.2-mutter-17_49.2-1ubuntu1%2Bubuntu2604xorg1_amd64.deb" \
  "${OUT_DIR}/gir1.2-mutter-17_49.2-1ubuntu1+ubuntu2604xorg1_amd64.deb"

"${ROOT_DIR}/scripts/build-ubuntu-xorg-session-deb.sh"

echo
echo "Downloaded GNOME 49 downgrade .debs into ${DOWNLOAD_DIR}"
echo "Local mutter/session .debs are available in ${OUT_DIR}"
