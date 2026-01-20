#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
WORK_DIR="${ROOT_DIR}/work"

PKG_NAME="ubuntu-xorg-session"
PKG_VERSION="${PKG_VERSION:-1.0}"
PKG_ARCH="all"

if ! command -v dpkg-deb >/dev/null 2>&1; then
  echo "ERROR: dpkg-deb not found. Please install: sudo apt install -y dpkg"
  exit 1
fi

mkdir -p "${OUT_DIR}" "${WORK_DIR}"

PKG_ROOT="${WORK_DIR}/${PKG_NAME}_${PKG_VERSION}"
DEBIAN_DIR="${PKG_ROOT}/DEBIAN"

rm -rf "${PKG_ROOT}"
mkdir -p "${DEBIAN_DIR}"

cat > "${DEBIAN_DIR}/control" <<EOF
Package: ${PKG_NAME}
Version: ${PKG_VERSION}
Section: admin
Priority: optional
Architecture: ${PKG_ARCH}
Maintainer: ubuntu-2604-xorg <noreply@example.invalid>
Depends: gdm3, gnome-session-bin, gnome-shell
Description: Add an Ubuntu Xorg session entry for GDM (safe)
 Installs an "Ubuntu on Xorg" session entry and the systemd user units needed
 to start GNOME on X11 on Ubuntu 26.04.
EOF

install -D -m 0644 \
  "${ROOT_DIR}/files/ubuntu-xorg.desktop" \
  "${PKG_ROOT}/usr/share/xsessions/ubuntu-xorg.desktop"

install -D -m 0644 \
  "${ROOT_DIR}/files/systemd-user/gnome-session-x11@.target" \
  "${PKG_ROOT}/usr/lib/systemd/user/gnome-session-x11@.target"
install -D -m 0644 \
  "${ROOT_DIR}/files/systemd-user/gnome-session-x11.target" \
  "${PKG_ROOT}/usr/lib/systemd/user/gnome-session-x11.target"
install -D -m 0644 \
  "${ROOT_DIR}/files/systemd-user/org.gnome.Shell@x11.service" \
  "${PKG_ROOT}/usr/lib/systemd/user/org.gnome.Shell@x11.service"
install -D -m 0644 \
  "${ROOT_DIR}/files/systemd-user/org.gnome.Shell.target.d/ubuntu-xorg-session.conf" \
  "${PKG_ROOT}/usr/lib/systemd/user/org.gnome.Shell.target.d/ubuntu-xorg-session.conf"

OUT_DEB="${OUT_DIR}/${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}.deb"
dpkg-deb --root-owner-group --build "${PKG_ROOT}" "${OUT_DEB}" >/dev/null

echo "Built: ${OUT_DEB}"
echo "Next: ${ROOT_DIR}/scripts/install-ubuntu-xorg-session-deb.sh --yes"

