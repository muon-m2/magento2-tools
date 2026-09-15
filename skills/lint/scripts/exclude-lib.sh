#!/usr/bin/env bash
# exclude-lib.sh — the directories lint's scanners and fixers must never descend into, as a
# comma-separated pattern list ANCHORED at the scan target. Sourced by run-analysis.sh and
# apply-fixes.sh.
#
#   lint_exclude_pattern <target-path> [<runner-prefix>]
#
# Why anchored. The list used to be free-floating globs — `*/vendor/*,*/generated/*,*/var/*,
# */pub/static/*` — and both tools that consume it match far more than the target's own subtree:
#   * PHP_CodeSniffer (`--ignore`, for phpcs and phpcbf) turns `*` into `.*` and runs the result as
#     an UNANCHORED regex against each file's realpath (Filters/Filter.php::shouldIgnorePath);
#   * PHPMD (`--exclude`, through pdepend's ExcludePathFilter) tests each pattern unanchored against
#     the target-local path AND ^-anchored against the realpath.
# So `*/var/*` matched every file under a Docker image's install root /var/www/magento, and
# `*/vendor/*` every file of a Composer-installed module. The tools scanned 0 files and the pass
# read as clean — measured in a Magento 2.4.9 container: phpcs scanned 0 files with the old globs
# and 23 with anchored ones.
#
# Why the realpath. Both tools compare against the realpath as THEY see it, which inside a container
# is not the host's path. The target is resolved through the runner's own PHP — the same
# `$RUNNER php -r` probe run-analysis.sh already makes for rector — or with `pwd -P` when there is no
# runner. If neither resolves it, the target string itself is the anchor; both tools match it as a
# substring, so it still excludes the right subtree for any target spelled the way the tool is given it.

lint_exclude_pattern() {
    local target="${1%/}" runner="${2:-}" anchor="" name out=""
    [ -n "$target" ] || target="."
    if [ -n "$runner" ]; then
        # shellcheck disable=SC2086  # the runner prefix is intentionally word-split
        anchor="$($runner php -r 'echo (string) realpath($argv[1]);' -- "$target" 2>/dev/null </dev/null)"
    elif [ -d "$target" ]; then
        anchor="$(cd "$target" 2>/dev/null && pwd -P)"
    fi
    anchor="${anchor:-$target}"
    anchor="${anchor%/}"
    for name in vendor generated var pub/static; do
        out="${out:+${out},}${anchor}/${name}/*"
    done
    printf '%s' "$out"
}
