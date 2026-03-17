#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Simulate restoring the exact login/session stack that was present immediately
before the 2026-03-16 09:09:48 apt dist-upgrade.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=./preupdate-session-stack-packages.sh
source "${ROOT_DIR}/scripts/preupdate-session-stack-packages.sh"

download_entries
"${ROOT_DIR}/scripts/download-gnome49-downgrade-debs.sh"
mapfile -t debs < <(collect_deb_paths)

echo "Simulating pre-update session stack restore with apt:"
printf '  %s\n' "${debs[@]}"
echo
echo "Versioned packages restored from the repository:"
echo "  gnome-settings-daemon=50~beta-0ubuntu2"
echo "  gnome-settings-daemon-common=50~beta-0ubuntu2"
echo

apt-get -s install --allow-downgrades --reinstall \
  "${debs[@]}" \
  gnome-settings-daemon=50~beta-0ubuntu2 \
  gnome-settings-daemon-common=50~beta-0ubuntu2
