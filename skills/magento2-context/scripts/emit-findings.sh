#!/usr/bin/env bash
# emit-findings.sh — shared emission tail for the audit build-findings.sh wrappers.
#
# Owns the JSON→(optional post-JSON hook)→SARIF pipeline that the six audit skills
# (security / performance / static-analysis / marketplace-prep / accessibility /
# breeze-compat) previously each inlined verbatim. Lives in the magento2-context hub
# alongside emit-json.sh / emit-sarif.sh / resolve-basename.sh so every findings skill
# reaches one canonical emitter instead of a sibling skill's scripts dir.
#
# A caller assembles its findings + scanner_errors JSON, sets the labelling env, and
# invokes this once. It:
#   1. runs emit-json.sh  → writes {OUTPUT_DIR}/{OUTPUT_BASENAME}.json
#   2. runs POST_JSON_HOOK (if set) with the JSON path — lets a skill inject extra
#      top-level fields (marketplace readiness score, security cve-status) BEFORE SARIF
#      so the injected fields land in JSON only, matching the prior per-skill behaviour.
#   3. runs emit-sarif.sh → writes the .sarif sibling, appending a `scanner_errors`
#      record when SARIF emission fails (never aborts the run).
#   4. echoes the final JSON document to stdout for callers that read it.
#
# Inputs (env vars):
#   FINDINGS_FILE        JSON array of findings (required; forwarded to emit-json.sh).
#   SCANNER_ERRORS_FILE  Optional JSON array of scanner errors (forwarded to emit-json.sh).
#   TARGET_MODULE        required (forwarded).
#   TARGET_PATH          required (forwarded).
#   SCOPE                "module" (default) | "site" | "diff" | "vendor" | "theme".
#   OUTPUT_DIR           required — destination dir for both .json and .sarif.
#   SKILL_NAME, SKILL_VERSION, OUTPUT_KIND, SKILL_VERSIONS_JSON   labelling (forwarded).
#   BASENAME_KIND        audit token for resolve-basename.sh (e.g. security, perf, quality,
#                        readiness, a11y, breeze-compat). Required unless OUTPUT_BASENAME is set.
#   OUTPUT_BASENAME      explicit basename; overrides BASENAME_KIND/resolve-basename.
#   DATE                 default: today (UTC); passed to resolve-basename.sh.
#   POST_JSON_HOOK       optional script path, invoked as `bash $POST_JSON_HOOK $JSON_FILE`.

set -uo pipefail

: "${FINDINGS_FILE:?FINDINGS_FILE is required}"
: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"
: "${OUTPUT_DIR:?OUTPUT_DIR is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_JSON="${SCRIPT_DIR}/emit-json.sh"
EMIT_SARIF="${SCRIPT_DIR}/emit-sarif.sh"
RESOLVE_BASENAME="${SCRIPT_DIR}/resolve-basename.sh"

if [ ! -f "$EMIT_JSON" ]; then
    echo "emit-findings: shared JSON emitter not found at $EMIT_JSON" >&2
    exit 2
fi

SCOPE="${SCOPE:-module}"
DATE="${DATE:-$(date -u +%Y-%m-%d)}"

# Resolve the output basename (explicit wins; else derive from the audit kind).
if [ -z "${OUTPUT_BASENAME:-}" ]; then
    : "${BASENAME_KIND:?BASENAME_KIND or OUTPUT_BASENAME is required}"
    if [ -f "$RESOLVE_BASENAME" ]; then
        OUTPUT_BASENAME="$(DATE="$DATE" SCOPE="$SCOPE" TARGET_MODULE="$TARGET_MODULE" \
            bash "$RESOLVE_BASENAME" "$BASENAME_KIND")"
    elif [ "$SCOPE" = "module" ]; then
        OUTPUT_BASENAME="${TARGET_MODULE}-${BASENAME_KIND}-${DATE}"
    else
        OUTPUT_BASENAME="${BASENAME_KIND}-${SCOPE}-${DATE}"
    fi
fi

export FINDINGS_FILE TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR OUTPUT_BASENAME
[ -n "${SCANNER_ERRORS_FILE:-}" ] && export SCANNER_ERRORS_FILE
# SKILL_NAME / SKILL_VERSION / OUTPUT_KIND / SKILL_VERSIONS_JSON are exported by the caller.

# JSON emission is fatal: if emit-json.sh fails (missing python3, invalid findings file, …) abort
# now with a clear cause rather than continuing and cat-ing a file that was never written. SARIF
# emission below stays non-fatal by design.
if ! bash "$EMIT_JSON" > /dev/null; then
    echo "emit-findings: emit-json.sh failed for '${OUTPUT_BASENAME}'" >&2
    exit 4
fi

OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}.json"
if [ ! -f "$OUTPUT_FILE" ]; then
    echo "emit-findings: expected JSON document not produced at $OUTPUT_FILE" >&2
    exit 4
fi

# Per-skill post-JSON injection (runs before SARIF so injected fields propagate to JSON only).
if [ -n "${POST_JSON_HOOK:-}" ] && [ -f "$POST_JSON_HOOK" ] && [ -f "$OUTPUT_FILE" ]; then
    bash "$POST_JSON_HOOK" "$OUTPUT_FILE" || true
fi

# SARIF alongside JSON; on failure, record it under scanner_errors rather than aborting.
SARIF_OUTPUT="${OUTPUT_DIR}/${OUTPUT_BASENAME}.sarif"
if [ -f "$EMIT_SARIF" ] && [ -f "$OUTPUT_FILE" ]; then
    SARIF_ERR="$(mktemp)"
    if ! bash "$EMIT_SARIF" "$OUTPUT_FILE" > "$SARIF_OUTPUT" 2> "$SARIF_ERR"; then
        python3 - "$OUTPUT_FILE" "$SARIF_ERR" <<'PY'
import json, os, sys
doc_path, err_path = sys.argv[1], sys.argv[2]
try:
    with open(doc_path) as fh:
        doc = json.load(fh)
    err = open(err_path).read().strip() if os.path.exists(err_path) else ""
    doc.setdefault("scanner_errors", []).append({
        "scanner": "emit-sarif",
        "stderr": err or "emit-sarif.sh failed with non-zero exit",
    })
    with open(doc_path, "w") as fh:
        json.dump(doc, fh, indent=2)
except Exception:
    pass
PY
    fi
    rm -f "$SARIF_ERR"
fi

# Echo the final JSON document for callers that read stdout.
cat "$OUTPUT_FILE"
