#!/usr/bin/env bash
# docs-path-matcher.sh — pure decision function for the .docs/ path guard.
#
#   docs_path_decide <project_root> <abs_path> <is_magento>   -> echoes "allow" | "deny"
#
# Inputs are pre-normalized: project_root has no trailing slash; abs_path is absolute and
# lexically normalized; is_magento is "yes" or "no". No I/O, no globals — directly testable.
# Fails OPEN (allow) on every branch except a fully-determined misplaced-.docs write.

docs_path_decide() {
    local root="$1" path="$2" is_magento="$3"

    # Scope gate: only Magento projects are governed by the .docs/ convention.
    [ "$is_magento" = "yes" ] || { printf 'allow\n'; return 0; }

    # Must be strictly inside the project root.
    case "$path" in
        "$root"/*) ;;
        *) printf 'allow\n'; return 0 ;;
    esac

    # Must contain a path segment exactly equal to ".docs".
    case "/$path/" in
        */.docs/*) ;;
        *) printf 'allow\n'; return 0 ;;
    esac

    # Canonical allowed location: {root}/.docs and anything beneath it.
    if [ "$path" = "$root/.docs" ]; then printf 'allow\n'; return 0; fi
    case "$path" in
        "$root"/.docs/*) printf 'allow\n'; return 0 ;;
    esac

    # Magento project, inside root, has a .docs segment, not the canonical one -> block.
    printf 'deny\n'
    return 0
}
