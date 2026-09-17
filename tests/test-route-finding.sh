#!/usr/bin/env bash
# test-route-finding.sh — contract test for the finding→owning-skill resolver.
#
# route-finding.sh must:
#   - route each producer/category pair to the owner named in fix-routing.md;
#   - honour the conditional rows both ways (the --file and --breeze predicates);
#   - prefer an exact subcategory row over a wildcard row;
#   - emit `unrouted` (exit 0) rather than guessing when no row matches.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/context/scripts/route-finding.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: resolver not found at $SCRIPT"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

FAIL=0

# expect <owner> -- <args…>
expect() {
    local want="$1"; shift
    [ "$1" = "--" ] && shift
    local got
    got="$(bash "$SCRIPT" "$@" | cut -f1)"
    if [ "$got" != "$want" ]; then
        echo "FAIL: $* → '$got', expected '$want'"
        FAIL=1
    fi
}

# --- specialist owners the old prose tables never reached ---
expect extension-point -- --skill=security   --category=preference-collision
expect graphql         -- --skill=security   --category=graphql-auth
expect upgrade         -- --skill=security   --category=cve
expect extension-point -- --skill=perf-audit --category=plugin-hotpath
expect indexer         -- --skill=perf-audit --category=indexer
expect message-queue   -- --skill=perf-audit --category=queue
expect cli-command     -- --skill=perf-audit --category=cron-batch
expect frontend        -- --skill=perf-audit --category=storefront-http
expect breeze-adapt    -- --skill=breeze-compat --category=knockout
expect frontend        -- --skill=a11y-audit --category=alt-text
expect docs            -- --skill=marketplace --category=documentation

# --- conditional rows, exercised BOTH ways ---
expect webapi  -- --skill=review --category=api --file=Api/OrderRepositoryInterface.php
expect graphql -- --skill=review --category=api --file=Model/Resolver/Orders.php

expect admin-form    -- --skill=review --category=admin --file=view/adminhtml/ui_component/acme_order_form.xml
expect admin-listing -- --skill=review --category=admin --file=view/adminhtml/ui_component/acme_order_listing.xml

expect frontend -- --skill=review --category=csp --file=view/frontend/templates/js.phtml
expect fix      -- --skill=review --category=csp --file=etc/csp_whitelist.xml

expect frontend     -- --skill=review --category=frontend --file=view/frontend/web/js/a.js
expect breeze-adapt -- --skill=review --category=frontend --file=view/frontend/web/js/a.js --breeze

# --- surface invariants route by their SI rule id, not by the category ---
expect message-queue -- --skill=lint --category=surface --subcategory=SI-01
expect admin-listing -- --skill=lint --category=surface --subcategory=SI-06
expect admin-form    -- --skill=lint --category=surface --subcategory=SI-07
expect fix           -- --skill=lint --category=surface --subcategory=SI-09

# --- gates ---
GATE="$(bash "$SCRIPT" --skill=security --category=secret | cut -f2)"
if [ "$GATE" != "manual" ]; then
    echo "FAIL: security/secret gate is '$GATE', expected 'manual' (a burned credential needs rotation, not just deletion)"
    FAIL=1
fi
GATE="$(bash "$SCRIPT" --skill=lint --category=style | cut -f2)"
if [ "$GATE" != "auto" ]; then
    echo "FAIL: lint/style gate is '$GATE', expected 'auto'"
    FAIL=1
fi

# --- never guess ---
OUT="$(bash "$SCRIPT" --skill=review --category=not-a-real-category)"
RC=$?
if [ "$RC" -ne 0 ]; then echo "FAIL: unmatched row exited $RC, expected 0"; FAIL=1; fi
if [ "$(printf '%s' "$OUT" | cut -f1)" != "unrouted" ]; then
    echo "FAIL: unmatched row → '$OUT', expected owner 'unrouted'"
    FAIL=1
fi

# The documented signature must not advertise a flag the resolver rejects: a caller
# following the doc would exit 2 at runtime. Every long flag named in the signature block
# must be one the resolver actually accepts.
# Scope to the FENCED block inside the section, not the whole section: the surrounding
# prose legitimately names flags it is telling you NOT to use, and markdown table rules
# (`------`) also look like long flags. A `sed '/start/,/```/' ` range would instead stop at
# the OPENING fence and capture nothing, which passes vacuously.
SIGFLAGS="$(awk '
    /^## Resolution signature/ {sec=1; next}
    sec && /^## / {exit}
    sec && /^```/ {fence=!fence; next}
    sec && fence' skills/context/references/fix-routing.md \
    | grep -oE '[-][-][a-z][a-z-]*' | sort -u)"
if [ -z "$SIGFLAGS" ]; then
    echo "FAIL: parsed zero flags from fix-routing.md's Resolution signature section"
    FAIL=1
fi
for flag in $SIGFLAGS; do
    case "$flag" in
        --breeze) probe="$flag" ;;
        *)        probe="${flag}=x" ;;
    esac
    if bash "$SCRIPT" --skill=review --category=security "$probe" >/dev/null 2>&1; then
        :
    else
        echo "FAIL: fix-routing.md's signature documents '$flag', but route-finding.sh rejects it"
        FAIL=1
    fi
done

if [ "$FAIL" -eq 0 ]; then echo "PASS: routing resolver matches fix-routing.md"; fi
exit "$FAIL"
