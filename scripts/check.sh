#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Repo: ${ROOT_DIR}"
echo

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "OS: ${PRETTY_NAME:-unknown}"
  echo "VERSION_ID: ${VERSION_ID:-unknown}"
  echo "VERSION_CODENAME: ${VERSION_CODENAME:-unknown}"
else
  echo "ERROR: /etc/os-release not readable"
  exit 1
fi

echo
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found in PATH"
  exit 1
fi
echo "docker: OK"

if ! docker ps >/dev/null 2>&1; then
  echo "ERROR: docker ps failed. Is docker running? Are you in the docker group?"
  exit 1
fi
echo "docker daemon access: OK"

echo
echo "Installed (host):"
dpkg -l | awk '/^ii/ && ($2 ~ /^(gdm3|gnome-shell|gnome-session|mutter|mutter-common|mutter-common-bin|gir1.2-mutter-17|libmutter-17-0)(:.*)?$/) {print "  " $2 " " $3}'

echo
echo "Done."
