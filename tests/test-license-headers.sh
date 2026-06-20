#!/usr/bin/env bash
# test-license-headers.sh — contract test for the module-create license-header stamper.
#
# magento2-context/scripts/add-license-headers.sh <module-path> <Vendor> must:
#   - prepend the standard copyright header (pointing at LICENSE.txt) to every *.php,
#     inserted immediately after the `<?php` line;
#   - be idempotent — a file that already carries the header is left untouched, and a
#     second run adds nothing;
#   - recurse into subdirectories;
#   - leave non-PHP files alone and skip any .php whose first line is not `<?php`;
#   - keep the result valid PHP (php -l), when php is available.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/magento2-context/scripts/add-license-headers.sh"
MARKER="See LICENSE.txt for license details."
COPYRIGHT="Copyright © Acme. All rights reserved."

if [ ! -f "$SCRIPT" ]; then
    echo "FAIL: stamper not found at $SCRIPT"
    exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/m2-hdr.XXXXXX")"
trap 'rm -f "$tmp_unused" 2>/dev/null; rm -rf "$work"' EXIT
tmp_unused=""

mkdir -p "$work/Service" "$work/Model"

# a.php — no header, canonical layout. Should be stamped.
printf '<?php\n\ndeclare(strict_types=1);\n\nnamespace Acme\\Mod\\Service;\n\nclass A\n{\n}\n' > "$work/Service/A.php"

# b.php — already carries the header. Should be left byte-identical.
printf '<?php\n/**\n * Copyright © Acme. All rights reserved.\n * %s\n */\ndeclare(strict_types=1);\n\nclass B\n{\n}\n' "$MARKER" > "$work/Model/B.php"
b_before="$(cat "$work/Model/B.php")"

# plain.txt — not PHP. Should be ignored.
printf 'just text\n' > "$work/plain.txt"

# Weird.php — first line is not `<?php`. Should be skipped, not corrupted.
printf '#!/usr/bin/env php\n<?php\necho 1;\n' > "$work/Weird.php"
weird_before="$(cat "$work/Weird.php")"

count_marker() { grep -cF "$MARKER" "$1" 2>/dev/null || true; }

# --- run the stamper ---
if ! bash "$SCRIPT" "$work" "Acme" >/dev/null 2>&1; then
    echo "FAIL: stamper exited non-zero on a valid module path"
    exit 1
fi

fail=0

# a.php gets exactly one header, after <?php, with the right copyright line.
if [ "$(count_marker "$work/Service/A.php")" != "1" ]; then
    echo "FAIL: A.php should carry exactly one header marker"; fail=1
fi
if [ "$(head -n1 "$work/Service/A.php")" != "<?php" ]; then
    echo "FAIL: A.php first line must remain '<?php'"; fail=1
fi
if [ "$(sed -n '2p' "$work/Service/A.php")" != "/**" ]; then
    echo "FAIL: A.php header must start immediately after the <?php line"; fail=1
fi
if ! grep -qF "$COPYRIGHT" "$work/Service/A.php"; then
    echo "FAIL: A.php missing copyright line for the given vendor"; fail=1
fi

# b.php already had a header → untouched (still exactly one marker, byte-identical).
if [ "$(count_marker "$work/Model/B.php")" != "1" ]; then
    echo "FAIL: B.php header must not be duplicated"; fail=1
fi
if [ "$(cat "$work/Model/B.php")" != "$b_before" ]; then
    echo "FAIL: B.php (already stamped) must be left byte-identical"; fail=1
fi

# non-PHP untouched
if grep -qF "$MARKER" "$work/plain.txt"; then
    echo "FAIL: plain.txt (non-PHP) must not be stamped"; fail=1
fi

# weird first line untouched
if [ "$(cat "$work/Weird.php")" != "$weird_before" ]; then
    echo "FAIL: Weird.php (no <?php on line 1) must be left untouched"; fail=1
fi

# --- idempotency: a second run changes nothing ---
a_after_first="$(cat "$work/Service/A.php")"
bash "$SCRIPT" "$work" "Acme" >/dev/null 2>&1
if [ "$(cat "$work/Service/A.php")" != "$a_after_first" ]; then
    echo "FAIL: second run must be a no-op (not idempotent)"; fail=1
fi
if [ "$(count_marker "$work/Service/A.php")" != "1" ]; then
    echo "FAIL: second run duplicated the header"; fail=1
fi

# --- stamped file must still be valid PHP ---
if command -v php >/dev/null 2>&1; then
    if ! php -l "$work/Service/A.php" >/dev/null 2>&1; then
        echo "FAIL: stamped A.php no longer passes php -l"; fail=1
    fi
fi

if [ "$fail" -eq 0 ]; then
    echo "license-header stamper: all assertions passed"
fi
exit "$fail"
