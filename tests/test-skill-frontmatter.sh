#!/usr/bin/env bash
# test-skill-frontmatter.sh — validate every skill's SKILL.md YAML frontmatter.
#
# This is the test that would have caught EAV-1 (4 leading spaces before the opening
# `---`, which silently un-registered the skill) and FI-4 (over-long description).
#
# Contract for each skills/<dir>/SKILL.md:
#   1. line 1 is exactly "---" (no leading whitespace, no BOM)
#   2. a `name:` key whose value equals the directory name
#   3. a non-empty `description:` (possibly a multi-line folded scalar) of <= 1024 chars
#   4. a closing "---" terminating the frontmatter block
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAILS=0
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }

MAX_DESC=1024

for skill_md in skills/*/SKILL.md; do
    dir=$(basename "$(dirname "$skill_md")")

    # 1. Line 1 must be exactly "---".
    first_line=$(sed -n '1p' "$skill_md")
    if [ "$first_line" != "---" ]; then
        fail "$dir: line 1 is not exactly '---' (got: '$first_line')"
        continue
    fi

    # Find the closing '---' (first line that is exactly '---' after line 1).
    close_line=$(awk 'NR>1 && $0=="---"{print NR; exit}' "$skill_md")
    if [ -z "$close_line" ]; then
        fail "$dir: no closing '---' for frontmatter"
        continue
    fi

    # Extract the frontmatter block (between the fences).
    fm=$(sed -n "2,$((close_line - 1))p" "$skill_md")

    # 2. name: must match the directory.
    name=$(printf '%s\n' "$fm" | sed -n -E 's/^name:[[:space:]]*//p' | head -1 | tr -d '\r')
    if [ -z "$name" ]; then
        fail "$dir: missing 'name:' key"
    elif [ "$name" != "$dir" ]; then
        fail "$dir: name '$name' does not match directory '$dir'"
    fi

    # 3. description: non-empty, <= MAX_DESC chars. Supports the multi-line folded form
    #    (description: on its own line, value on subsequent more-indented lines).
    desc=$(printf '%s\n' "$fm" | awk '
        /^description:/ {
            grab=1
            line=$0
            sub(/^description:[[:space:]]*/, "", line)
            if (line != "") printf "%s ", line
            next
        }
        grab==1 {
            # a new top-level key (no leading whitespace, contains a colon) ends the value
            if ($0 ~ /^[A-Za-z0-9_-]+:/) { grab=0; next }
            gsub(/^[[:space:]]+/, "", $0)
            if ($0 != "") printf "%s ", $0
        }
    ')
    desc=$(printf '%s' "$desc" | sed -E 's/[[:space:]]+$//')
    if [ -z "$desc" ]; then
        fail "$dir: empty 'description:'"
    else
        len=${#desc}
        if [ "$len" -gt "$MAX_DESC" ]; then
            fail "$dir: description is ${len} chars (> ${MAX_DESC})"
        fi
    fi
done

if [ "$FAILS" -gt 0 ]; then
    echo "frontmatter validation failed: $FAILS issue(s)"
    exit 1
fi
echo "all skill frontmatter valid"
exit 0
