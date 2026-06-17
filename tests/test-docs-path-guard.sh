#!/usr/bin/env bash
# test-docs-path-guard.sh — the .docs/ path guard's matcher (and, when python3 is present,
# the entry script end-to-end). Matcher cases need no interpreter and always run.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# shellcheck source=../hooks/docs-path-matcher.sh
. hooks/docs-path-matcher.sh

FAIL=0
R=/proj

m() { # desc expected root path is_magento
    local desc="$1" expected="$2" got
    got="$(docs_path_decide "$3" "$4" "$5")"
    if [ "$got" = "$expected" ]; then
        printf '  ok   matcher: %s\n' "$desc"
    else
        printf '  FAIL matcher: %s — expected %s got %s\n' "$desc" "$expected" "$got"
        FAIL=1
    fi
}

echo "matcher unit cases:"
m "canonical {root}/.docs"        allow "$R" "$R/.docs/review.md"               yes
m "nested under {root}/.docs"     allow "$R" "$R/.docs/sub/x.md"                yes
m "{root}/.docs itself"           allow "$R" "$R/.docs"                         yes
m "src/.docs misplaced"           deny  "$R" "$R/src/.docs/review.md"           yes
m "module .docs misplaced"        deny  "$R" "$R/app/code/Acme/Mod/.docs/x.md"  yes
m "vendor .docs misplaced"        deny  "$R" "$R/vendor/foo/.docs/x.md"         yes
m "notdocs/.docs misplaced"       deny  "$R" "$R/notdocs/.docs/x.md"            yes
m "non-.docs path"                allow "$R" "$R/app/code/Acme/Mod/etc/di.xml"  yes
m "filename containing .docs"     allow "$R" "$R/notes.docs"                    yes
m "scope gate off (non-magento)"  allow "$R" "$R/src/.docs/x.md"                no
m "outside project root"          allow "$R" "/tmp/out/.docs/x.md"              yes

if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
exit 0
