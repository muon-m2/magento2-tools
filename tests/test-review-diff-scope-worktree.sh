#!/usr/bin/env bash
# diff-scope.sh must list the changes a review is asked to look at — committed, uncommitted and
# untracked alike.
#
# Regression test for a review that silently reviewed nothing. The file list came from
# `git diff <ref>...HEAD`, which compares COMMITS: a modified-but-uncommitted file and a brand-new
# untracked file were both invisible, the script reported "no changed files" and exited 1, and
# review's diff mode short-circuits on exit 1 with "no findings — nothing to review". That is
# exactly the state `feature` runs its R* reviews in, because per-task commits are off by default.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v git >/dev/null 2>&1 || { echo "skip: git not on PATH"; exit 77; }

SCRIPT="$PWD/skills/review/scripts/diff-scope.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }

# Hermetic git: no signing prompts, no line-ending rewrites, no user config required.
g() {
    git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c tag.gpgsign=false \
        -c core.autocrlf=false "$@"
}

cd "$WORK" || exit 1
g init -q
mkdir -p mod/etc other
echo a > mod/a.php
echo x > mod/etc/c.xml
echo z > other/z.php
printf 'mod/gen.php\n' > .gitignore
g add . && g commit -qm base && g tag v1

# 1. Clean tree: a change committed since the ref must still be listed (the CI / pull-request case).
echo more >> mod/etc/c.xml
g commit -qam second
out="$(bash "$SCRIPT" mod v1 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] || fail "clean tree: exit $rc, expected 0"
printf '%s\n' "$out" | grep -qx 'mod/etc/c.xml' || fail "clean tree: committed change not listed: [$out]"

# 2. Uncommitted edit, untracked new file, staged new file — the state feature's R* reviews run in.
echo b >> mod/a.php
echo new > mod/b.php
echo staged > mod/s.php && g add mod/s.php
echo notes > mod/notes.txt      # untracked, but not a reviewable extension
echo gen > mod/gen.php          # untracked AND gitignored
out="$(bash "$SCRIPT" mod v1 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] || fail "dirty tree: exit $rc, expected 0 (reported: $(bash "$SCRIPT" mod v1 2>&1 >/dev/null))"
for f in mod/a.php mod/b.php mod/s.php mod/etc/c.xml; do
    printf '%s\n' "$out" | grep -qx "$f" || fail "dirty tree: $f not listed: [$out]"
done
printf '%s\n' "$out" | grep -q 'notes.txt' && fail "dirty tree: the extension filter no longer applies: [$out]"
printf '%s\n' "$out" | grep -q 'gen.php' && fail "dirty tree: a gitignored file was listed: [$out]"
[ "$(printf '%s\n' "$out" | sort | uniq -d)" = "" ] || fail "dirty tree: a path was listed twice: [$out]"

# 3. From inside the module: paths stay relative to the repo root, as the header promises.
#    `git ls-files` prints cwd-relative paths by default, `git diff --name-only` root-relative ones.
out="$(cd mod && bash "$SCRIPT" . v1 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] || fail "subdirectory: exit $rc, expected 0"
for f in mod/a.php mod/b.php; do
    printf '%s\n' "$out" | grep -qx "$f" || fail "subdirectory: $f not listed root-relative: [$out]"
done

# 4. The short-circuit contract survives: a module with no changes at all still exits 1.
bash "$SCRIPT" other v1 >/dev/null 2>&1; rc=$?
[ "$rc" = "1" ] || fail "unchanged module: exit $rc, expected 1"

if [ "$FAIL" = "0" ]; then
    echo "PASS: diff-scope lists committed, uncommitted, staged and untracked changes"
    exit 0
fi
exit 1
