#!/usr/bin/env bash
# compare-findings.sh — diff a re-run against its baseline and emit the closure document.
#
# `verification` has always been a required field on every finding that nothing ever executed.
# This is the run-level counterpart: re-audit, then diff by fingerprint so "we fixed it" is a
# measured claim rather than an optimistic one.
#
# Read-only with respect to the codebase: it reads two findings documents and writes a report.
# It never edits code — `audit` stays an auditor (see its Core Rules).
#
# Inputs (env vars):
#   BASELINE_JSON   findings document from BEFORE the remediation (required)
#   CURRENT_JSON    findings document from the re-run AFTER it (required)
#   TARGET_MODULE   e.g. "Acme_OrderExport" (required)
#   TARGET_PATH     e.g. "app/code/Acme/OrderExport" (required)
#   SCOPE           module (default) | site | vendor
#   DOCS_ROOT       artifact root; default .docs
#   OUTPUT_DIR      default {DOCS_ROOT}/audits
#   WAIVERS_FILE    default {DOCS_ROOT}/findings/waivers.yml
#   RUN_DATE        override the YYYY-MM-DD stamp (tests pin this)
#
# Output:
#   {OUTPUT_DIR}/{TARGET_MODULE}-closure-{date}.json   outputKind=closure
#   {OUTPUT_DIR}/{TARGET_MODULE}-closure-{date}.sarif
#
# Buckets (keyed by fingerprint):
#   closed      in baseline, absent now
#   still_open  in baseline, present now
#   waived      suppressed by waivers.yml — never counted as closed
#   regressed   absent from baseline, present now — introduced by the remediation
#   skipped     raised by a scanner that could not be trusted on the re-run; NEVER closed
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_SCRIPTS="${SCRIPT_DIR}/../../context/scripts"

: "${BASELINE_JSON:?BASELINE_JSON is required}"
: "${CURRENT_JSON:?CURRENT_JSON is required}"
: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

for f in "$BASELINE_JSON" "$CURRENT_JSON"; do
    [ -f "$f" ] || { echo "compare-findings: not found: $f" >&2; exit 2; }
done

command -v python3 >/dev/null 2>&1 || { echo "compare-findings: python3 required" >&2; exit 2; }

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
WAIVERS_FILE="${WAIVERS_FILE:-${DOCS_ROOT}/findings/waivers.yml}"
DATE="${RUN_DATE:-$(date -u +%Y-%m-%d)}"

EMIT_FINDINGS="${CONTEXT_SCRIPTS}/emit-findings.sh"
[ -f "$EMIT_FINDINGS" ] || { echo "compare-findings: emitter not found at $EMIT_FINDINGS" >&2; exit 2; }

SKILL_VERSION="$(awk '/^---$/{c++; next} c==1 && /^version:/{print $2; exit}' \
    "${SCRIPT_DIR}/../SKILL.md")"
SKILL_VERSION="${SKILL_VERSION:-1.1.0}"

# Resolve active waivers into a plain fingerprint list the python step can read. Sourced
# rather than reimplemented so suppression semantics (expiry, verdicts) live in one place.
WAIVED_FPS=""
# shellcheck source=/dev/null
if [ -f "${CONTEXT_SCRIPTS}/waivers-lib.sh" ]; then
    source "${CONTEXT_SCRIPTS}/waivers-lib.sh"
    waivers_load "$WAIVERS_FILE"
    waivers_check_ignored "$WAIVERS_FILE"
    for _fp in "${!WAIVER_VERDICT[@]}"; do
        if [ "$(waivers_status "$_fp" "$DATE")" = "active" ]; then
            WAIVED_FPS="${WAIVED_FPS}${_fp}"$'\n'
        fi
    done
fi

# The caller reads these after we return, so they must NOT live under a trap-cleaned dir.
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FINDINGS_FILE="${TMP_DIR}/findings.json"
META_FILE="${TMP_DIR}/meta.json"
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"

BASELINE_JSON="$BASELINE_JSON" CURRENT_JSON="$CURRENT_JSON" \
WAIVED_FPS="$WAIVED_FPS" FINDINGS_FILE="$FINDINGS_FILE" META_FILE="$META_FILE" \
FINDINGS_LIB="${CONTEXT_SCRIPTS}/findings-lib.sh" \
SCANNER_ERRORS_FILE="$SCANNER_ERRORS_FILE" python3 <<'PY'
import json
import os
import subprocess
import sys


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


base = load(os.environ["BASELINE_JSON"])
cur = load(os.environ["CURRENT_JSON"])

for name, doc in (("baseline", base), ("current", cur)):
    major = str(doc.get("schemaVersion", "1.0")).split(".")[0]
    if major != "1":
        sys.stderr.write(
            f"compare-findings: {name} document is schemaVersion "
            f"{doc.get('schemaVersion')!r}; only major version 1 is supported\n")
        sys.exit(3)


scanner_errors = []


def producer(finding, doc):
    for tag in finding.get("tags") or []:
        if isinstance(tag, str) and tag.startswith("producer:"):
            return tag.split(":", 1)[1]
    return doc.get("skill", "")


def fingerprint_of(producer, f):
    """Recompute identity for a finding that carries none (a pre-1.1 document).

    Shelling out to findings-lib.sh's finding_fingerprint is deliberate: a second
    normalizer written here would diverge from the emitter's on exactly the whitespace
    and trailing-separator cases the fingerprint exists to survive.
    """
    lib = os.environ.get("FINDINGS_LIB", "")
    if not lib or not os.path.exists(lib):
        return ""
    ev = (f.get("evidence") or [{}])[0]
    proc = subprocess.run(
        ["bash", "-c",
         'source "$1"; finding_fingerprint "$2" "$3" "$4" "$5" "$6" "$7"',
         "compare-findings", lib, producer,
         f.get("category", ""), f.get("subcategory", "") or "",
         f.get("title", ""), ev.get("file", ""), ev.get("snippet", "") or ""],
        capture_output=True, text=True, stdin=subprocess.DEVNULL,
    )
    return proc.stdout.strip()


def by_fp(doc):
    """Index findings by fingerprint, recomputing it when absent.

    Indexing ONLY on a present fingerprint would make a pre-1.1 baseline look like zero
    findings, so every one of them would silently read as `closed`. Absence of identity
    is not evidence of a fix.
    """
    out = {}
    for f in doc.get("findings") or []:
        fp = f.get("fingerprint") or fingerprint_of(producer(f, doc), f)
        if fp:
            out[fp] = f
        else:
            # Still not identifiable: report it rather than dropping it, so the count
            # never silently shrinks.
            unidentifiable.append(f.get("id", "<no id>"))
    return out


unidentifiable = []

base_f = by_fp(base)
cur_f = by_fp(cur)

if unidentifiable:
    scanner_errors.append({
        "scanner": "closure-diff",
        "stderr": "findings with no computable fingerprint were excluded from the diff: "
                  + ", ".join(unidentifiable),
    })

# A scanner is untrustworthy on this run if it crashed, or if `tools` marks it degraded or
# skipped. Its findings can never be reported closed: absence of a result is not a result.
# This is the same discipline `scanner_errors` already encodes per-document.
untrusted = {e.get("scanner") for e in (cur.get("scanner_errors") or []) if e.get("scanner")}
for tool, status in (cur.get("tools") or {}).items():
    if status in ("degraded", "skipped", "unavailable"):
        untrusted.add(tool)

waived = {fp for fp in os.environ.get("WAIVED_FPS", "").split("\n") if fp}

closure = {"closed": [], "still_open": [], "waived": [], "regressed": [], "skipped": []}
actionable = []

for fp, f in base_f.items():
    if fp in waived:
        closure["waived"].append(fp)
    elif producer(f, base) in untrusted:
        closure["skipped"].append(fp)
    elif fp in cur_f:
        closure["still_open"].append(fp)
        actionable.append(dict(cur_f[fp], closure_state="still_open"))
    else:
        closure["closed"].append(fp)

for fp, f in cur_f.items():
    if fp in base_f or fp in waived:
        continue
    closure["regressed"].append(fp)
    actionable.append(dict(f, closure_state="regressed"))

for k in closure:
    closure[k].sort()

with open(os.environ["FINDINGS_FILE"], "w", encoding="utf-8") as fh:
    json.dump(actionable, fh, indent=2)

with open(os.environ["SCANNER_ERRORS_FILE"], "w", encoding="utf-8") as fh:
    json.dump((cur.get("scanner_errors") or []) + scanner_errors, fh, indent=2)

with open(os.environ["META_FILE"], "w", encoding="utf-8") as fh:
    json.dump({
        "closure": closure,
        "verdict_delta": {"from": base.get("audit_verdict"), "to": cur.get("audit_verdict")},
        "score_delta": {"from": base.get("audit_score"), "to": cur.get("audit_score")},
        "baseline_report": os.environ["BASELINE_JSON"],
    }, fh, indent=2)
PY

diff_rc=$?
if [ "$diff_rc" -ne 0 ] || [ ! -f "$FINDINGS_FILE" ]; then
    # Fatal on purpose: a partial or empty closure document would read as "everything closed".
    echo "compare-findings: diff step failed (rc=$diff_rc)" >&2
    exit 4
fi

export FINDINGS_FILE SCANNER_ERRORS_FILE META_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="audit"
export SKILL_VERSION
export OUTPUT_KIND="closure"
export SKILL_VERSIONS_JSON="[\"audit@${SKILL_VERSION}\",\"context@1.15.0\"]"

DATE="$DATE" BASENAME_KIND="closure" \
POST_JSON_HOOK="${SCRIPT_DIR}/audit-verdict.sh" \
    bash "$EMIT_FINDINGS"
