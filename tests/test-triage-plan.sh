#!/usr/bin/env bash
# test-triage-plan.sh — contract test for the triage plan builder.
#
# build-plan.sh must:
#   - route each confirmed finding to its owner and assign it a batch;
#   - order batches per the spec (upgrade → fix → structural → frontend → i18n →
#     test-generate → lint → docs);
#   - hold non-confirmed findings in verify_first[], never in a batch;
#   - put waived findings in waived[] and count them as neither routed nor closed;
#   - list unroutable findings in unrouted[] rather than defaulting them to fix;
#   - resolve its input from {DOCS_ROOT}/audits when INPUT_JSON is UNSET — the default
#     path is the one a user actually hits, so pinning only the explicit path would let
#     the discovery branch rot untested.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/triage/scripts/build-plan.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

work="$(mktemp -d "${TMPDIR:-/tmp}/m2-triage.XXXXXX")"
# The output must survive this trap — build-plan.sh writes under $work/.docs, which the
# test reads BEFORE returning. (Never print a path out of a trap'd dir; see the v2.2.0 RCA.)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/.docs/findings"
cat > "$work/.docs/findings/waivers.yml" <<'YAML'
version: 1
waivers:
  - fingerprint: "aaaa1111"
    finding: "security/csrf: known false positive"
    file: Controller/Ok.php
    verdict: false-positive
    reason: "Parent Action validates"
    author: s.autushka
YAML

INPUT="$PWD/tests/fixtures/triage/audit-sample.json"
OUT="$work/.docs/remediation/Acme_Test-plan-2026-09-16.json"

TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test \
DOCS_ROOT="$work/.docs" INPUT_JSON="$INPUT" RUN_DATE=2026-09-16 \
    bash "$SCRIPT" >/dev/null || { echo "FAIL: build-plan.sh exited non-zero"; exit 1; }

[ -f "$OUT" ] || { echo "FAIL: plan not written to $OUT"; exit 1; }

python3 - "$OUT" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
fail = 0

def err(msg):
    global fail
    print("FAIL: " + msg)
    fail = 1

if doc.get("outputKind") != "remediation":
    err(f"outputKind is {doc.get('outputKind')!r}, expected 'remediation'")

byfp = {f["fingerprint"]: f for f in doc.get("findings", [])}

# Specialist routing, not a blanket fall-through to fix.
if byfp.get("f0000000000000000000000000000000000000000000000000000000000000a1", {}).get("owner") != "extension-point":
    err("security/preference-collision did not route to extension-point")
if byfp.get("f0000000000000000000000000000000000000000000000000000000000000a2", {}).get("owner") != "indexer":
    err("perf-audit/indexer did not route to indexer")

# Confidence gate: a `candidate` finding may never sit in a batch.
vf = {f["fingerprint"] for f in doc.get("verify_first", [])}
if "f0000000000000000000000000000000000000000000000000000000000000a4" not in vf:
    err("a candidate-confidence finding was not held in verify_first")
if byfp.get("f0000000000000000000000000000000000000000000000000000000000000a4", {}).get("batch") is not None:
    err("a candidate-confidence finding was assigned a batch")

# Waived: reported, with its reason, and never routed.
waived = {f["fingerprint"]: f for f in doc.get("waived", [])}
if "aaaa1111" not in waived:
    err("the waived finding is missing from waived[]")
elif not waived["aaaa1111"].get("reason"):
    err("the waived finding lost its reason")
if "aaaa1111" in byfp and byfp["aaaa1111"].get("status") == "routable":
    err("a waived finding was routed")

# Unroutable: listed, never guessed.
un = {f["fingerprint"] for f in doc.get("unrouted", [])}
if "f0000000000000000000000000000000000000000000000000000000000000a6" not in un:
    err("an unknown category was not listed in unrouted[]")

# Batch ordering: lint runs last so it formats what the run produced.
owners = [b["owner"] for b in doc.get("batches", [])]
if "lint" in owners and owners[-1] != "lint":
    err(f"lint must be the last batch, got order {owners}")
if "extension-point" in owners and "lint" in owners:
    if owners.index("extension-point") > owners.index("lint"):
        err("structural work must precede lint")

sys.exit(fail)
PY
RC=$?

# --- the UNSET-INPUT_JSON default: newest {DOCS_ROOT}/audits/*-audit-*.json ---
# Exercised separately because a builder that only works when the caller pins the input
# is a builder whose documented default has never run.
if [ "$RC" -eq 0 ]; then
    mkdir -p "$work/.docs/audits"
    cp "$INPUT" "$work/.docs/audits/Acme_Test-audit-2026-09-16.json"
    rm -f "$OUT"

    TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test \
    DOCS_ROOT="$work/.docs" RUN_DATE=2026-09-16 \
        bash "$SCRIPT" >/dev/null || { echo "FAIL: build-plan.sh exited non-zero with INPUT_JSON unset"; exit 1; }

    if [ ! -f "$OUT" ]; then
        echo "FAIL: with INPUT_JSON unset, no plan was written to $OUT"
        RC=1
    else
        python3 - "$OUT" <<'PY' || RC=1
import json, sys
doc = json.load(open(sys.argv[1]))
owners = [b["owner"] for b in doc.get("batches", [])]
if owners != ["extension-point", "indexer", "lint"]:
    print(f"FAIL: default input discovery produced batches {owners}, "
          "expected ['extension-point', 'indexer', 'lint']")
    sys.exit(1)
if not doc.get("inputs"):
    print("FAIL: the plan does not record which document(s) it ingested")
    sys.exit(1)
sys.exit(0)
PY
    fi
fi

[ "$RC" -eq 0 ] && echo "PASS: triage plan routes, gates, waives and orders correctly"
exit "$RC"
