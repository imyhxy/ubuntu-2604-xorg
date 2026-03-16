#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"

latest_pkg() {
  local pattern="$1"
  apt-cache pkgnames | rg "${pattern}" | sort -V | tail -n 1
}

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script removes the session files and downgrades mutter packages back to the Ubuntu repo versions.

It requires sudo. To proceed, run:
  ${ROOT_DIR}/scripts/rollback.sh --yes
EOF
  exit 0
fi

echo "Removing session files..."
if [[ -x "${ROOT_DIR}/scripts/remove-ubuntu-xorg-session-deb.sh" ]]; then
  "${ROOT_DIR}/scripts/remove-ubuntu-xorg-session-deb.sh" --yes
fi

safe_rm_if_unowned_or_ours() {
  local path="$1"
  if [[ ! -e "${path}" ]]; then
    return 0
  fi

  local owners
  owners="$(dpkg -S "${path}" 2>/dev/null | awk -F: "{print \\$1}" | sort -u || true)"

  # If dpkg doesn't know about this file, it was likely manually installed.
  if [[ -z "${owners}" ]]; then
    sudo rm -f "${path}"
    return 0
  fi

  # If the only owner is ubuntu-xorg-session, allow removal.
  if [[ "${owners}" == "ubuntu-xorg-session" ]]; then
    sudo rm -f "${path}"
    return 0
  fi

  echo "Skipping removal of ${path} (owned by: ${owners})"
}

# If an older revision of this repo installed session files directly,
# remove those too to keep rollback deterministic.
safe_rm_if_unowned_or_ours /usr/share/xsessions/ubuntu-xorg.desktop
sudo rm -f /etc/systemd/user/gnome-session-x11@.target
sudo rm -f /etc/systemd/user/gnome-session-x11.target
sudo rm -f /etc/systemd/user/org.gnome.Shell@x11.service
sudo rm -f /etc/systemd/user/org.gnome.Shell.target.d/ubuntu-2604-xorg.conf
sudo rm -f /etc/systemd/user/org.gnome.Shell.target.d/ubuntu-xorg-session.conf

repo_version() {
  local pkg="$1"
  apt-cache policy "$pkg" | awk '
    $1=="Version" && $2=="table:" {in=1; next}
    in && $1=="***" {next}
    in && $1 ~ /^[0-9]/ {print $1; exit}
  '
}

libmutter_pkg="$(latest_pkg '^libmutter-[0-9]+-0$')"
gir_pkg="$(latest_pkg '^gir1\.2-mutter-[0-9]+$')"

if [[ -z "${libmutter_pkg}" || -z "${gir_pkg}" ]]; then
  echo "ERROR: Could not determine the current mutter ABI package names."
  exit 1
fi

pkg_args=()
add_repo_pkg() {
  local pkg="$1"
  local ver
  ver="$(repo_version "${pkg}")"
  if [[ -n "${ver}" ]]; then
    pkg_args+=( "${pkg}=${ver}" )
  fi
}

add_repo_pkg gdm3
add_repo_pkg libgdm1
add_repo_pkg gir1.2-gdm-1.0
add_repo_pkg gnome-session
add_repo_pkg gnome-session-bin
add_repo_pkg gnome-session-common
add_repo_pkg gnome-shell
add_repo_pkg gnome-shell-common
add_repo_pkg gnome-shell-ubuntu-extensions
add_repo_pkg gnome-shell-extension-prefs
add_repo_pkg gnome-initial-setup
add_repo_pkg gnome-remote-desktop
add_repo_pkg ubuntu-session
add_repo_pkg ubuntu-desktop
add_repo_pkg ubuntu-desktop-minimal
add_repo_pkg mutter-common
add_repo_pkg mutter-common-bin
add_repo_pkg "${libmutter_pkg}"
add_repo_pkg "${gir_pkg}"

if (( ${#pkg_args[@]} == 0 )); then
  echo "ERROR: Could not determine repo versions via apt-cache policy."
  exit 1
fi

echo "Restoring repo versions:"
printf '  %s\n' "${pkg_args[@]}"

sudo apt install -y --allow-downgrades --reinstall \
  "${pkg_args[@]}"

echo "Rollback complete. Prefer logging in with Wayland (“Ubuntu”) first."
