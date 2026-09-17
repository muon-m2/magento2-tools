#!/usr/bin/env bash
# waivers-lib.sh — triage suppression state, keyed on finding fingerprints.
#
# A waiver records a decision ALREADY taken about a finding: it is a false positive,
# an accepted risk, or won't be fixed. A waived finding is still reported (in the
# `waived` bucket, with its reason and author) — it is never silently dropped and it
# is never counted as closed.
#
# Sourced, not executed. Populates:
#   WAIVER_VERDICT[fp] WAIVER_REASON[fp] WAIVER_AUTHOR[fp] WAIVER_EXPIRES[fp]

# Consumers (triage's build-plan.sh, the closure diff) read these by name after
# sourcing this library, so shellcheck cannot see the use from here.
# shellcheck disable=SC2034
declare -gA WAIVER_VERDICT=()
declare -gA WAIVER_REASON=()
declare -gA WAIVER_AUTHOR=()
declare -gA WAIVER_EXPIRES=()

# waivers_load <path> — no file is a normal state, not an error.
waivers_load() {
    local path="$1"
    WAIVER_VERDICT=(); WAIVER_REASON=(); WAIVER_AUTHOR=(); WAIVER_EXPIRES=()
    [ -f "$path" ] || return 0

    local fp verdict reason author expires
    while IFS=$'\t' read -r fp verdict reason author expires; do
        [ -n "$fp" ] || continue
        WAIVER_VERDICT["$fp"]="$verdict"
        WAIVER_REASON["$fp"]="$reason"
        WAIVER_AUTHOR["$fp"]="$author"
        WAIVER_EXPIRES["$fp"]="$expires"
    done < <(python3 - "$path" <<'PY'
import sys
# Deliberately a minimal line parser: the waivers file is a fixed, flat shape and
# PyYAML is not a dependency of this repo.
fp = verdict = reason = author = expires = ""


def flush():
    if fp:
        print("\t".join([fp, verdict, reason, author, expires]))


for raw in open(sys.argv[1], encoding="utf-8"):
    line = raw.strip()
    if line.startswith("- fingerprint:"):
        flush()
        fp = line.split(":", 1)[1].strip().strip('"')
        verdict = reason = author = expires = ""
    elif line.startswith("verdict:"):
        verdict = line.split(":", 1)[1].strip().strip('"')
    elif line.startswith("reason:"):
        reason = line.split(":", 1)[1].strip().strip('"')
    elif line.startswith("author:"):
        author = line.split(":", 1)[1].strip().strip('"')
    elif line.startswith("expires:"):
        expires = line.split(":", 1)[1].strip().strip('"')
flush()
PY
    )
}

# waivers_status <fingerprint> <today YYYY-MM-DD> → active | expired | none
waivers_status() {
    local fp="$1" today="$2"
    if [ -z "${WAIVER_VERDICT[$fp]+set}" ]; then
        echo none
        return 0
    fi
    local exp="${WAIVER_EXPIRES[$fp]}"
    if [ -n "$exp" ] && [[ "$exp" < "$today" ]]; then
        # An expired waiver RESURFACES the finding. Suppression that outlives its own
        # deadline is how a deferred risk becomes a forgotten one.
        echo expired
        return 0
    fi
    echo active
}

# waivers_stale <current-fingerprint…> — prints loaded fingerprints matching nothing.
waivers_stale() {
    local fp cur present
    for fp in "${!WAIVER_VERDICT[@]}"; do
        present=0
        for cur in "$@"; do
            [ "$cur" = "$fp" ] && { present=1; break; }
        done
        [ "$present" -eq 0 ] && echo "$fp"
    done
    return 0
}

# waivers_check_ignored <path> — warn (stderr) if suppressions will not persist.
waivers_check_ignored() {
    local path="$1"
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    if git check-ignore -q "$path" 2>/dev/null; then
        echo "waivers: '$path' is gitignored — these suppressions are local only and will reset." >&2
        echo "waivers: commit the file, or relocate it with --waivers=<path> outside the ignored tree." >&2
        return 0
    fi
    if [ -f "$path" ] && ! git ls-files --error-unmatch "$path" >/dev/null 2>&1; then
        echo "waivers: '$path' is untracked — commit it so the team shares these decisions." >&2
    fi
    return 0
}
