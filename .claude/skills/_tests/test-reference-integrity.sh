#!/usr/bin/env bash
# Reference integrity: any references/, templates/, or scripts/ path mentioned in
# a SKILL.md or reference markdown file must exist on disk.
#
# Scan scope (broadened in v5):
#   - .claude/skills/*/SKILL.md
#   - .claude/skills/*/references/*.md
#
# Matching:
#   - Backtick-quoted relative paths: `references/foo.md`, `templates/bar.php`, `scripts/baz.sh`.
#   - Placeholder-templated paths ({Module}, {Vendor}, ...) are skipped — they're docs.
#
# Out of scope:
#   - HTML/JSON template files (not reference docs).
#   - Path mentions outside backticks (too noisy; would generate false positives from
#     prose like "the file under scripts").
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

FAIL=0
while IFS= read -r doc; do
    skill_dir=""
    # Determine the owning skill directory so relative paths can be resolved against it.
    # SKILL.md lives at .claude/skills/<skill>/SKILL.md.
    # references/*.md live at .claude/skills/<skill>/references/<file>.md.
    case "$doc" in
        */SKILL.md)
            skill_dir="$(dirname "$doc")"
            ;;
        */references/*)
            # Walk up to the skill root.
            skill_dir="$(dirname "$(dirname "$doc")")"
            ;;
    esac
    [ -z "$skill_dir" ] && continue

    while IFS= read -r ref; do
        case "$ref" in
            *"{"*"}"*) continue ;;
        esac
        # First try resolving against the doc's owning skill.
        if [ -e "${skill_dir}/${ref}" ]; then
            continue
        fi
        # Fall back to any skill dir under .claude/skills/ — registry/cross-cutting docs
        # legitimately reference templates and references from other skills.
        if find .claude/skills -mindepth 2 -maxdepth 6 -path "*/${ref}" -print -quit | grep -q .; then
            continue
        fi
        echo "missing reference: ${ref} (in ${doc})"
        FAIL=1
    done < <(grep -oE '`(references|templates|scripts)/[A-Za-z0-9._/-]+`' "$doc" | sed 's/`//g' | sort -u)
done < <(find .claude/skills \( -name SKILL.md -o \( -path '*/references/*.md' \) \) -type f | sort)

exit "$FAIL"
