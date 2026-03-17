#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Download the GTK/GNOME helper packages used by the RustDesk UI alignment flow.

This downloads:
  - GTK 4 packages from the pre-upgrade Resolute 4.21.5+ds-5 set
  - gnome-settings-daemon 49.0-1ubuntu3 packages

It intentionally does not touch xdg-desktop-portal-gnome because current
GTK 4 packages in Resolute declare Breaks against portal versions < 50.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=./rustdesk-ui-alignment-packages.sh
source "${ROOT_DIR}/scripts/rustdesk-ui-alignment-packages.sh"

download_entries

echo
echo "Downloaded UI-alignment packages into ${DOWNLOAD_DIR}"
