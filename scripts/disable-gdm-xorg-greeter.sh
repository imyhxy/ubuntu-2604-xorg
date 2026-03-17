#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"
CONFIG_FILE="/etc/gdm3/custom.conf"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script re-enables the default GDM Wayland greeter by commenting out:
  WaylandEnable=false

It requires sudo. To proceed, run:
  ${ROOT_DIR}/scripts/disable-gdm-xorg-greeter.sh --yes
EOF
  exit 0
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "ERROR: ${CONFIG_FILE} not found."
  exit 1
fi

backup="${CONFIG_FILE}.ubuntu-2604-xorg.bak"
sudo cp -a "${CONFIG_FILE}" "${backup}"

sudo python3 - <<'PY'
from pathlib import Path

path = Path("/etc/gdm3/custom.conf")
lines = path.read_text().splitlines()
out = []
in_daemon = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        in_daemon = stripped == "[daemon]"
        out.append(line)
        continue
    if in_daemon and stripped == "WaylandEnable=false":
        out.append("#WaylandEnable=false")
        continue
    out.append(line)

path.write_text("\n".join(out) + "\n")
PY

echo "Updated ${CONFIG_FILE}"
echo "Backup: ${backup}"
echo "Next: sudo systemctl restart gdm3"
echo "Rollback: uncomment WaylandEnable=false again or run ${ROOT_DIR}/scripts/enable-gdm-xorg-greeter.sh --yes"
