#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Download the exact login/session package set that was installed just before
the 2026-03-16 09:09:48 apt dist-upgrade.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=./preupdate-session-stack-packages.sh
source "${ROOT_DIR}/scripts/preupdate-session-stack-packages.sh"

download_entries
"${ROOT_DIR}/scripts/download-gnome49-downgrade-debs.sh"

echo
echo "Downloaded pre-update session stack packages into ${DOWNLOAD_DIR}"
