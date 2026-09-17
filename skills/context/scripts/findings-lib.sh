#!/usr/bin/env bash
# findings-lib.sh — the ONE shared engine behind every audit skill's build-findings.sh.
#
# Each audit skill keeps a thin build-findings.sh entry point (its documented env-var
# interface is unchanged) that sources this library and declares only what differs:
# which scanners run, and how the output is labelled. Everything the six former copies
# duplicated lives here once: scanner execution with JSON validation, per-scanner
# stderr capture into scanner_errors, findings merge, and the hand-off to
# emit-findings.sh.
#
# Usage (from a skill's scripts/build-findings.sh):
#
#   source "${SCRIPT_DIR}/../../context/scripts/findings-lib.sh"
#   findings_init                                # validates TARGET_MODULE/TARGET_PATH,
#                                                # sets TMP_DIR (trap'd) + EMIT_FINDINGS
#   findings_scan <name> <script> [args…]        # run one scanner, register its output
#   findings_register <name> <out.json> <err>    # register an externally produced output
#   findings_emit [extra-findings.json…]         # scanner_errors + merge + emit
#
# The wrapper must export/set before findings_emit:
#   SKILL_NAME, SKILL_VERSION, OUTPUT_KIND, BASENAME_KIND, OUTPUT_DIR
# Optional: POST_JSON_HOOK (forwarded to emit-findings.sh).
#
# scanner_errors contract (unchanged from the former copies): one entry per scanner
# whose stderr file is non-empty; a non-zero exit or invalid JSON downgrades that
# scanner's findings to [] and records why, so "scanner crashed" is never conflated
# with "scanner found nothing".

# Version stamped into SKILL_VERSIONS_JSON for the shared context canon — read from
# context's own SKILL.md frontmatter so it can never drift (the former
# copies each hardcoded it).
_findings_lib_context_version() {
    awk '/^---$/{c++; next} c==1 && /^version:/{print $2; exit}' \
        "$(dirname "${BASH_SOURCE[0]}")/../SKILL.md"
}
FINDINGS_LIB_CONTEXT_VERSION="$(_findings_lib_context_version)"
if [ -z "$FINDINGS_LIB_CONTEXT_VERSION" ]; then
    echo "findings-lib: could not read version from context/SKILL.md frontmatter" >&2
    exit 2
fi

_FINDINGS_NAMES=()
_FINDINGS_OUTS=()
_FINDINGS_ERRS=()

# _sha256 — portable digest over stdin. Linux has sha256sum; macOS ships shasum.
_sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | cut -d' ' -f1
    else
        # Fail loudly. Returning empty here would hand callers an unfingerprintable
        # finding, which downstream reads as "no identity" — waivers stop matching and
        # a closure diff cannot tell a fixed finding from an unidentifiable one.
        echo "findings-lib: no SHA-256 tool found (need sha256sum or shasum)" >&2
        return 3
    fi
}

# finding_fingerprint <producer> <category> <subcategory> <title> <file> <snippet>
#
# Stable identity for one finding ACROSS runs. `finding.id` is regenerated every run
# ({skill}-{date}-{seq}) and evidence[].line moves the moment the file is patched, so
# neither can carry a decision (a waiver, a closure verdict) forward. Line number and
# run date are therefore deliberately NOT inputs.
finding_fingerprint() {
    local producer="$1" category="$2" subcategory="$3" title="$4" file="$5" snippet="$6"
    local norm
    # Collapse whitespace runs and strip trailing separators so reformatting the
    # source does not change a finding's identity.
    norm="$(printf '%s' "$snippet" \
        | tr '\n\t' '  ' \
        | tr -s ' ' \
        | sed 's/^ *//; s/ *$//; s/[,;]*$//; s/ *$//')"
    printf '%s|%s|%s|%s|%s|%s' \
        "$producer" "$category" "$subcategory" "$title" "$file" "$norm" | _sha256
}

findings_init() {
    : "${TARGET_MODULE:?TARGET_MODULE is required}"
    : "${TARGET_PATH:?TARGET_PATH is required}"

    # The directory of the *sourcing* wrapper is already in SCRIPT_DIR; resolve the
    # shared emitter relative to this library so every skill agrees on one path.
    _FINDINGS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EMIT_FINDINGS="${_FINDINGS_LIB_DIR}/emit-findings.sh"
    if [ ! -f "$EMIT_FINDINGS" ]; then
        echo "build-findings: shared emitter not found at $EMIT_FINDINGS" >&2
        exit 2
    fi

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
}

# findings_scan <name> <script> [args…]
# Runs the scanner, capturing stdout to $TMP_DIR/<name>.json and stderr to
# $TMP_DIR/<name>.err. Non-zero exit or invalid JSON falls back to [] and is
# recorded in the .err file. Registers the scanner for scanner_errors + merge.
# Returns the scanner's success (0) or failure (1) so callers may react, but the
# conventional call site ignores it: `findings_scan foo foo.sh || true`.
findings_scan() {
    local name="$1" script="$2"; shift 2
    local out="${TMP_DIR}/${name}.json" err="${TMP_DIR}/${name}.err"
    local rc=0
    if ! bash "$script" "$@" > "$out" 2> "$err"; then
        echo "$name: scanner returned non-zero exit" >> "$err"
        echo "[]" > "$out"
        rc=1
    elif ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$out" 2>/dev/null; then
        echo "$name: produced invalid JSON" >> "$err"
        echo "[]" > "$out"
        rc=1
    fi
    _FINDINGS_NAMES+=("$name")
    _FINDINGS_OUTS+=("$out")
    _FINDINGS_ERRS+=("$err")
    return "$rc"
}

# findings_register <name> <out.json> <err-file>
# For scanners the wrapper had to run itself (non-standard invocation). Validates the
# JSON (downgrading to [] on failure, recorded in <err-file>) and registers the pair.
findings_register() {
    local name="$1" out="$2" err="$3"
    if [ ! -f "$out" ]; then
        echo "[]" > "$out"
        echo "$name: findings file not produced" >> "$err"
    elif ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$out" 2>/dev/null; then
        echo "$name: produced invalid JSON" >> "$err"
        echo "[]" > "$out"
    fi
    _FINDINGS_NAMES+=("$name")
    _FINDINGS_OUTS+=("$out")
    _FINDINGS_ERRS+=("$err")
}

# findings_emit [extra-findings.json…]
# Builds scanner_errors from every registered scanner, merges every registered output
# (plus any extra findings files passed as arguments) into one array, then emits the
# unified document (JSON + SARIF) via emit-findings.sh.
findings_emit() {
    : "${SKILL_NAME:?SKILL_NAME is required}"
    : "${SKILL_VERSION:?SKILL_VERSION is required}"
    : "${OUTPUT_KIND:?OUTPUT_KIND is required}"
    : "${BASENAME_KIND:?BASENAME_KIND is required}"

    # (name, err-file) pairs travel via argv — NOT stdin — because the heredoc that
    # carries the program already owns stdin; a pipe here would be silently discarded.
    local _pairs=()
    local i
    for i in "${!_FINDINGS_NAMES[@]}"; do
        _pairs+=("${_FINDINGS_NAMES[$i]}" "${_FINDINGS_ERRS[$i]}")
    done
    SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
    python3 - "${_pairs[@]}" > "$SCANNER_ERRORS_FILE" <<'PY'
import json
import os
import sys

args = sys.argv[1:]
errors = []
for i in range(0, len(args) - 1, 2):
    name, path = args[i], args[i + 1]
    if os.path.exists(path) and os.path.getsize(path) > 0:
        text = open(path, encoding='utf-8', errors='replace').read().strip()
        if text:
            errors.append({'scanner': name, 'stderr': text})
print(json.dumps(errors, indent=2))
PY

    FINDINGS_FILE="${TMP_DIR}/findings.json"
    python3 - "${_FINDINGS_OUTS[@]}" "$@" > "$FINDINGS_FILE" <<'PY'
import json
import sys

merged = []
for path in sys.argv[1:]:
    try:
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        if isinstance(data, list):
            merged.extend(data)
    except Exception:
        continue

print(json.dumps(merged, indent=2))
PY

    export FINDINGS_FILE SCANNER_ERRORS_FILE
    export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
    export SKILL_NAME SKILL_VERSION OUTPUT_KIND
    export SKILL_VERSIONS_JSON="[\"${SKILL_NAME}@${SKILL_VERSION}\",\"context@${FINDINGS_LIB_CONTEXT_VERSION}\"]"

    BASENAME_KIND="$BASENAME_KIND" bash "$EMIT_FINDINGS"
}
