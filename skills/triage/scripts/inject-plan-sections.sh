#!/usr/bin/env bash
# inject-plan-sections.sh — POST_JSON_HOOK for emit-findings.sh.
#
# The shared emitter owns the findings envelope; the four remediation buckets
# (batches / waived / verify_first / unrouted, plus stale_waivers and the ingested
# inputs) are `outputKind=remediation`'s own top-level additions. They are injected here,
# between JSON and SARIF, exactly like marketplace's readiness score — so they land in the
# JSON document without pretending to be SARIF results.
#
# Usage: bash inject-plan-sections.sh <emitted.json>
# Env:   TRIAGE_PLAN_SECTIONS — path to the JSON object holding the sections.

set -uo pipefail

JSON_FILE="${1:?inject-plan-sections: emitted JSON path is required}"
: "${TRIAGE_PLAN_SECTIONS:?TRIAGE_PLAN_SECTIONS is required}"

command -v python3 >/dev/null 2>&1 || {
    echo "inject-plan-sections: python3 required" >&2
    exit 2
}

python3 - "$JSON_FILE" "$TRIAGE_PLAN_SECTIONS" <<'PY'
import json
import sys

doc_path, sections_path = sys.argv[1], sys.argv[2]

with open(doc_path, encoding="utf-8") as fh:
    doc = json.load(fh)
with open(sections_path, encoding="utf-8") as fh:
    sections = json.load(fh)

# Required by findings-schema.md's `outputKind=remediation`: present even when empty, so a
# consumer never has to distinguish "no waivers" from "this producer forgot the field".
for key in ("inputs", "batches", "waived", "verify_first", "unrouted", "stale_waivers"):
    doc[key] = sections.get(key, [])

with open(doc_path, "w", encoding="utf-8") as fh:
    json.dump(doc, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
PY
