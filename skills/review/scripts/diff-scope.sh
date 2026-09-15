#!/usr/bin/env bash
# diff-scope.sh — list files changed in a module since a given git ref: committed, staged, unstaged
# and untracked (not ignored) files alike.
#
# Usage:
#   diff-scope.sh <module-path> [<ref>]
#
#   <module-path>  e.g. src/app/code/Acme/OrderS3Export
#   <ref>          git ref (default: origin/main)
#
# Output:
#   Prints one path per line (relative to repo root), filtered to:
#     *.php, *.xml, *.xsd, *.phtml, *.json, *.graphqls, *.html, *.css, *.less, *.js
#   restricted to files inside <module-path>.
#
# Exits 0 if any changed files; 1 if none (allowing callers to short-circuit).

set -euo pipefail

MODULE_PATH="${1:?usage: diff-scope.sh <module-path> [<ref>]}"
REF="${2:-origin/main}"

if [ ! -d "$MODULE_PATH" ]; then
    echo "diff-scope: module path not found: $MODULE_PATH" >&2
    exit 2
fi

if ! command -v git >/dev/null 2>&1; then
    echo "diff-scope: git not available" >&2
    exit 3
fi

# Validate ref exists; fall back to HEAD~ if missing.
if ! git rev-parse --verify --quiet "$REF" >/dev/null; then
    if git rev-parse --verify --quiet "HEAD~" >/dev/null; then
        echo "diff-scope: ref '$REF' missing; falling back to HEAD~" >&2
        REF="HEAD~"
    else
        echo "diff-scope: ref '$REF' missing and no HEAD~ fallback available" >&2
        exit 4
    fi
fi

# "Changed" is measured on the WORKING TREE against the point this branch left <ref>: committed,
# staged, unstaged, and untracked-but-not-ignored files all count. `git diff <ref>...HEAD` compared
# commits only, so uncommitted work — the state `feature` runs its R* reviews in, with per-task
# commits off by default — read as "no changed files" and the review stopped with "nothing to
# review". On a clean tree (CI, pull requests) the list is the same as before.
BASE="$(git merge-base "$REF" HEAD 2>/dev/null || true)"
BASE="${BASE:-$REF}"

# `git ls-files` prints cwd-relative paths unless given --full-name; `git diff --name-only` always
# prints root-relative ones. Both must agree, or the same file could be listed twice.
CHANGED=$( { git diff --name-only --diff-filter=ACMR "$BASE" -- "$MODULE_PATH" 2>/dev/null
             git ls-files --others --exclude-standard --full-name -- "$MODULE_PATH" 2>/dev/null; } \
    | grep -E '\.(php|xml|xsd|phtml|json|graphqls|html|css|less|js)$' \
    | sort -u \
    || true)

if [ -z "$CHANGED" ]; then
    echo "diff-scope: no changed files in $MODULE_PATH since $REF (committed, uncommitted or untracked)" >&2
    exit 1
fi

printf '%s\n' "$CHANGED"
