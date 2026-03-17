#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOWNLOAD_DIR="${ROOT_DIR}/out/rustdesk-ui-alignment"

ui_entries() {
  cat <<'EOF'
https://launchpadlibrarian.net/848064387/libgtk-4-1_4.21.5+ds-5_amd64.deb libgtk-4-1_4.21.5+ds-5_amd64.deb
https://launchpadlibrarian.net/848064374/gir1.2-gtk-4.0_4.21.5+ds-5_amd64.deb gir1.2-gtk-4.0_4.21.5+ds-5_amd64.deb
https://launchpadlibrarian.net/848064381/libgtk-4-common_4.21.5+ds-5_all.deb libgtk-4-common_4.21.5+ds-5_all.deb
https://launchpadlibrarian.net/820758228/gnome-settings-daemon_49.0-1ubuntu3_amd64.deb gnome-settings-daemon_49.0-1ubuntu3_amd64.deb
https://launchpadlibrarian.net/820758220/gnome-settings-daemon-common_49.0-1ubuntu3_all.deb gnome-settings-daemon-common_49.0-1ubuntu3_all.deb
EOF
}

download_entries() {
  mkdir -p "${DOWNLOAD_DIR}"

  while read -r url filename; do
    [[ -n "${url}" ]] || continue
    if [[ -f "${DOWNLOAD_DIR}/${filename}" ]]; then
      continue
    fi
    echo "Downloading ${filename}"
    curl -fsSL -o "${DOWNLOAD_DIR}/${filename}" "${url}"
  done < <(ui_entries)
}

collect_deb_paths() {
  while read -r _url filename; do
    [[ -n "${filename}" ]] || continue
    printf '%s\n' "${DOWNLOAD_DIR}/${filename}"
  done < <(ui_entries)
}
