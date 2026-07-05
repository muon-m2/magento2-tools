#!/usr/bin/env bash
# test-audit-consolidate.sh — magento2-audit's consolidate.sh must merge per-dimension findings
# documents into ONE `audit` document (JSON + SARIF) via the shared hub emitter: dedup across
# dimensions, severity-rank, merge scanner_errors, and inject verdict/score/coverage.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

SCRIPT="skills/magento2-audit/scripts/consolidate.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
DIM="$WORK/dims"; mkdir -p "$DIM" "$WORK/out"

# Two dimension documents. The SAME finding (same file+line+category+title) appears in both
# security and review — it must collapse to ONE finding tagged with both dimensions.
cat > "$DIM/Acme_Foo-security-1970-01-01.json" <<'JSON'
{
  "skill": "magento2-security-audit", "outputKind": "security",
  "findings": [
    {"id":"S1","severity":"high","category":"security","title":"Missing ACL on endpoint",
     "evidence":[{"file":"Controller/Save.php","line":10}]},
    {"id":"S2","severity":"critical","category":"security","title":"SQL injection in repository",
     "evidence":[{"file":"Model/Repo.php","line":88}]}
  ],
  "scanner_errors": [{"scanner":"secret-scan","stderr":"trufflehog absent"}]
}
JSON
cat > "$DIM/Acme_Foo-review-1970-01-01.json" <<'JSON'
{
  "skill": "magento2-module-review", "outputKind": "review",
  "findings": [
    {"id":"R1","severity":"medium","category":"security","title":"Missing ACL on endpoint",
     "evidence":[{"file":"Controller/Save.php","line":10}]},
    {"id":"R2","severity":"low","category":"maintainability","title":"Unused import",
     "evidence":[{"file":"Model/Repo.php","line":3}]}
  ],
  "scanner_errors": []
}
JSON

INPUT_DIR="$DIM" TARGET_MODULE="Acme_Foo" TARGET_PATH="src/app/code/Acme/Foo" \
SCOPE="module" OUTPUT_DIR="$WORK/out" \
    bash "$SCRIPT" > /dev/null 2> "$WORK/err" || {
    echo "FAIL: consolidate.sh exited non-zero:"; sed 's/^/    /' "$WORK/err" >&2; exit 1; }

# Basename uses resolve-basename kind=audit → Acme_Foo-audit-<date>.
JSON_OUT=$(find "$WORK/out" -name 'Acme_Foo-audit-*.json' | head -1)
SARIF_OUT=$(find "$WORK/out" -name 'Acme_Foo-audit-*.sarif' | head -1)
[ -n "$JSON_OUT" ]  || { echo "FAIL: no consolidated JSON produced"; exit 1; }
[ -n "$SARIF_OUT" ] || { echo "FAIL: no consolidated SARIF produced"; exit 1; }

python3 - "$JSON_OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get('skill') == 'magento2-audit', f"skill={d.get('skill')!r}"
assert d.get('outputKind') == 'audit', f"outputKind={d.get('outputKind')!r}"
titles = [f.get('title') for f in d['findings']]
# 4 raw findings across 2 docs, but the duplicated "Missing ACL on endpoint" collapses to 1 → 3.
assert len(d['findings']) == 3, f"expected 3 deduped findings, got {len(d['findings'])}: {titles}"
# dedup keeps the higher severity (high from security beats medium from review)
acl = [f for f in d['findings'] if f['title'] == 'Missing ACL on endpoint'][0]
assert acl['severity'] == 'high', f"dedup should keep higher severity, got {acl['severity']}"
assert set(acl.get('dimensions', [])) == {'magento2-security-audit','magento2-module-review'}, \
    f"dedup must record both dimensions: {acl.get('dimensions')}"
# severity-ranked: critical first
assert d['findings'][0]['severity'] == 'critical', 'findings must be severity-ranked'
# merged scanner_errors carried through
assert any(e.get('scanner') == 'secret-scan' for e in d.get('scanner_errors', [])), 'scanner_errors merged'
# verdict/coverage injected
assert d.get('audit_verdict') == 'FAIL', f"verdict={d.get('audit_verdict')!r} (critical+high => FAIL)"
assert isinstance(d.get('dimension_coverage'), list) and len(d['dimension_coverage']) == 2, 'coverage per dimension'
PY
[ "$?" = "0" ] || { echo "FAIL: consolidated JSON contract"; exit 1; }

python3 - "$SARIF_OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get('version') == '2.1.0'
assert d['runs'][0]['tool']['driver']['name'] == 'magento2-audit'
assert len(d['runs'][0]['results']) == 3, 'SARIF mirrors deduped findings'
PY
[ "$?" = "0" ] || { echo "FAIL: consolidated SARIF contract"; exit 1; }

echo "audit consolidate: dedup + rank + verdict + JSON/SARIF all correct"
exit 0
