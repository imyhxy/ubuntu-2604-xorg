#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Download the package files used by the RustDesk slowdown rollback workflow.

Default:
  Downloads the exact Mesa 25.2.8-2ubuntu1 packages that were upgraded to
  26.0.1-2ubuntu1 on 2026-03-16.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: ${arg}" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=./rustdesk-slowdown-rollback-packages.sh
source "${ROOT_DIR}/scripts/rustdesk-slowdown-rollback-packages.sh"

download_entries 0

echo
echo "Downloaded rollback packages into ${DOWNLOAD_DIR}"
