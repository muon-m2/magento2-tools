#!/usr/bin/env bash
# smoke-tail-since.sh — diff var/log/exception.log against a baseline captured by smoke-baseline.sh.
#
# Usage:
#   smoke-tail-since.sh <baseline-file> <output-diff-file>
#
# Behaviour:
#   - Reads baseline keys: file, size_bytes, sha256_of_last_4096.
#   - If live size >= baseline size and the rotation hash still matches the original tail region,
#     dumps live bytes [baseline_size .. EOF] to the output file.
#   - If live size <  baseline size OR the rotation hash mismatches, treats this as a rotation:
#     dumps the full live file AND, if found, the post-baseline portion of var/log/exception.log.1.
#   - If the live file is missing, writes a single line "MISSING: log file disappeared after baseline".
#
# Exit codes:
#   0 — diff captured (may be empty — caller must check)
#   1 — diff captured AND it is non-empty (convenience for shell `if`)
#   2 — baseline file missing or malformed
#   3 — live log path could not be located

set -euo pipefail

if [[ "${1:-}" == "" || "${2:-}" == "" ]]; then
  echo "usage: $0 <baseline-file> <output-diff-file>" >&2
  exit 64
fi

BASELINE="$1"
OUT="$2"

if [[ ! -f "${BASELINE}" ]]; then
  echo "baseline file not found: ${BASELINE}" >&2
  exit 2
fi

BASE_FILE=""
BASE_SIZE=""
BASE_SHA=""
while IFS='=' read -r key val; do
  case "${key}" in
    file) BASE_FILE="${val}" ;;
    size_bytes) BASE_SIZE="${val}" ;;
    sha256_of_last_4096) BASE_SHA="${val}" ;;
  esac
done < "${BASELINE}"

if [[ -z "${BASE_FILE}" || -z "${BASE_SIZE}" ]]; then
  echo "baseline file malformed: ${BASELINE}" >&2
  exit 2
fi

mkdir -p "$(dirname "${OUT}")"
: > "${OUT}"

if [[ ! -f "${BASE_FILE}" ]]; then
  echo "MISSING: ${BASE_FILE} disappeared after baseline (size_bytes=${BASE_SIZE})" >> "${OUT}"
  if [[ -s "${OUT}" ]]; then exit 1; fi
  exit 0
fi

LIVE_SIZE="$(stat -c '%s' "${BASE_FILE}" 2>/dev/null || stat -f '%z' "${BASE_FILE}")"

rotation_check() {
  # returns 0 if rotation hash still matches (no rotation), 1 if it does not
  local at="${BASE_SIZE}"
  if [[ "${at}" -le 4096 ]]; then
    local end=$(( at ))
    if [[ "${end}" -eq 0 ]]; then return 0; fi
    local sha
    sha="$(head -c "${end}" "${BASE_FILE}" | sha256sum | awk '{print $1}')"
    [[ "${sha}" == "${BASE_SHA}" ]]
  else
    local start=$(( at - 4096 ))
    local sha
    sha="$(dd if="${BASE_FILE}" bs=1 skip="${start}" count=4096 2>/dev/null | sha256sum | awk '{print $1}')"
    [[ "${sha}" == "${BASE_SHA}" ]]
  fi
}

if [[ "${LIVE_SIZE}" -ge "${BASE_SIZE}" ]] && rotation_check; then
  if [[ "${LIVE_SIZE}" -gt "${BASE_SIZE}" ]]; then
    tail -c +"$(( BASE_SIZE + 1 ))" "${BASE_FILE}" > "${OUT}"
  fi
else
  echo "# ROTATION DETECTED: live size ${LIVE_SIZE} < baseline ${BASE_SIZE} or hash mismatch" >> "${OUT}"
  cat "${BASE_FILE}" >> "${OUT}"
  ROTATED="${BASE_FILE}.1"
  if [[ -f "${ROTATED}" ]]; then
    ROT_SIZE="$(stat -c '%s' "${ROTATED}" 2>/dev/null || stat -f '%z' "${ROTATED}")"
    if [[ "${ROT_SIZE}" -gt "${BASE_SIZE}" ]]; then
      echo "# ALSO INCLUDING POST-BASELINE PORTION OF ${ROTATED}" >> "${OUT}"
      tail -c +"$(( BASE_SIZE + 1 ))" "${ROTATED}" >> "${OUT}"
    fi
  fi
fi

if [[ -s "${OUT}" ]]; then
  exit 1
fi
exit 0
