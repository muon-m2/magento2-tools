#!/usr/bin/env bash
# =============================================================================
# Stamp the standard copyright/license header onto every PHP file in a module.
#
# Usage: magento2-context/scripts/add-license-headers.sh <module-path> <Vendor>
#
# Inserts, immediately after the `<?php` line of each *.php file:
#
#     /**
#      * Copyright © <Vendor>. All rights reserved.
#      * See LICENSE.txt for license details.
#      */
#
# The header is generic (it points at LICENSE.txt rather than restating terms),
# so the same block is correct whether the module ships a proprietary EULA or an
# OSI license — the LICENSE.txt file holds the actual terms.
#
# Idempotent: a file that already contains the header marker is left untouched,
# so this is safe to re-run (augment mode) and never duplicates the block.
# Files whose first line is not `<?php` are skipped, not rewritten.
#
# Exit codes:
#   0 — completed (some files may have been skipped — reported, not fatal)
#   2 — bad arguments
# =============================================================================
set -euo pipefail

module_path="${1:-}"
vendor="${2:-}"

if [[ -z "$module_path" || -z "$vendor" ]]; then
    echo "Usage: $0 <module-path> <Vendor>" >&2
    exit 2
fi
if [[ ! -d "$module_path" ]]; then
    echo "Not a directory: $module_path" >&2
    exit 2
fi

MARKER="See LICENSE.txt for license details."

stamped=0
present=0
skipped=0

while IFS= read -r -d '' file; do
    if grep -qF "$MARKER" "$file"; then
        present=$((present + 1))
        continue
    fi
    if [[ "$(head -n 1 "$file")" != "<?php" ]]; then
        printf "  ⚠  skipped (no '<?php' on line 1): %s\n" "${file#"$module_path"/}" >&2
        skipped=$((skipped + 1))
        continue
    fi

    tmp="$(mktemp "${TMPDIR:-/tmp}/m2-hdr.XXXXXX")"
    {
        printf '<?php\n'
        printf '/**\n'
        printf ' * Copyright © %s. All rights reserved.\n' "$vendor"
        printf ' * %s\n' "$MARKER"
        printf ' */\n'
        tail -n +2 "$file"
    } > "$tmp"
    # Write back in place so the file's inode/permissions are preserved.
    cat "$tmp" > "$file"
    rm -f "$tmp"
    stamped=$((stamped + 1))
done < <(find "$module_path" -type f -name '*.php' -print0)

printf "license headers — stamped: %d, already present: %d, skipped: %d\n" \
    "$stamped" "$present" "$skipped"
