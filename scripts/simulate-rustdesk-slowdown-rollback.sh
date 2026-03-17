#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for arg in "$@"; do
  case "${arg}" in
    --help|-h)
      cat <<EOF
Simulate the RustDesk slowdown rollback with apt.

Default:
  Simulates a Mesa rollback to 25.2.8-2ubuntu1.
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
mapfile -t debs < <(collect_deb_paths 0)

echo "Simulating rollback/install with apt:"
printf '  %s\n' "${debs[@]}"
echo

apt-get -s install --allow-downgrades --reinstall "${debs[@]}"
