#!/usr/bin/env bash
# test-command-routing.sh — every commands/*.md must be a well-formed thin pass-through to a
# real skill, and the set must be exactly the 18 expected shortcuts. Every command except
# the scaffold dispatcher must be user-only (disable-model-invocation: true) so the Skill
# tool reaches the skill, not the command stub.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CMD_DIR="commands"
FAIL=0

# expected: command verb -> target skill
EXPECTED="context:context
snapshot:debug
review:review
security:security
perf:perf-audit
deploy:deploy
bugfix:fix
feature:feature
release:release
test:test-generate
upgrade:upgrade
i18n:i18n
lint:lint
scaffold:module-create
audit:audit
docs:docs
triage:triage
remediate:remediate"

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

# 2. every command except the scaffold dispatcher is user-only. With a model-invocable command
#    sharing a skill's name, the Skill tool resolves to the thin command stub and the skill body
#    becomes unreachable; user-only commands let the model reach the skills directly.
for f in "$CMD_DIR"/*.md; do
    [ -e "$f" ] || continue
    cmd="$(basename "$f" .md)"
    [ "$cmd" = "scaffold" ] && continue
    grep -qE '^disable-model-invocation: +true' "$f" \
        || { echo "FAIL: command $f must set 'disable-model-invocation: true'"; FAIL=1; }
done

# 2b. the scaffold dispatcher routes to (gated) generator skills; it is itself a model-invocable
#     entry point — the write gate lives in the target skill — so it must NOT be user-only.
f="$CMD_DIR/scaffold.md"
if [ ! -f "$f" ]; then echo "FAIL: missing $f"; FAIL=1
elif grep -qE '^disable-model-invocation: +true' "$f"; then
    echo "FAIL: dispatcher command $f must not set 'disable-model-invocation: true' (gates live in target skills)"; FAIL=1
fi

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
echo "command routing: 18 commands valid, well-formed, routed to real skills"
exit 0
