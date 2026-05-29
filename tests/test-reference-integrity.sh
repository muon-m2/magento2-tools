#!/usr/bin/env bash
# Reference integrity: any references/, templates/, or scripts/ path mentioned in
# a SKILL.md or reference markdown file must exist on disk.
#
# Scan scope (broadened in v5):
#   - skills/*/SKILL.md
#   - skills/*/references/*.md
#
# Matching:
#   - Backtick-quoted relative paths: `references/foo.md`, `templates/bar.php`, `scripts/baz.sh`.
#   - Plugin-var paths: `${CLAUDE_SKILL_DIR}/scripts/baz.sh` (resolved against the owning
#     skill) and `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/...` (resolved against the repo root).
#   - Placeholder-templated paths ({Module}, {Vendor}, ...) are skipped — they're docs.
#
# Out of scope:
#   - HTML/JSON template files (not reference docs).
#   - Path mentions outside backticks (too noisy; would generate false positives from
#     prose like "the file under scripts").
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FAIL=0
while IFS= read -r doc; do
    skill_dir=""
    # Determine the owning skill directory so relative paths can be resolved against it.
    # SKILL.md lives at skills/<skill>/SKILL.md.
    # references/*.md live at skills/<skill>/references/<file>.md.
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
        # Resolve plugin-var prefixes first (they contain literal { } that would
        # otherwise be mistaken for {Module}-style doc placeholders).
        case "$ref" in
            '${CLAUDE_SKILL_DIR}/'*)
                rel="${ref#'${CLAUDE_SKILL_DIR}/'}"
                target="${skill_dir}/${rel}"
                ;;
            '${CLAUDE_PLUGIN_ROOT}/'*)
                rel="${ref#'${CLAUDE_PLUGIN_ROOT}/'}"
                target="./${rel}"
                ;;
            *"{"*"}"*)
                continue   # placeholder-templated doc path
                ;;
            *)
                rel="$ref"
                target="${skill_dir}/${ref}"
                ;;
        esac
        # First try the direct resolution above.
        if [ -e "$target" ]; then
            continue
        fi
        # Fall back to any skill dir under skills/ — registry/cross-cutting docs
        # legitimately reference templates and references from other skills.
        if find skills -mindepth 2 -maxdepth 6 -path "*/${rel}" -print -quit | grep -q .; then
            continue
        fi
        echo "missing reference: ${ref} (in ${doc})"
        FAIL=1
    done < <(grep -oE '`(\$\{CLAUDE_SKILL_DIR\}/|\$\{CLAUDE_PLUGIN_ROOT\}/)?(references|templates|scripts|skills)/[A-Za-z0-9._/-]+`' "$doc" | sed 's/`//g' | sort -u)
done < <(find skills \( -name SKILL.md -o \( -path '*/references/*.md' \) \) -type f | sort)

exit "$FAIL"
