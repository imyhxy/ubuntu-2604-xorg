#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script removes the locally-installed ubuntu-xorg-session package (sudo required).
To proceed, run:
  ${ROOT_DIR}/scripts/remove-ubuntu-xorg-session-deb.sh --yes
EOF
  exit 0
fi

if dpkg-query -W -f='${Status}\n' ubuntu-xorg-session 2>/dev/null | grep -q "install ok installed"; then
  sudo apt remove -y ubuntu-xorg-session || sudo dpkg -r ubuntu-xorg-session
else
  echo "ubuntu-xorg-session is not installed; nothing to remove."
fi

