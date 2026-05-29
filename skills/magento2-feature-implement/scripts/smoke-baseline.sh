#!/usr/bin/env bash
# smoke-baseline.sh — capture a baseline for var/log/exception.log before the smoke run.
#
# Usage:
#   smoke-baseline.sh <output-baseline-file>
#
# Resolves the Magento root in this order:
#   1. src/  (if src/app/etc/env.php exists)
#   2. .     (if app/etc/env.php exists)
#   3. first var/log/exception.log found via `find` capped at depth 3
#
# Output file format (key=value):
#   file=<absolute path>
#   size_bytes=<size>
#   sha256_of_last_4096=<hex>
#   captured_at=<ISO8601 UTC>
#
# Exit codes:
#   0 — baseline captured (file may not exist yet — size_bytes=0 in that case)
#   2 — could not locate a Magento root with var/log/

set -euo pipefail

if [[ "${1:-}" == "" ]]; then
  echo "usage: $0 <output-baseline-file>" >&2
  exit 64
fi

OUT="$1"

resolve_log() {
  if [[ -f "src/app/etc/env.php" ]]; then
    echo "src/var/log/exception.log"
    return 0
  fi
  if [[ -f "app/etc/env.php" ]]; then
    echo "var/log/exception.log"
    return 0
  fi
  local found
  found="$(find . -maxdepth 4 -type f -path '*/var/log/exception.log' 2>/dev/null | head -n1 || true)"
  if [[ -n "${found}" ]]; then
    echo "${found#./}"
    return 0
  fi
  return 1
}

LOG_PATH="$(resolve_log || true)"
if [[ -z "${LOG_PATH}" ]]; then
  echo "no var/log/exception.log found at common Magento roots" >&2
  exit 2
fi

ABS_PATH="$(readlink -f "${LOG_PATH}" 2>/dev/null || python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "${LOG_PATH}")"

if [[ -f "${LOG_PATH}" ]]; then
  SIZE="$(stat -c '%s' "${LOG_PATH}" 2>/dev/null || stat -f '%z' "${LOG_PATH}")"
  if [[ "${SIZE}" -gt 0 ]]; then
    if [[ "${SIZE}" -le 4096 ]]; then
      SHA="$(sha256sum "${LOG_PATH}" | awk '{print $1}')"
    else
      SHA="$(tail -c 4096 "${LOG_PATH}" | sha256sum | awk '{print $1}')"
    fi
  else
    SHA="0"
  fi
else
  SIZE=0
  SHA="0"
fi

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

mkdir -p "$(dirname "${OUT}")"
cat > "${OUT}" <<EOF
file=${ABS_PATH}
size_bytes=${SIZE}
sha256_of_last_4096=${SHA}
captured_at=${NOW}
EOF

echo "baseline written: ${OUT}"
echo "  file=${ABS_PATH}"
echo "  size_bytes=${SIZE}"
echo "  captured_at=${NOW}"
