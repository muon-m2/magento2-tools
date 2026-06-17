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

# Entry-script integration (needs python3; matcher cases above already ran).
if command -v python3 >/dev/null 2>&1; then
    echo "entry-script integration cases:"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/bin"; : > "$tmp/bin/magento"   # mark $tmp as a Magento project

    mkjson() { # tool path cwd
        python3 -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":{"file_path":sys.argv[2]},"cwd":sys.argv[3]}))' "$1" "$2" "$3"
    }
    e() { # desc want_exit tool path [cwd]
        local desc="$1" want="$2" tool="$3" path="$4" cwd="${5:-$tmp}" rc=0
        CLAUDE_PROJECT_DIR="$tmp" bash hooks/guard-docs-path.sh <<<"$(mkjson "$tool" "$path" "$cwd")" >/dev/null 2>&1 || rc=$?
        if [ "$rc" = "$want" ]; then
            printf '  ok   entry: %s (exit %s)\n' "$desc" "$rc"
        else
            printf '  FAIL entry: %s — expected exit %s got %s\n' "$desc" "$want" "$rc"
            FAIL=1
        fi
    }

    e "Write canonical .docs allowed"    0 Write "$tmp/.docs/r.md"
    e "Write src/.docs blocked"          2 Write "$tmp/src/.docs/r.md"
    e "Write module .docs blocked"       2 Write "$tmp/app/code/A/M/.docs/x.md"
    e "Edit non-.docs allowed"           0 Edit  "$tmp/app/code/A/M/etc/di.xml"
    e "Write relative src/.docs blocked" 2 Write "src/.docs/r.md"
    e "non-Write/Edit tool ignored"      0 Read  "$tmp/src/.docs/r.md"

    # Non-Magento project: the same misplaced path must be allowed.
    tmp2="$(mktemp -d)"; rc2=0
    CLAUDE_PROJECT_DIR="$tmp2" bash hooks/guard-docs-path.sh \
        <<<"$(mkjson Write "$tmp2/src/.docs/x.md" "$tmp2")" >/dev/null 2>&1 || rc2=$?
    if [ "$rc2" = 0 ]; then printf '  ok   entry: non-magento misplaced allowed (exit 0)\n'
    else printf '  FAIL entry: non-magento expected 0 got %s\n' "$rc2"; FAIL=1; fi
    rm -rf "$tmp2"

    # Fail-open: no CLAUDE_PROJECT_DIR -> allow even a misplaced path.
    rc3=0
    env -u CLAUDE_PROJECT_DIR bash hooks/guard-docs-path.sh \
        <<<"$(mkjson Write /x/src/.docs/x.md /x)" >/dev/null 2>&1 || rc3=$?
    if [ "$rc3" = 0 ]; then printf '  ok   entry: fail-open without project dir (exit 0)\n'
    else printf '  FAIL entry: fail-open expected 0 got %s\n' "$rc3"; FAIL=1; fi
else
    echo "entry-script integration: SKIP (python3 not on PATH); matcher cases ran"
fi

if [ "$FAIL" -ne 0 ]; then echo "RESULT: FAIL"; exit 1; fi
echo "RESULT: PASS"
exit 0
