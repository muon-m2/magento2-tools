#!/usr/bin/env bash
# Every script under skills/*/scripts/ must pass `bash -n`.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
while IFS= read -r script; do
    if ! bash -n "$script" 2>&1; then
        echo "syntax error in $script"
        FAIL=1
    fi
done < <(find skills -path '*/scripts/*.sh' -type f)

exit "$FAIL"
