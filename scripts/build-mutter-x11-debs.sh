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

rm -rf mutter-* *.dsc *.debian.tar.* *.orig.tar.* *.buildinfo *.changes *.deb *.ddeb
apt-get source mutter

MUTTER_DIR="$(find . -maxdepth 1 -type d -name "mutter-*" | head -n 1)"
test -n "${MUTTER_DIR}"
cd "${MUTTER_DIR}"

if patch --forward --batch -p1 < /repo/patches/mutter/0001-enable-x11-backend.patch; then
  echo "Applied local mutter packaging patch."
elif grep -q -- "-Dx11=true" debian/rules; then
  echo "ERROR: Local mutter patch failed and debian/rules still contains -Dx11=true." >&2
  exit 1
else
  echo "Local mutter patch not needed for this source snapshot."
fi

# Add a local version suffix for clarity (e.g. 50~beta-2ubuntu4+ubuntu2604xorg1).
if ! dpkg-parsechangelog -S Version | grep -q ubuntu2604xorg; then
  dch --local "+ubuntu2604xorg" --distribution "$(dpkg-parsechangelog -S Distribution)" "Fix mutter packaging for Ubuntu 26.04 Xorg session build."
fi

PACKAGE_VERSION="$(dpkg-parsechangelog -S Version)"

mk-build-deps --install --tool "apt-get -y --no-install-recommends" --remove debian/control

export DEB_BUILD_OPTIONS=nocheck
dpkg-buildpackage -us -uc -b

cd ..

cp -v libmutter-*-0_"${PACKAGE_VERSION}"_amd64.deb /repo/out/
cp -v mutter-common_"${PACKAGE_VERSION}"_all.deb /repo/out/
cp -v mutter-common-bin_"${PACKAGE_VERSION}"_amd64.deb /repo/out/
cp -v gir1.2-mutter-*_"${PACKAGE_VERSION}"_amd64.deb /repo/out/

# Make outputs editable by the host user.
chown -R "${HOST_UID}:${HOST_GID}" /repo/out

# Avoid leaving root-owned artifacts in the shared workdir on the host.
chown -R "${HOST_UID}:${HOST_GID}" /repo/work
'

echo
echo "Build complete."
echo "Next: ./scripts/install-mutter-x11-debs.sh --yes"
