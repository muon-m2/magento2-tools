#!/usr/bin/env bash
# test-audit-compare.sh — contract test for the closure diff.
#
# compare-findings.sh must classify every baseline finding, and in particular must:
#   - mark a finding present in the baseline and absent now as `closed`;
#   - mark a finding present in BOTH as `still_open`;
#   - mark a finding absent from the baseline but present now as `regressed`
#     (the remediation introduced it) — this is the class nothing catches today;
#   - never count a dimension that failed to re-run as `closed`.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

SCRIPT="skills/audit/scripts/compare-findings.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }

work="$(mktemp -d "${TMPDIR:-/tmp}/m2-compare.XXXXXX")"
trap 'rm -rf "$work"' EXIT

mk() { # mk <file> <verdict> <score> <fingerprint…>
    local out="$1" verdict="$2" score="$3"; shift 3
    python3 - "$out" "$verdict" "$score" "$@" <<'PY'
import json, sys
out, verdict, score, *fps = sys.argv[1:]
json.dump({
    "schemaVersion": "1.1", "skill": "audit", "skillVersion": "1.0.0",
    "skillVersions": ["audit@1.0.0"], "outputKind": "audit",
    "target": {"module": "Acme_Test", "path": "app/code/Acme/Test", "scope": "module"},
    "runAt": "2026-09-16T10:00:00Z", "mode": "full", "context": {},
    "audit_verdict": verdict, "audit_score": int(score),
    "summary": {"total": len(fps), "bySeverity": {}, "byCategory": {}},
    "findings": [{"id": f"x{i}", "fingerprint": fp, "severity": "high",
                  "category": "csrf", "title": f"t{i}",
                  "evidence": [{"file": "A.php", "line": 1}],
                  "recommendation": "r", "verification": "v",
                  "tags": ["producer:security"]}
                 for i, fp in enumerate(fps)],
    "skipped": [], "scanner_errors": [], "tools": {"phpcs": "executed", "security": "executed"},
}, open(out, "w"))
PY
}

# baseline: aa, bb, cc      current: bb, dd
#   aa → closed      bb → still_open      cc → closed      dd → REGRESSED
mk "$work/base.json" FAIL 41 aa bb cc
mk "$work/cur.json"  CONDITIONAL 78 bb dd

BASELINE_JSON="$work/base.json" CURRENT_JSON="$work/cur.json" \
DOCS_ROOT="$work/.docs" TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test \
RUN_DATE=2026-09-16 bash "$SCRIPT" || { echo "FAIL: compare exited non-zero"; exit 1; }

OUT="$work/.docs/audits/Acme_Test-closure-2026-09-16.json"
[ -f "$OUT" ] || { echo "FAIL: closure document not written to $OUT"; exit 1; }

python3 - "$OUT" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
c = doc.get("closure", {})
fail = 0

def want(bucket, fps):
    global fail
    got = sorted(c.get(bucket, []))
    if got != sorted(fps):
        print(f"FAIL: closure.{bucket} = {got}, expected {sorted(fps)}")
        fail = 1

if doc.get("outputKind") != "closure":
    print(f"FAIL: outputKind = {doc.get('outputKind')!r}, expected 'closure'")
    fail = 1

want("closed", ["aa", "cc"])
want("still_open", ["bb"])
want("regressed", ["dd"])

if doc.get("verdict_delta") != {"from": "FAIL", "to": "CONDITIONAL"}:
    print(f"FAIL: verdict_delta = {doc.get('verdict_delta')}")
    fail = 1
if doc.get("score_delta") != {"from": 41, "to": 78}:
    print(f"FAIL: score_delta = {doc.get('score_delta')}")
    fail = 1
sys.exit(fail)
PY
RC=$?

# A waived finding must land in `waived`, not `still_open` — it is not a remediation failure.
mkdir -p "$work/.docs/findings"
cat > "$work/.docs/findings/waivers.yml" <<'YAML'
version: 1
waivers:
  - fingerprint: "bb"
    finding: "accepted risk"
    file: A.php
    verdict: accepted-risk
    reason: "Compensating control in the parent Action"
    author: s.autushka
YAML

BASELINE_JSON="$work/base.json" CURRENT_JSON="$work/cur.json" \
DOCS_ROOT="$work/.docs" TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test \
RUN_DATE=2026-09-17 bash "$SCRIPT" >/dev/null

python3 - "$work/.docs/audits/Acme_Test-closure-2026-09-17.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1])).get("closure", {})
if "bb" in c.get("still_open", []):
    print("FAIL: a waived finding was reported still_open")
    sys.exit(1)
if "bb" not in c.get("waived", []):
    print(f"FAIL: waived finding missing from closure.waived (got {c.get('waived')})")
    sys.exit(1)
sys.exit(0)
PY
RC3=$?

# A dimension that could not be re-run must NOT let its findings read as closed.
python3 - "$work/cur.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
doc["scanner_errors"] = [{"scanner": "security", "stderr": "crashed"}]
doc["tools"]["security"] = "degraded"
json.dump(doc, open(sys.argv[1], "w"))
PY

BASELINE_JSON="$work/base.json" CURRENT_JSON="$work/cur.json" \
DOCS_ROOT="$work/.docs2" TARGET_MODULE=Acme_Test TARGET_PATH=app/code/Acme/Test \
RUN_DATE=2026-09-16 bash "$SCRIPT" >/dev/null

python3 - "$work/.docs2/audits/Acme_Test-closure-2026-09-16.json" <<'PY'
import json, sys
c = json.load(open(sys.argv[1])).get("closure", {})
if not c.get("skipped"):
    print("FAIL: a degraded scanner produced no closure.skipped entry — its findings would read as closed")
    sys.exit(1)
# The degraded scanner is `security`, which produced every baseline finding here, so
# nothing it raised may be reported closed on this run.
if c.get("closed"):
    print(f"FAIL: findings from a degraded scanner were reported closed: {c['closed']}")
    sys.exit(1)
sys.exit(0)
PY
RC2=$?

if [ "$RC" -eq 0 ] && [ "$RC2" -eq 0 ] && [ "$RC3" -eq 0 ]; then
    echo "PASS: closure diff classifies closed/still-open/waived/regressed/skipped"
    exit 0
fi
exit 1
