#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"

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

ver_lib="$(repo_version libmutter-17-0)"
ver_common="$(repo_version mutter-common)"
ver_common_bin="$(repo_version mutter-common-bin)"
ver_gir="$(repo_version gir1.2-mutter-17)"

if [[ -z "${ver_lib}" || -z "${ver_common}" || -z "${ver_common_bin}" || -z "${ver_gir}" ]]; then
  echo "ERROR: Could not determine repo versions via apt-cache policy."
  echo "Run manually:"
  echo "  apt-cache policy libmutter-17-0 mutter-common mutter-common-bin gir1.2-mutter-17 | sed -n '1,120p'"
  exit 1
fi

echo "Downgrading to repo versions:"
echo "  libmutter-17-0=${ver_lib}"
echo "  mutter-common=${ver_common}"
echo "  mutter-common-bin=${ver_common_bin}"
echo "  gir1.2-mutter-17=${ver_gir}"

sudo apt install -y --allow-downgrades --reinstall \
  "libmutter-17-0=${ver_lib}" \
  "mutter-common=${ver_common}" \
  "mutter-common-bin=${ver_common_bin}" \
  "gir1.2-mutter-17=${ver_gir}"

echo "Rollback complete. Prefer logging in with Wayland (“Ubuntu”) first."
