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
gir_pkg="$(latest_pkg '^gir1\.2-mutter-[0-9]+$')"

echo
echo "Installed (host):"
dpkg -l | awk -v libmutter_pkg="${libmutter_pkg}" -v gir_pkg="${gir_pkg}" '/^ii/ && ($2 ~ /^(gdm3|gnome-shell|gnome-session|mutter|mutter-common|mutter-common-bin)(:.*)?$/ || $2 == libmutter_pkg || $2 == gir_pkg) { print "  " $2 " " $3 }'

gnome_shell_version="$(dpkg-query -W -f='${Version}\n' gnome-shell 2>/dev/null || true)"
if [[ -n "${gnome_shell_version}" ]] && dpkg --compare-versions "${gnome_shell_version}" ge "50~"; then
  echo
  echo "ERROR: GNOME Shell ${gnome_shell_version} is installed."
  echo "This repo's working Xorg solution is for the GNOME 49 / mutter 49 stack."
  echo "GNOME 49 disabled X11 sessions by default, and upstream planned removal for GNOME 50."
  echo "On the current GNOME 50 packages, the old native Ubuntu Xorg session path no longer works with this repo's approach."
  echo
  echo "Do not run run-all.sh on this system state."
  echo "Use scripts/simulate-gnome49-downgrade.sh to preview the supported downgrade,"
  echo "or scripts/install-gnome49-downgrade.sh --yes to move this machine back to the GNOME 49-compatible stack."
  exit 1
fi

echo
echo "Done."
