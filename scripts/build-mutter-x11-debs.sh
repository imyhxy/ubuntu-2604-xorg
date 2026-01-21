#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
WORK_DIR="${ROOT_DIR}/work"

UBUNTU_IMAGE="${UBUNTU_IMAGE:-ubuntu:devel}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

mkdir -p "${OUT_DIR}" "${WORK_DIR}"

echo "Building mutter in Docker image: ${UBUNTU_IMAGE}"
echo "Output dir: ${OUT_DIR}"
echo "Work dir: ${WORK_DIR}"
echo

docker run --rm \
  -v "${ROOT_DIR}:/repo:rw" \
  -w /repo/work \
  -e "HOST_UID=${HOST_UID}" \
  -e "HOST_GID=${HOST_GID}" \
  "${UBUNTU_IMAGE}" \
  bash -lc '
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends devscripts equivs ca-certificates quilt patch

# Enable deb-src inside the container (does not affect host).
if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
  if ! grep -qE "^Types:.*\\bdeb-src\\b" /etc/apt/sources.list.d/ubuntu.sources; then
    sed -i "s/^Types: deb$/Types: deb deb-src/" /etc/apt/sources.list.d/ubuntu.sources
  fi
fi
apt-get update

rm -rf mutter-* *.dsc *.debian.tar.* *.orig.tar.*
apt-get source mutter

MUTTER_DIR="$(find . -maxdepth 1 -type d -name "mutter-*" | head -n 1)"
test -n "${MUTTER_DIR}"
cd "${MUTTER_DIR}"

patch -p1 < /repo/patches/mutter/0001-enable-x11-backend.patch

# Add a local version suffix for clarity (e.g. 49.2-1ubuntu1+ubuntu2604xorg1).
if ! dpkg-parsechangelog -S Version | grep -q ubuntu2604xorg; then
  dch --local "+ubuntu2604xorg" --distribution "$(dpkg-parsechangelog -S Distribution)" "Enable mutter X11 backend for Ubuntu 26.04 Xorg session."
fi

mk-build-deps --install --tool "apt-get -y --no-install-recommends" --remove debian/control

export DEB_BUILD_OPTIONS=nocheck
dpkg-buildpackage -us -uc -b

cd ..

cp -v libmutter-17-0_*_amd64.deb /repo/out/
cp -v mutter-common_*_all.deb /repo/out/
cp -v mutter-common-bin_*_amd64.deb /repo/out/
cp -v gir1.2-mutter-17_*_amd64.deb /repo/out/

# Make outputs editable by the host user.
chown -R "${HOST_UID}:${HOST_GID}" /repo/out

# Avoid leaving root-owned artifacts in the shared workdir on the host.
chown -R "${HOST_UID}:${HOST_GID}" /repo/work
'

echo
echo "Build complete."
echo "Next: ./scripts/install-mutter-x11-debs.sh --yes"
