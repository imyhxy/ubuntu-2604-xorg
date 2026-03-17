#!/usr/bin/env bash
set -euo pipefail

PACKAGE="mutter-common"
DIST="resolute"
ARCH="amd64"
FROM_TS="2026-02-14T00:00:00Z"
TO_TS=""
TARGET_VERSION_PREFIX="49.2-"
RESOLUTION_SECONDS=60

usage() {
  cat <<'EOF'
Find the last Ubuntu snapshot timestamp where mutter-common still matches the
GNOME 49 / mutter 49.2 line, using direct snapshot metadata fetches and a
binary search.

Usage:
  ./scripts/find-last-mutter-49-snapshot.sh
  ./scripts/find-last-mutter-49-snapshot.sh --from 2026-02-14T00:00:00Z --to 2026-03-16T00:00:00Z
  ./scripts/find-last-mutter-49-snapshot.sh --package mutter-common --target-prefix 49.2-

Flags:
  --from ISO8601        Inclusive UTC lower bound. Default: 2026-02-14T00:00:00Z
  --to ISO8601          Inclusive UTC upper bound. Default: current UTC time
  --package NAME        Package to probe. Default: mutter-common
  --dist NAME           Ubuntu codename. Default: resolute
  --arch NAME           Architecture. Default: amd64
  --target-prefix STR   Version prefix to consider a match. Default: 49.2-
  --resolution SEC      Stop when range is <= this many seconds. Default: 60
  --help, -h            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      FROM_TS="${2:-}"
      shift 2
      ;;
    --to)
      TO_TS="${2:-}"
      shift 2
      ;;
    --package)
      PACKAGE="${2:-}"
      shift 2
      ;;
    --dist)
      DIST="${2:-}"
      shift 2
      ;;
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    --target-prefix)
      TARGET_VERSION_PREFIX="${2:-}"
      shift 2
      ;;
    --resolution)
      RESOLUTION_SECONDS="${2:-}"
      shift 2
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

if [[ -z "${TO_TS}" ]]; then
  TO_TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

python3 - <<'PY' "${FROM_TS}" "${TO_TS}" "${PACKAGE}" "${DIST}" "${ARCH}" "${TARGET_VERSION_PREFIX}" "${RESOLUTION_SECONDS}"
import lzma
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

from_ts, to_ts, package, dist, arch, prefix, resolution = sys.argv[1:]
resolution = int(resolution)

def parse_ts(value: str) -> int:
    return int(datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc).timestamp())

def fmt_snapshot(ts: int) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y%m%dT%H%M%SZ")

def fmt_iso(ts: int) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

cache: dict[int, str | None] = {}

def fetch_version(ts: int) -> str | None:
    if ts in cache:
      return cache[ts]
    sid = fmt_snapshot(ts)
    url = f"https://snapshot.ubuntu.com/ubuntu/{sid}/dists/{dist}/main/binary-{arch}/Packages.xz"
    req = urllib.request.Request(url, headers={"User-Agent": "ubuntu-2604-xorg/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = resp.read()
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            cache[ts] = None
            return None
        raise
    except urllib.error.URLError:
        cache[ts] = None
        return None
    text = lzma.decompress(payload).decode("utf-8", errors="ignore")
    needle = f"Package: {package}\n"
    version = None
    for block in text.split("\n\n"):
        if block.startswith(needle):
            for line in block.splitlines():
                if line.startswith("Version: "):
                    version = line.split(": ", 1)[1]
                    break
            break
    cache[ts] = version
    return version

lo = parse_ts(from_ts)
hi = parse_ts(to_ts)
if lo > hi:
    raise SystemExit("--from must be <= --to")

lo_ver = fetch_version(lo)
hi_ver = fetch_version(hi)

def is_match(ver: str | None) -> bool:
    return ver is not None and ver.startswith(prefix)

if not is_match(lo_ver):
    raise SystemExit(f"Lower bound {from_ts} is not on the target line: {lo_ver}")
if is_match(hi_ver):
    raise SystemExit(f"Upper bound {to_ts} is still on the target line: {hi_ver}")

while hi - lo > resolution:
    mid = lo + (hi - lo) // 2
    ver = fetch_version(mid)
    if is_match(ver):
        lo = mid
    else:
        hi = mid

lo_ver = fetch_version(lo)
hi_ver = fetch_version(hi)

print(f"package={package}")
print(f"target_prefix={prefix}")
print(f"last_matching_snapshot={fmt_snapshot(lo)}")
print(f"last_matching_time_utc={fmt_iso(lo)}")
print(f"last_matching_version={lo_ver}")
print(f"first_non_matching_snapshot={fmt_snapshot(hi)}")
print(f"first_non_matching_time_utc={fmt_iso(hi)}")
print(f"first_non_matching_version={hi_ver}")
print(f"resolution_seconds={resolution}")
PY
