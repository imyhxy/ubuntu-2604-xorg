#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/rustdesk-slowdown-rollback"

mesa_entries() {
  cat <<'EOF'
https://launchpadlibrarian.net/835449855/libegl-mesa0_25.2.8-2ubuntu1_amd64.deb libegl-mesa0_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835449857/libgl1-mesa-dri_25.2.8-2ubuntu1_amd64.deb libgl1-mesa-dri_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835449858/libglx-mesa0_25.2.8-2ubuntu1_amd64.deb libglx-mesa0_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835449856/libgbm1_25.2.8-2ubuntu1_amd64.deb libgbm1_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835450123/libgbm1_25.2.8-2ubuntu1_i386.deb libgbm1_25.2.8-2ubuntu1_i386.deb
https://launchpadlibrarian.net/835449861/mesa-libgallium_25.2.8-2ubuntu1_amd64.deb mesa-libgallium_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835450130/mesa-libgallium_25.2.8-2ubuntu1_i386.deb mesa-libgallium_25.2.8-2ubuntu1_i386.deb
https://launchpadlibrarian.net/835449852/mesa-va-drivers_25.2.8-2ubuntu1_amd64.deb mesa-va-drivers_25.2.8-2ubuntu1_amd64.deb
https://launchpadlibrarian.net/835449853/mesa-vdpau-drivers_25.2.8-2ubuntu1_amd64.deb mesa-vdpau-drivers_25.2.8-2ubuntu1_amd64.deb
EOF
}

helper_entries() {
  cat <<'EOF'
https://launchpadlibrarian.net/820758228/gnome-settings-daemon_49.0-1ubuntu3_amd64.deb gnome-settings-daemon_49.0-1ubuntu3_amd64.deb
https://launchpadlibrarian.net/820758220/gnome-settings-daemon-common_49.0-1ubuntu3_all.deb gnome-settings-daemon-common_49.0-1ubuntu3_all.deb
https://launchpadlibrarian.net/817961901/xdg-desktop-portal-gnome_49.0-1ubuntu1_amd64.deb xdg-desktop-portal-gnome_49.0-1ubuntu1_amd64.deb
EOF
}

download_entries() {
  local include_helpers="${1:-0}"

  mkdir -p "${DOWNLOAD_DIR}"

  while read -r url filename; do
    [[ -n "${url}" ]] || continue
    if [[ -f "${DOWNLOAD_DIR}/${filename}" ]]; then
      continue
    fi
    echo "Downloading ${filename}"
    curl -fsSL -o "${DOWNLOAD_DIR}/${filename}" "${url}"
  done < <(
    mesa_entries
    if [[ "${include_helpers}" == "1" ]]; then
      helper_entries
    fi
  )
}

collect_deb_paths() {
  local include_helpers="${1:-0}"

  while read -r _url filename; do
    [[ -n "${filename}" ]] || continue
    printf '%s\n' "${DOWNLOAD_DIR}/${filename}"
  done < <(
    mesa_entries
    if [[ "${include_helpers}" == "1" ]]; then
      helper_entries
    fi
  )
}
