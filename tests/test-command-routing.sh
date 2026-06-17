#!/usr/bin/env bash
# test-command-routing.sh — every commands/*.md must be a well-formed thin pass-through to a
# real magento2-* skill, and the set must be exactly the 9 expected shortcuts. Write commands
# must be user-only (disable-model-invocation: true).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CMD_DIR="commands"
FAIL=0

# expected: command verb -> target skill
EXPECTED="context:magento2-context
snapshot:magento2-debug
review:magento2-module-review
security:magento2-security-audit
perf:magento2-performance-audit
deploy:magento2-deploy
bugfix:magento2-bug-fix
feature:magento2-feature-implement
release:magento2-release"

if [ ! -d "$CMD_DIR" ]; then echo "FAIL: $CMD_DIR/ directory not found"; exit 1; fi

# 1. each expected command exists, is well-formed, and routes to its (real) skill
while IFS=: read -r cmd skill; do
    [ -n "$cmd" ] || continue
    f="$CMD_DIR/$cmd.md"
    if [ ! -f "$f" ]; then echo "FAIL: missing command file $f"; FAIL=1; continue; fi
    [ "$(head -1 "$f")" = "---" ] || { echo "FAIL: $f missing YAML frontmatter"; FAIL=1; }
    grep -qE '^description: +.+' "$f" || { echo "FAIL: $f missing non-empty description"; FAIL=1; }
    grep -qE '^argument-hint:' "$f" || { echo "FAIL: $f missing argument-hint"; FAIL=1; }
    grep -qF "magento2-tools:$skill"'`' "$f" || { echo "FAIL: $f does not route to magento2-tools:$skill"; FAIL=1; }
    grep -qF '$ARGUMENTS' "$f" || { echo "FAIL: $f does not forward \$ARGUMENTS"; FAIL=1; }
    [ -d "skills/$skill" ] || { echo "FAIL: $f routes to non-existent skill $skill"; FAIL=1; }
done <<EOF
$EXPECTED
EOF

# 2. write commands must be user-only
for cmd in deploy bugfix feature release; do
    f="$CMD_DIR/$cmd.md"
    [ -f "$f" ] || continue
    grep -qE '^disable-model-invocation: +true' "$f" \
        || { echo "FAIL: write command $f must set 'disable-model-invocation: true'"; FAIL=1; }
done

# 2b. read-only commands must NOT be user-only (auto-invokable)
for cmd in context snapshot review security perf; do
    f="$CMD_DIR/$cmd.md"
    [ -f "$f" ] || continue
    grep -qE '^disable-model-invocation: +true' "$f" \
        && { echo "FAIL: read-only command $f must not set 'disable-model-invocation: true'"; FAIL=1; }
done

# 3. no unexpected command files, and filenames are lowercase-kebab
for f in "$CMD_DIR"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    printf '%s\n' "$EXPECTED" | grep -q "^$base:" \
        || { echo "FAIL: unexpected command file $f (not in expected set)"; FAIL=1; }
    printf '%s' "$base" | grep -qE '^[a-z][a-z0-9-]*$' \
        || { echo "FAIL: $f filename not lowercase-kebab"; FAIL=1; }
done

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "command routing: 9 commands valid, well-formed, routed to real skills"
exit 0
