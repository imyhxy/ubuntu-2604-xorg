#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"

"${ROOT_DIR}/scripts/check.sh"
echo
"${ROOT_DIR}/scripts/build-ubuntu-xorg-session-deb.sh"
echo
"${ROOT_DIR}/scripts/install-ubuntu-xorg-session-deb.sh" "${YES}"
echo
"${ROOT_DIR}/scripts/build-mutter-x11-debs.sh"
echo
"${ROOT_DIR}/scripts/install-mutter-x11-debs.sh" "${YES}"

echo
echo "Done. Log out and choose “Ubuntu on Xorg”."
