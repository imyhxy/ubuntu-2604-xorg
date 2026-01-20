#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
YES="${1:-}"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script installs the local ubuntu-xorg-session .deb from:
  ${OUT_DIR}

It requires sudo. To proceed, run:
  ${ROOT_DIR}/scripts/install-ubuntu-xorg-session-deb.sh --yes
EOF
  exit 0
fi

shopt -s nullglob
debs=( "${OUT_DIR}"/ubuntu-xorg-session_*_all.deb )

if (( ${#debs[@]} == 0 )); then
  echo "ERROR: No ubuntu-xorg-session_*_all.deb found in ${OUT_DIR}."
  echo "Run: ${ROOT_DIR}/scripts/build-ubuntu-xorg-session-deb.sh"
  exit 1
fi

latest="$(printf '%s\n' "${debs[@]}" | sort -V | tail -n 1)"

sudo dpkg -i "${latest}" || true
sudo apt -f install -y

echo "Installed: ubuntu-xorg-session"
echo "Next: log out and check that “Ubuntu on Xorg” appears in GDM."

