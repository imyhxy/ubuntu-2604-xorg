#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES=0

for arg in "$@"; do
  case "${arg}" in
    --yes)
      YES=1
      ;;
    --help|-h)
      cat <<EOF
Install the RustDesk slowdown rollback packages.

Default:
  Downgrades Mesa back to 25.2.8-2ubuntu1.
  --yes              Required to perform the install.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

if [[ "${YES}" != "1" ]]; then
  cat <<EOF
This script installs rollback packages on the host and requires sudo.

Preview first:
  ${ROOT_DIR}/scripts/simulate-rustdesk-slowdown-rollback.sh

To proceed with Mesa only:
  ${ROOT_DIR}/scripts/install-rustdesk-slowdown-rollback.sh --yes
EOF
  exit 0
fi

# shellcheck source=./rustdesk-slowdown-rollback-packages.sh
source "${ROOT_DIR}/scripts/rustdesk-slowdown-rollback-packages.sh"

"${ROOT_DIR}/scripts/simulate-rustdesk-slowdown-rollback.sh"

mapfile -t debs < <(collect_deb_paths 0)

sudo apt install -y --allow-downgrades --reinstall "${debs[@]}"

echo
echo "Rollback install complete."
echo "Next:"
echo "  1. Log out and back in"
echo "  2. Re-test the RustDesk tray/UI latency"
echo "  3. If needed, reboot once so the downgraded Mesa stack is used everywhere"
