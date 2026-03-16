#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

latest_pkg() {
  local pattern="$1"
  apt-cache pkgnames | rg "${pattern}" | sort -V | tail -n 1
}

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

libmutter_pkg="$(latest_pkg '^libmutter-[0-9]+-0$')"
gir_pkg="$(latest_pkg '^gir1\\.2-mutter-[0-9]+$')"

echo
echo "Installed (host):"
dpkg -l | awk -v libmutter_pkg="${libmutter_pkg}" -v gir_pkg="${gir_pkg}" '
  /^ii/ && (
    $2 ~ /^(gdm3|gnome-shell|gnome-session|mutter|mutter-common|mutter-common-bin)(:.*)?$/ ||
    $2 == libmutter_pkg ||
    $2 == gir_pkg
  ) {
    print "  " $2 " " $3
  }
'

echo
echo "Done."
