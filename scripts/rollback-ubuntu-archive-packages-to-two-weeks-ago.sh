#!/usr/bin/env bash
set -euo pipefail

DAYS=14
SNAPSHOT_ID=""
YES=0
LIST_ONLY=0
CHUNK_SIZE=150

usage() {
  cat <<'EOF'
Find packages whose installed version changed in the last N days and roll them
back to the version available from the Ubuntu Snapshot Service at that cutoff.

Default behavior is simulation only.

Usage:
  ./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh
  ./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --days 7
  ./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --snapshot-id 20260302T000000Z
  ./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --list-only
  ./scripts/rollback-ubuntu-archive-packages-to-two-weeks-ago.sh --yes

Flags:
  --days N           Look back N days from now in apt history. Default: 14
  --snapshot-id ID   Use an explicit snapshot ID in YYYYMMDDTHHMMSSZ format
  --list-only        Only print the resolved rollback package/version targets
  --yes              Apply the rollback instead of only simulating it
  --help, -h         Show this help

Notes:
  - Only packages with version changes (Upgrade/Downgrade in apt history) are considered.
  - Only packages currently installed and backed by the Ubuntu archive are considered.
  - Local .deb installs and third-party repository packages are skipped.
  - Snapshot IDs are always UTC timestamps.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="${2:-}"
      shift 2
      ;;
    --snapshot-id)
      SNAPSHOT_ID="${2:-}"
      shift 2
      ;;
    --list-only)
      LIST_ONLY=1
      shift
      ;;
    --yes)
      YES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${SNAPSHOT_ID}" ]]; then
  SNAPSHOT_ID="$(date -u -d "${DAYS} days ago" +%Y%m%dT%H%M%SZ)"
fi

if [[ ! "${SNAPSHOT_ID}" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "Invalid snapshot ID: ${SNAPSHOT_ID}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
DIST_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME:-resolute}")"

VERSION_CHANGED_FILE="${TMP_DIR}/version-changed.txt"
INSTALLED_AFTER_CUTOFF_FILE="${TMP_DIR}/installed-after-cutoff.txt"
INSTALLED_FILE="${TMP_DIR}/installed.txt"
UBUNTU_BACKED_FILE="${TMP_DIR}/ubuntu-backed.txt"
SKIPPED_FILE="${TMP_DIR}/skipped.txt"
TARGETS_FILE="${TMP_DIR}/targets.tsv"
SPECS_FILE="${TMP_DIR}/target-specs.txt"
SNAPSHOT_HITS_FILE="${TMP_DIR}/snapshot-hits.txt"
REMOVE_TARGETS_FILE="${TMP_DIR}/remove-targets.tsv"
REMOVE_SPECS_FILE="${TMP_DIR}/remove-specs.txt"

echo "Scanning apt history for packages with version changes since snapshot ${SNAPSHOT_ID}..."

python3 - <<'PY' "${SNAPSHOT_ID}" > "${VERSION_CHANGED_FILE}"
import gzip
import glob
import sys
from datetime import datetime, timezone
from pathlib import Path

snapshot_id = sys.argv[1]
start = datetime.strptime(snapshot_id, '%Y%m%dT%H%M%SZ').replace(tzinfo=timezone.utc)
pkgs = set()

for path in sorted(glob.glob('/var/log/apt/history.log*')):
    raw = gzip.open(path, 'rt', errors='ignore').read() if path.endswith('.gz') else Path(path).read_text(errors='ignore')
    for block in [b.strip() for b in raw.split('\n\n') if b.strip()]:
        lines = block.splitlines()
        if not lines or not lines[0].startswith('Start-Date:'):
            continue
        when = datetime.strptime(lines[0].split('Start-Date: ')[1], '%Y-%m-%d  %H:%M:%S').replace(tzinfo=timezone.utc)
        if when < start:
            continue
        for line in lines[1:]:
            if not (line.startswith('Upgrade: ') or line.startswith('Downgrade: ')):
                continue
            _, rest = line.split(': ', 1)
            items = []
            depth = 0
            cur = ''
            for ch in rest:
                if ch == ',' and depth == 0:
                    if cur.strip():
                        items.append(cur.strip())
                    cur = ''
                    continue
                cur += ch
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            if cur.strip():
                items.append(cur.strip())
            for item in items:
                pkg, sep, _ = item.partition(' (')
                if sep:
                    pkgs.add(pkg.strip())

for pkg in sorted(pkgs):
    print(pkg)
PY

python3 - <<'PY' "${SNAPSHOT_ID}" > "${INSTALLED_AFTER_CUTOFF_FILE}"
import gzip
import glob
import sys
from datetime import datetime, timezone
from pathlib import Path

snapshot_id = sys.argv[1]
cutoff = datetime.strptime(snapshot_id, '%Y%m%dT%H%M%SZ').replace(tzinfo=timezone.utc)
pkgs = set()

for path in sorted(glob.glob('/var/log/apt/history.log*')):
    raw = gzip.open(path, 'rt', errors='ignore').read() if path.endswith('.gz') else Path(path).read_text(errors='ignore')
    for block in [b.strip() for b in raw.split('\n\n') if b.strip()]:
        lines = block.splitlines()
        if not lines or not lines[0].startswith('Start-Date:'):
            continue
        when = datetime.strptime(lines[0].split('Start-Date: ')[1], '%Y-%m-%d  %H:%M:%S').replace(tzinfo=timezone.utc)
        if when < cutoff:
            continue
        for line in lines[1:]:
            if not line.startswith('Install: '):
                continue
            _, rest = line.split(': ', 1)
            items = []
            depth = 0
            cur = ''
            for ch in rest:
                if ch == ',' and depth == 0:
                    if cur.strip():
                        items.append(cur.strip())
                    cur = ''
                    continue
                cur += ch
                if ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
            if cur.strip():
                items.append(cur.strip())
            for item in items:
                pkg, sep, _ = item.partition(' (')
                if sep:
                    pkgs.add(pkg.strip())

for pkg in sorted(pkgs):
    print(pkg)
PY

dpkg-query -W -f='${Package}:${Architecture}\n' | sort -u > "${INSTALLED_FILE}"

python3 - <<'PY' "${VERSION_CHANGED_FILE}" "${INSTALLED_AFTER_CUTOFF_FILE}" "${INSTALLED_FILE}" "${UBUNTU_BACKED_FILE}" "${SKIPPED_FILE}" "${TMP_DIR}/resolved-installed-after-cutoff.txt"
import subprocess
import sys

changed_path, installed_after_path, installed_path, backed_path, skipped_path, installed_after_resolved_path = sys.argv[1:]
with open(changed_path, 'r', encoding='utf-8') as fh:
    changed = [line.strip() for line in fh if line.strip()]
with open(installed_after_path, 'r', encoding='utf-8') as fh:
    installed_after = [line.strip() for line in fh if line.strip()]
with open(installed_path, 'r', encoding='utf-8') as fh:
    installed = {line.strip() for line in fh if line.strip()}
native_arch = subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip()

alias_map = {}
for pkg_arch in installed:
    pkg, arch = pkg_arch.rsplit(':', 1)
    alias_map[pkg_arch] = pkg_arch
    if arch == native_arch:
        alias_map.setdefault(pkg, pkg_arch)
    if arch == 'all':
        alias_map.setdefault(pkg, pkg_arch)
        alias_map.setdefault(f'{pkg}:{native_arch}', pkg_arch)

selected = []
skipped = []
for pkg in changed:
    resolved = alias_map.get(pkg)
    if resolved is None:
        skipped.append((pkg, 'not currently installed'))
        continue
    selected.append((pkg, resolved))

resolved_installed_after = []
for pkg in installed_after:
    resolved = alias_map.get(pkg)
    if resolved is not None:
        resolved_installed_after.append(resolved)

backed = []
for start in range(0, len(selected), 200):
    chunk_pairs = selected[start:start + 200]
    chunk = [resolved for _, resolved in chunk_pairs]
    if not chunk:
      continue
    policy = subprocess.check_output(['apt-cache', 'policy', *chunk], text=True, errors='ignore')
    current_pkg = None
    lines = []
    sections = {}
    for raw_line in policy.splitlines():
        if raw_line and not raw_line.startswith(' '):
            if current_pkg is not None:
                sections[current_pkg] = '\n'.join(lines)
            current_pkg = raw_line[:-1] if raw_line.endswith(':') else raw_line
            lines = [raw_line]
        elif current_pkg is not None:
            lines.append(raw_line)
    if current_pkg is not None:
        sections[current_pkg] = '\n'.join(lines)

    for original_pkg, resolved_pkg in chunk_pairs:
        section = sections.get(resolved_pkg, '')
        if not section and resolved_pkg.endswith(f':{native_arch}'):
            section = sections.get(resolved_pkg.rsplit(':', 1)[0], '')
        if not section and resolved_pkg.endswith(':all'):
            section = sections.get(resolved_pkg.rsplit(':', 1)[0], '')
        if not section:
            skipped.append((original_pkg, 'no apt policy output'))
        else:
            backed.append(resolved_pkg)

with open(backed_path, 'w', encoding='utf-8') as fh:
    for pkg in sorted(dict.fromkeys(backed)):
        fh.write(pkg + '\n')
with open(skipped_path, 'w', encoding='utf-8') as fh:
    for pkg, reason in skipped:
        fh.write(f'{pkg}\t{reason}\n')
with open(installed_after_resolved_path, 'w', encoding='utf-8') as fh:
    for pkg in sorted(dict.fromkeys(resolved_installed_after)):
        fh.write(pkg + '\n')
PY

mapfile -t UBUNTU_BACKED_PACKAGES < "${UBUNTU_BACKED_FILE}"
mapfile -t INSTALLED_AFTER_CUTOFF_PACKAGES < "${TMP_DIR}/resolved-installed-after-cutoff.txt"

mapfile -t LOCAL_REBUILT_PACKAGES < <(
  dpkg-query -W -f='${Package}:${Architecture}\t${Version}\n' \
    | awk -F '\t' '$2 ~ /\+ubuntu2604xorg/ { print $1 }' \
    | sort -u
)

if [[ "${#LOCAL_REBUILT_PACKAGES[@]}" -gt 0 ]]; then
  mapfile -t UBUNTU_BACKED_PACKAGES < <(
    printf '%s\n' "${UBUNTU_BACKED_PACKAGES[@]}" "${LOCAL_REBUILT_PACKAGES[@]}" | sort -u
  )
  printf '%s\n' "${UBUNTU_BACKED_PACKAGES[@]}" > "${UBUNTU_BACKED_FILE}"
fi

python3 - <<'PY' "${UBUNTU_BACKED_FILE}" "${INSTALLED_FILE}"
import sys
from pathlib import Path

backed_path = Path(sys.argv[1])
installed_path = Path(sys.argv[2])

backed = [line.strip() for line in backed_path.read_text(encoding='utf-8', errors='ignore').splitlines() if line.strip()]
installed = {line.strip() for line in installed_path.read_text(encoding='utf-8', errors='ignore').splitlines() if line.strip()}

extra = set()
for pkg_arch in backed:
    pkg, arch = pkg_arch.rsplit(':', 1)
    if not pkg.startswith('language-pack-') or pkg.endswith('-base'):
        continue
    base_pkg_arch = f'{pkg}-base:all'
    if base_pkg_arch in installed:
        extra.add(base_pkg_arch)

if extra:
    merged = sorted(set(backed) | extra)
    backed_path.write_text(''.join(f'{line}\n' for line in merged), encoding='utf-8')
PY

python3 - <<'PY' "${UBUNTU_BACKED_FILE}" "${INSTALLED_FILE}"
import subprocess
import sys
from pathlib import Path

backed_path = Path(sys.argv[1])
installed_path = Path(sys.argv[2])

backed = [line.strip() for line in backed_path.read_text(encoding='utf-8', errors='ignore').splitlines() if line.strip()]
installed = {line.strip() for line in installed_path.read_text(encoding='utf-8', errors='ignore').splitlines() if line.strip()}
native_arch = subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip()

alias_map = {}
for pkg_arch in installed:
    pkg, arch = pkg_arch.rsplit(':', 1)
    alias_map[pkg_arch] = pkg_arch
    if arch == native_arch:
        alias_map.setdefault(pkg, pkg_arch)
    if arch == 'all':
        alias_map.setdefault(pkg, pkg_arch)
        alias_map.setdefault(f'{pkg}:{native_arch}', pkg_arch)

dev_pkgs = []
for pkg_arch in installed:
    pkg, _ = pkg_arch.rsplit(':', 1)
    suffix = pkg.rsplit('-', 1)[-1] if '-' in pkg else ''
    if suffix in ('dev', 'dbg', 'common', 'data', 'doc', 'bin', 'plugins', 'base') or '-plugin-' in pkg:
        dev_pkgs.append(pkg)

extra = set()
for pkg in dev_pkgs:
    resolved = alias_map.get(pkg)
    if resolved is not None:
        extra.add(resolved)

dev_pkgs_list = sorted(set(dev_pkgs))
if dev_pkgs_list:
    try:
        out = subprocess.check_output(['apt-cache', 'depends'] + dev_pkgs_list, text=True, errors='ignore')
        for raw in out.splitlines():
            line = raw.strip()
            if not line.startswith('Depends:'):
                continue
            dep = line.split(':', 1)[1].strip()
            if not dep or dep.startswith('<'):
                continue
            resolved = alias_map.get(dep)
            if resolved is not None:
                extra.add(resolved)
    except subprocess.CalledProcessError:
        pass

if extra:
    merged = sorted(set(backed) | extra)
    backed_path.write_text(''.join(f'{line}\n' for line in merged), encoding='utf-8')
PY

if [[ "${#UBUNTU_BACKED_PACKAGES[@]}" == "0" ]]; then
  echo "No installed Ubuntu-archive packages with version changes were found in the last ${DAYS} days." >&2
  exit 1
fi

mapfile -t UBUNTU_BACKED_PACKAGES < "${UBUNTU_BACKED_FILE}"

echo "Resolving snapshot versions from Ubuntu Snapshot Service (${SNAPSHOT_ID})..."

python3 - <<'PY' "${UBUNTU_BACKED_FILE}" "${TARGETS_FILE}" "${SPECS_FILE}" "${SNAPSHOT_HITS_FILE}" "${SNAPSHOT_ID}" "${DIST_CODENAME}"
import http.client
import lzma
import subprocess
import sys
import time
import urllib.error
import urllib.request
from collections import defaultdict

backed_path, targets_path, specs_path, hits_path, snapshot_id, dist_codename = sys.argv[1:]
native_arch = subprocess.check_output(['dpkg', '--print-architecture'], text=True).strip()

with open(backed_path, 'r', encoding='utf-8') as fh:
    wanted = [line.strip() for line in fh if line.strip()]

installed_versions = {}
dpkg_out = subprocess.check_output(
    ['dpkg-query', '-W', '-f=${Package}:${Architecture}\t${Version}\n'],
    text=True,
)
for line in dpkg_out.splitlines():
    pkg_arch, version = line.split('\t', 1)
    installed_versions[pkg_arch] = version

def better_version(candidate: str, current: str | None) -> bool:
    if current is None:
        return True
    return subprocess.run(
        ['dpkg', '--compare-versions', candidate, 'gt', current],
        check=False,
    ).returncode == 0

targets = {}
wanted_names = defaultdict(list)
arches_needed = set()

for pkg_arch in wanted:
    if ':' in pkg_arch:
        pkg, arch = pkg_arch.rsplit(':', 1)
    else:
        pkg, arch = pkg_arch, native_arch
        pkg_arch = f'{pkg}:{arch}'
    wanted_names[pkg].append((pkg_arch, arch))
    if arch == 'i386':
        arches_needed.add('i386')
    else:
        arches_needed.add(native_arch)

components = ['main', 'restricted', 'universe', 'multiverse']
snapshot_hits = 0
resolved = set()

for component in components:
    for arch in sorted(arches_needed):
        url = f'https://snapshot.ubuntu.com/ubuntu/{snapshot_id}/dists/{dist_codename}/{component}/binary-{arch}/Packages.xz'
        payload = None
        for attempt in range(3):
            req = urllib.request.Request(url, headers={'User-Agent': 'ubuntu-2604-xorg/1.0'})
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    payload = resp.read()
                break
            except urllib.error.HTTPError as exc:
                if exc.code == 404:
                    payload = None
                    break
                if attempt == 2:
                    raise
            except (urllib.error.URLError, http.client.IncompleteRead, TimeoutError, EOFError):
                if attempt == 2:
                    payload = None
                else:
                    time.sleep(1 + attempt)
        if payload is None:
            continue

        try:
            text = lzma.decompress(payload).decode('utf-8', errors='ignore')
        except lzma.LZMAError:
            continue
        for block in text.split('\n\n'):
            if not block.startswith('Package: '):
                continue
            pkg_name = None
            pkg_arch_field = None
            pkg_version = None
            for line in block.splitlines():
                if line.startswith('Package: '):
                    pkg_name = line.split(': ', 1)[1]
                elif line.startswith('Architecture: '):
                    pkg_arch_field = line.split(': ', 1)[1]
                elif line.startswith('Version: '):
                    pkg_version = line.split(': ', 1)[1]
                if pkg_name and pkg_arch_field and pkg_version:
                    break
            if not pkg_name or not pkg_arch_field or not pkg_version:
                continue
            if pkg_name not in wanted_names:
                continue
            for pkg_arch, wanted_arch in wanted_names[pkg_name]:
                if wanted_arch == 'i386':
                    allowed = {'i386'}
                else:
                    allowed = {native_arch, 'all'}
                if pkg_arch_field not in allowed:
                    continue
                current = targets.get(pkg_arch)
                if better_version(pkg_version, current):
                    if pkg_arch not in resolved:
                        resolved.add(pkg_arch)
                    targets[pkg_arch] = pkg_version

snapshot_hits = len(resolved)

with open(targets_path, 'w', encoding='utf-8') as tfh, open(specs_path, 'w', encoding='utf-8') as sfh:
    for pkg_arch in sorted(targets):
        installed = installed_versions.get(pkg_arch)
        target = targets[pkg_arch]
        if installed is None or installed == '(none)' or installed == target:
            continue
        tfh.write(f'{pkg_arch}\t{installed}\t{target}\n')
        sfh.write(f'{pkg_arch}={target}\n')

with open(hits_path, 'w', encoding='utf-8') as hfh:
    hfh.write(f'{snapshot_hits}\n')
PY

python3 - <<'PY' "${INSTALLED_FILE}" "${UBUNTU_BACKED_FILE}" "${TMP_DIR}/resolved-installed-after-cutoff.txt" "${REMOVE_TARGETS_FILE}" "${REMOVE_SPECS_FILE}"
import sys

installed_path, backed_path, installed_after_path, remove_targets_path, remove_specs_path = sys.argv[1:]
installed_versions = {}
with open(installed_path, 'r', encoding='utf-8') as fh:
    for line in fh:
        pkg_arch = line.strip()
        if pkg_arch:
            installed_versions[pkg_arch] = None

dpkg_versions = {}
import subprocess
for line in subprocess.check_output(['dpkg-query', '-W', '-f=${Package}:${Architecture}\t${Version}\n'], text=True).splitlines():
    pkg_arch, version = line.split('\t', 1)
    dpkg_versions[pkg_arch] = version

with open(backed_path, 'r', encoding='utf-8') as fh:
    backed = {line.strip() for line in fh if line.strip()}
with open(installed_after_path, 'r', encoding='utf-8') as fh:
    installed_after = [line.strip() for line in fh if line.strip()]

remove_targets = []
remove_specs = []
for pkg_arch in installed_after:
    if pkg_arch not in backed:
        continue
    pkg_name = pkg_arch.rsplit(':', 1)[0] if ':' in pkg_arch else pkg_arch
    if not (pkg_name.startswith('linux-firmware-') and pkg_name != 'linux-firmware'):
        continue
    version = dpkg_versions.get(pkg_arch)
    if version is None:
        continue
    remove_targets.append((pkg_arch, version, '(remove)'))
    if ':' in pkg_arch:
        pkg, arch = pkg_arch.rsplit(':', 1)
        if arch == 'i386':
            remove_specs.append(f'{pkg}:i386-')
        else:
            remove_specs.append(f'{pkg}-')
    else:
        remove_specs.append(f'{pkg_arch}-')

with open(remove_targets_path, 'w', encoding='utf-8') as fh:
    for pkg_arch, version, action in sorted(dict.fromkeys(remove_targets)):
        fh.write(f'{pkg_arch}\t{version}\t{action}\n')
with open(remove_specs_path, 'w', encoding='utf-8') as fh:
    for spec in sorted(dict.fromkeys(remove_specs)):
        fh.write(f'{spec}\n')
PY

python3 - <<'PY' "${TARGETS_FILE}" "${SPECS_FILE}"
import sys
from pathlib import Path

targets_path = Path(sys.argv[1])
specs_path = Path(sys.argv[2])

seen_targets = set()
dedup_targets = []
if targets_path.exists():
    for line in targets_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if not line.strip():
            continue
        if line not in seen_targets:
            seen_targets.add(line)
            dedup_targets.append(line)
    targets_path.write_text(''.join(f'{line}\n' for line in dedup_targets), encoding='utf-8')

seen_specs = set()
dedup_specs = []
if specs_path.exists():
    for line in specs_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if not line.strip():
            continue
        if line not in seen_specs:
            seen_specs.add(line)
            dedup_specs.append(line)
    specs_path.write_text(''.join(f'{line}\n' for line in dedup_specs), encoding='utf-8')
PY

python3 - <<'PY' "${TARGETS_FILE}" "${SPECS_FILE}"
import sys
from pathlib import Path

targets_path = Path(sys.argv[1])
specs_path = Path(sys.argv[2])

if not targets_path.exists() or not specs_path.exists():
    raise SystemExit(0)

rows = []
for line in targets_path.read_text(encoding='utf-8', errors='ignore').splitlines():
    if not line.strip():
        continue
    pkg_arch, current, target = line.split('\t')
    rows.append((pkg_arch, current, target))

targets = {pkg_arch: target for pkg_arch, _, target in rows}

# Some snapshots publish a gnome-initial-setup build that breaks the
# simultaneously published gnome-shell-common version. Dropping
# gnome-initial-setup is safer than forcing an impossible downgrade set.
gis_pkg = 'gnome-initial-setup:amd64'
shell_common_pkg = 'gnome-shell-common:all'
if gis_pkg in targets and shell_common_pkg in targets:
    gis_target = targets[gis_pkg]
    shell_common_target = targets[shell_common_pkg]
    if gis_target.startswith('50') and shell_common_target.startswith('49'):
        rows = [row for row in rows if row[0] != gis_pkg]

targets_path.write_text(''.join(f'{pkg_arch}\t{current}\t{target}\n' for pkg_arch, current, target in rows), encoding='utf-8')
specs_path.write_text(''.join(f'{pkg_arch}={target}\n' for pkg_arch, _, target in rows), encoding='utf-8')
PY

python3 - <<'PY' "${TARGETS_FILE}" "${SPECS_FILE}" "${REMOVE_TARGETS_FILE}"
import sys
from pathlib import Path

targets_path = Path(sys.argv[1])
specs_path = Path(sys.argv[2])
remove_targets_path = Path(sys.argv[3])

remove_pkgs = set()
if remove_targets_path.exists():
    for line in remove_targets_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if not line.strip():
            continue
        pkg = line.split('\t', 1)[0]
        if pkg != 'package':
            remove_pkgs.add(pkg)

if remove_pkgs and targets_path.exists():
    kept_targets = []
    for line in targets_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if not line.strip():
            continue
        pkg = line.split('\t', 1)[0]
        if pkg not in remove_pkgs:
            kept_targets.append(line)
    targets_path.write_text(''.join(f'{line}\n' for line in kept_targets), encoding='utf-8')

if remove_pkgs and specs_path.exists():
    kept_specs = []
    for line in specs_path.read_text(encoding='utf-8', errors='ignore').splitlines():
        if not line.strip():
            continue
        pkg = line.split('=', 1)[0]
        if pkg not in remove_pkgs:
            kept_specs.append(line)
    specs_path.write_text(''.join(f'{line}\n' for line in kept_specs), encoding='utf-8')
PY

mapfile -t TARGET_SPECS < "${SPECS_FILE}"
mapfile -t REMOVE_SPECS < "${REMOVE_SPECS_FILE}" 2>/dev/null || true
SNAPSHOT_HITS=0
if [[ -s "${SNAPSHOT_HITS_FILE}" ]]; then
  while IFS= read -r count; do
    [[ -n "${count}" ]] || continue
    SNAPSHOT_HITS=$((SNAPSHOT_HITS + count))
  done < "${SNAPSHOT_HITS_FILE}"
fi

if [[ "${SNAPSHOT_HITS}" == "0" ]]; then
  NEAREST_HINT="$(
    python3 - <<'PY' "${SNAPSHOT_ID}" "${DIST_CODENAME}" 2>/dev/null || true
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

snapshot_id, dist_codename = sys.argv[1:]
base = datetime.strptime(snapshot_id, "%Y%m%dT%H%M%SZ").replace(tzinfo=timezone.utc)

def exists(ts):
    sid = ts.strftime("%Y%m%dT%H%M%SZ")
    url = f"https://snapshot.ubuntu.com/ubuntu/{sid}/dists/{dist_codename}/main/binary-amd64/Packages.xz"
    req = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "ubuntu-2604-xorg/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return 200 <= resp.status < 400
    except Exception:
        return False

for minutes in range(1, 24 * 60 + 1):
    earlier = base - timedelta(minutes=minutes)
    if exists(earlier):
        print(earlier.strftime("%Y%m%dT%H%M%SZ"))
        break
PY
  )"
  echo "Snapshot ${SNAPSHOT_ID} did not yield any package version entries from snapshot.ubuntu.com." >&2
  echo "Ubuntu snapshot IDs are not continuous timestamps; they must match a real published snapshot time." >&2
  if [[ -n "${NEAREST_HINT}" ]]; then
    echo "Nearest earlier usable snapshot found: ${NEAREST_HINT}" >&2
  else
    echo "Try a known-good published snapshot ID such as 20260214T154336Z." >&2
  fi
  exit 1
fi

echo
echo "Snapshot ID: ${SNAPSHOT_ID}"
echo "Version-changed packages since snapshot: $(wc -l < "${VERSION_CHANGED_FILE}")"
echo "Installed Ubuntu-archive candidates: ${#UBUNTU_BACKED_PACKAGES[@]}"
echo "Packages with a different snapshot version: ${#TARGET_SPECS[@]}"
echo "Packages to remove because they were installed after the snapshot: ${#REMOVE_SPECS[@]}"
echo "Skipped packages: $(wc -l < "${SKIPPED_FILE}" 2>/dev/null || echo 0)"
echo

if [[ "${LIST_ONLY}" == "1" ]]; then
  echo "Rollback targets:"
  if [[ -s "${TARGETS_FILE}" ]]; then
    printf 'package\tcurrent_version\tsnapshot_version\n'
    cat "${TARGETS_FILE}"
  else
    echo "(none)"
  fi
  echo
  echo "Removal targets:"
  if [[ -s "${REMOVE_TARGETS_FILE}" ]]; then
    printf 'package\tcurrent_version\taction\n'
    cat "${REMOVE_TARGETS_FILE}"
  else
    echo "(none)"
  fi
  echo
  echo "Skipped packages:"
  sed -n '1,999p' "${SKIPPED_FILE}" 2>/dev/null || true
  exit 0
fi

if [[ "${#TARGET_SPECS[@]}" == "0" && "${#REMOVE_SPECS[@]}" == "0" ]]; then
  echo "No package versions differ from the selected snapshot." >&2
  exit 0
fi

echo "Resolved rollback targets:"
printf '  %s\n' "${TARGET_SPECS[@]}"
echo
if [[ "${#REMOVE_SPECS[@]}" -gt 0 ]]; then
  echo "Resolved removal targets:"
  if [[ -s "${REMOVE_TARGETS_FILE}" ]]; then
    awk -F '\t' '{print "  remove " $1 " (" $2 ")"}' "${REMOVE_TARGETS_FILE}"
  else
    printf '  %s\n' "${REMOVE_SPECS[@]}"
  fi
  echo
fi

if [[ "${YES}" != "1" ]]; then
  echo "Simulation only. Use --yes to apply."
  sudo apt -s install --allow-downgrades --update --snapshot "${SNAPSHOT_ID}" "${TARGET_SPECS[@]}" "${REMOVE_SPECS[@]}"
  exit 0
fi

echo "Applying rollback to snapshot versions..."
sudo apt install -y --allow-downgrades --update --snapshot "${SNAPSHOT_ID}" "${TARGET_SPECS[@]}" "${REMOVE_SPECS[@]}"
