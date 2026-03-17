#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
YES="${1:-}"
CONFIG_FILE="/etc/gdm3/custom.conf"

if [[ "${YES}" != "--yes" ]]; then
  cat <<EOF
This script forces the GDM greeter/login screen to use Xorg by setting:
  WaylandEnable=false

It requires sudo. To proceed, run:
  ${ROOT_DIR}/scripts/enable-gdm-xorg-greeter.sh --yes
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
text = path.read_text()
lines = text.splitlines()
out = []
in_daemon = False
done = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        if in_daemon and not done:
            out.append("WaylandEnable=false")
            done = True
        in_daemon = stripped == "[daemon]"
        out.append(line)
        continue

    if in_daemon and (stripped == "#WaylandEnable=false" or stripped.startswith("WaylandEnable=")):
        if not done:
            out.append("WaylandEnable=false")
            done = True
        continue

    out.append(line)

if not done:
    if not any(line.strip() == "[daemon]" for line in out):
        out.extend(["[daemon]", "WaylandEnable=false"])
    else:
        final = []
        in_daemon = False
        inserted = False
        for line in out:
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                if in_daemon and not inserted:
                    final.append("WaylandEnable=false")
                    inserted = True
                in_daemon = stripped == "[daemon]"
                final.append(line)
                continue
            final.append(line)
        if in_daemon and not inserted:
            final.append("WaylandEnable=false")
        out = final

path.write_text("\n".join(out) + "\n")
PY

echo "Updated ${CONFIG_FILE}"
echo "Backup: ${backup}"
echo "Next: sudo systemctl restart gdm3"
echo "Rollback: ${ROOT_DIR}/scripts/disable-gdm-xorg-greeter.sh --yes"
