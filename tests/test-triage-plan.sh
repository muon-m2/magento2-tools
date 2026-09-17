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

# --- phase 3: SARIF input ---------------------------------------------------------------
# SARIF is a lossy carrier — no confidence, recommendation or verification — so every
# finding read from one must be held in verify_first and may NEVER reach a batch.
#
# The fixture below deliberately carries an evidence SNIPPET. The snippet is an input to the
# fingerprint but is NOT representable in SARIF, so recomputing identity on the SARIF side
# yields a DIFFERENT value. That makes this a real test of `partialFingerprints`: if the
# emitter stops writing it, or the reader stops reading it, the waiver below stops matching
# and this phase fails. (Without a snippet the recompute fallback coincidentally agrees, and
# the assertion would pass against a broken reader.)
swork="$(mktemp -d "${TMPDIR:-/tmp}/m2-triage-sarif.XXXXXX")"
cat > "$swork/findings.json" <<'JSON'
[
  {
    "id": "SNIP-001",
    "severity": "high",
    "category": "csrf",
    "title": "POST controller missing form key validation",
    "evidence": [
      { "file": "Controller/Adminhtml/Order/Save.php", "line": 47,
        "snippet": "public function execute()  ;" }
    ],
    "recommendation": "Implement HttpPostActionInterface.",
    "verification": "re-run review"
  }
]
JSON

FINDINGS_FILE="$swork/findings.json" TARGET_MODULE=Acme_Test \
TARGET_PATH=app/code/Acme/Test SCOPE=module OUTPUT_DIR="$swork/out" \
SKILL_NAME=security SKILL_VERSION=9.9.9 OUTPUT_KIND=security \
BASENAME_KIND=security DATE=2026-09-16 \
    bash skills/context/scripts/emit-findings.sh >/dev/null 2>&1

PAIR_JSON="$swork/out/Acme_Test-security-2026-09-16.json"
PAIR_SARIF="$swork/out/Acme_Test-security-2026-09-16.sarif"

if [ ! -f "$PAIR_SARIF" ] || [ ! -f "$PAIR_JSON" ]; then
    echo "FAIL: could not emit a JSON+SARIF pair to test SARIF ingestion"
    RC=1
else
    # Waive by the fingerprint the JSON carries...
    WFP="$(python3 -c "
import json, sys
print(json.load(open(sys.argv[1]))['findings'][0]['fingerprint'])
" "$PAIR_JSON")"

    # ...and assert it is NOT reachable by recomputation from SARIF alone, so the phase
    # cannot pass by coincidence.
    RECOMP="$(bash -c '
source skills/context/scripts/findings-lib.sh
finding_fingerprint security csrf "" "POST controller missing form key validation" \
    "Controller/Adminhtml/Order/Save.php" ""')"
    if [ "$WFP" = "$RECOMP" ]; then
        echo "FAIL: fixture is degenerate — the snippet-less recompute matches the real"
        echo "      fingerprint, so this phase would pass even with partialFingerprints broken"
        RC=1
    fi

    mkdir -p "$swork/.docs/findings"
    cat > "$swork/.docs/findings/waivers.yml" <<YAML
version: 1
waivers:
  - fingerprint: "$WFP"
    finding: "waived via the JSON report"
    file: Controller/Adminhtml/Order/Save.php
    verdict: accepted-risk
    reason: "Round-trip check"
    author: tester
YAML

    TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test DOCS_ROOT="$swork/.docs" \
    INPUT_JSON="$PAIR_SARIF" RUN_DATE=2026-09-16 \
        bash "$SCRIPT" >/dev/null 2>&1

    SOUT="$swork/.docs/remediation/Acme_Test-plan-2026-09-16.json"
    if [ ! -f "$SOUT" ]; then
        echo "FAIL: triage did not produce a plan from a SARIF input"
        RC=1
    else
        WFP="$WFP" python3 - "$SOUT" <<'PY' || RC=1
import json, os, sys
doc = json.load(open(sys.argv[1]))
fail = 0
if doc.get("batches"):
    print(f"FAIL: SARIF findings reached a batch ({doc['batches']}); they carry no "
          "confidence and must stay in verify_first")
    fail = 1
waived = {f.get("fingerprint") for f in doc.get("waived", [])}
if os.environ["WFP"] not in waived:
    print("FAIL: a waiver written against the JSON report did not match the same finding "
          "read back from SARIF — partialFingerprints is not round-tripping")
    fail = 1
sys.exit(fail)
PY
    fi
fi
rm -rf "$swork"

[ "$RC" -eq 0 ] && echo "PASS: triage routes, gates, waives, orders, and ingests SARIF"
exit "$RC"
