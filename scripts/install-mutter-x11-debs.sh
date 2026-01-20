#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
YES="${1:-}"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script installs mutter runtime .debs from:
  ${OUT_DIR}

It requires sudo. To proceed, run:
  ${ROOT_DIR}/scripts/install-mutter-x11-debs.sh --yes
EOF
  exit 0
fi

shopt -s nullglob

libmutter=( "${OUT_DIR}"/libmutter-17-0_*ubuntu2604xorg*_amd64.deb )
mutter_common=( "${OUT_DIR}"/mutter-common_*ubuntu2604xorg*_all.deb )
mutter_common_bin=( "${OUT_DIR}"/mutter-common-bin_*ubuntu2604xorg*_amd64.deb )
gir=( "${OUT_DIR}"/gir1.2-mutter-17_*ubuntu2604xorg*_amd64.deb )

if (( ${#libmutter[@]} == 0 || ${#mutter_common[@]} == 0 || ${#mutter_common_bin[@]} == 0 || ${#gir[@]} == 0 )); then
  echo "ERROR: Missing expected ubuntu2604xorg .debs in ${OUT_DIR}."
  echo "Run: ${ROOT_DIR}/scripts/build-mutter-x11-debs.sh"
  exit 1
fi

sudo dpkg -i "${libmutter[-1]}" "${mutter_common[-1]}" "${mutter_common_bin[-1]}" "${gir[-1]}" || true
sudo apt -f install -y

echo "Installed mutter packages."
echo "Next: log out and choose “Ubuntu on Xorg”."

