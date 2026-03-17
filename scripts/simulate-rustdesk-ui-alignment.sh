#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Simulate the RustDesk GTK/GNOME helper alignment rollback with apt.

This flow downgrades:
  - libgtk-4-1
  - libgtk-4-common
  - gir1.2-gtk-4.0
  - gnome-settings-daemon
  - gnome-settings-daemon-common
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
mapfile -t debs < <(collect_deb_paths)

echo "Simulating UI-alignment install with apt:"
printf '  %s\n' "${debs[@]}"
echo

cat <<'EOF'
Note:
  This path intentionally does not downgrade xdg-desktop-portal-gnome.
  Current GTK 4 packages in Resolute declare:
    Breaks: xdg-desktop-portal-gnome (< 50~)
  so a full portal rollback does not solve cleanly on this host.

EOF

apt-get -s install --allow-downgrades --reinstall "${debs[@]}"
