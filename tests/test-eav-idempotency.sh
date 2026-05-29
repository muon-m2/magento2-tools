#!/usr/bin/env bash
# EAV patch templates must:
#   1. Call getAttribute() before addAttribute() (idempotency).
#   2. Wrap the body after startSetup() in try { ... } finally { endSetup(); } so the
#      setup state always closes even if the patch throws.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
for tpl in skills/magento2-eav-attribute/templates/eav-add-*-patch.php; do
    [ -f "$tpl" ] || continue

    # Idempotency: getAttribute() before addAttribute().
    if ! grep -q 'getAttribute(' "$tpl"; then
        echo "FAIL: $tpl has no getAttribute() guard"
        FAIL=1
        continue
    fi
    first_get=$(grep -n 'getAttribute(' "$tpl" | head -1 | cut -d: -f1)
    first_add=$(grep -n 'addAttribute(' "$tpl" | head -1 | cut -d: -f1)
    if [ -z "$first_add" ]; then
        echo "FAIL: $tpl never calls addAttribute()"
        FAIL=1
        continue
    fi
    if [ "$first_get" -ge "$first_add" ]; then
        echo "FAIL: $tpl calls addAttribute() before any getAttribute() guard"
        FAIL=1
    fi

    # Lifecycle: try { ... } finally { endSetup(); } around the body.
    if ! grep -q 'startSetup' "$tpl"; then
        echo "FAIL: $tpl never calls startSetup()"
        FAIL=1
        continue
    fi
    if ! grep -qE '^\s*try\s*\{' "$tpl"; then
        echo "FAIL: $tpl lacks try { ... } block after startSetup()"
        FAIL=1
    fi
    if ! grep -qE '^\s*\}\s*finally\s*\{' "$tpl"; then
        echo "FAIL: $tpl lacks finally { endSetup() } block"
        FAIL=1
    fi
    # endSetup must appear inside the finally block — i.e. on a line after the finally
    # but before the closing brace of apply(). A simple proxy: at least one endSetup()
    # must follow the finally marker.
    finally_line=$(grep -nE '^\s*\}\s*finally\s*\{' "$tpl" | head -1 | cut -d: -f1)
    if [ -n "$finally_line" ]; then
        if ! tail -n +"$finally_line" "$tpl" | grep -q 'endSetup'; then
            echo "FAIL: $tpl finally block does not call endSetup()"
            FAIL=1
        fi
    fi
done

exit "$FAIL"
