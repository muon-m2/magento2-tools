#!/usr/bin/env bash
# consolidate.sh — merge the per-dimension findings documents produced by an audit run into
# ONE consolidated `audit` document (JSON + SARIF) via the shared magento2-context hub emitter.
#
# Each audit dimension (magento2-module-review, -security-audit, -performance-audit,
# -static-analysis, -accessibility-audit, -marketplace-prep, -breeze-compat-audit) emits its own
# findings-schema JSON. This script reads them all, tags each finding with its source dimension,
# de-duplicates by (file, line, category, title) keeping the highest severity, merges
# scanner_errors, computes an overall readiness verdict + score + per-dimension coverage, and
# emits the merged document so a whole-module audit collapses to a single ranked report + one
# SARIF for CI / GitHub Code Scanning.
#
# Inputs (env vars):
#   INPUT_DIR       Directory scanned (non-recursively) for *.json dimension documents.
#                   Either INPUT_DIR or INPUT_JSONS is required.
#   INPUT_JSONS     Newline- or space-separated explicit list of dimension JSON paths.
#   TARGET_MODULE   e.g. "Acme_Foo" (required).
#   TARGET_PATH     e.g. "src/app/code/Acme/Foo" (required).
#   SCOPE           "module" (default) | "site".
#   DOCS_ROOT       default: .docs — project-root artifact dir ({ctx.docs_root}).
#   OUTPUT_DIR      default: {DOCS_ROOT}/audits.
#   SKILL_VERSION   default: 1.0.0.
#
# Output:
#   Writes {OUTPUT_DIR}/{TARGET_MODULE}-audit-{date}.json (+ .sarif; site scope: audit-site-...).
#   Echoes the consolidated JSON to stdout.

set -uo pipefail

: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

SCOPE="${SCOPE:-module}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/audits}"
SKILL_VERSION="${SKILL_VERSION:-1.0.0}"
INPUT_DIR="${INPUT_DIR:-}"
INPUT_JSONS="${INPUT_JSONS:-}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "consolidate: python3 required" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT_FINDINGS="${SCRIPT_DIR}/../../magento2-context/scripts/emit-findings.sh"
if [ ! -f "$EMIT_FINDINGS" ]; then
    echo "consolidate: shared emitter not found at $EMIT_FINDINGS" >&2
    exit 2
fi

# Resolve the list of dimension JSON documents.
INPUTS=()
if [ -n "$INPUT_JSONS" ]; then
    # shellcheck disable=SC2206
    INPUTS=($INPUT_JSONS)
elif [ -n "$INPUT_DIR" ] && [ -d "$INPUT_DIR" ]; then
    while IFS= read -r f; do INPUTS+=("$f"); done \
        < <(find "$INPUT_DIR" -maxdepth 1 -type f -name '*.json' | sort)
fi

if [ "${#INPUTS[@]}" -eq 0 ]; then
    echo "consolidate: no dimension JSON documents found (set INPUT_DIR or INPUT_JSONS)" >&2
    exit 3
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FINDINGS_FILE="${TMP_DIR}/findings.json"
SCANNER_ERRORS_FILE="${TMP_DIR}/scanner_errors.json"
META_FILE="${TMP_DIR}/audit-meta.json"

# Merge + dedup + verdict, emitting three files: findings, scanner_errors, meta.
FINDINGS_FILE="$FINDINGS_FILE" \
SCANNER_ERRORS_FILE="$SCANNER_ERRORS_FILE" \
META_FILE="$META_FILE" \
python3 - "${INPUTS[@]}" <<'PY'
import json, os, sys

SEV_RANK = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1, 'info': 0}
SEV_WEIGHT = {'critical': 25, 'high': 15, 'medium': 5, 'low': 1, 'info': 0}

def load(path):
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:
        return None

merged = {}          # dedup key -> finding
scanner_errors = []
coverage = []

for path in sys.argv[1:]:
    doc = load(path)
    if not isinstance(doc, dict):
        scanner_errors.append({'scanner': 'consolidate',
                               'stderr': f'unreadable or non-object dimension document: {path}'})
        continue
    dimension = doc.get('skill') or os.path.basename(path)
    kind = doc.get('outputKind')
    findings = doc.get('findings') or []
    coverage.append({
        'dimension': dimension,
        'outputKind': kind,
        'findings': len(findings),
        'source': os.path.basename(path),
    })
    for e in (doc.get('scanner_errors') or []):
        scanner_errors.append(e)
    for f in findings:
        if not isinstance(f, dict):
            continue
        ev = (f.get('evidence') or [{}])
        first = ev[0] if ev else {}
        key = (first.get('file', ''), first.get('line', 0),
               f.get('category', ''), (f.get('title') or '').strip().lower())
        existing = merged.get(key)
        # tag provenance; when the same issue surfaces in several dimensions, record all.
        f = dict(f)
        f.setdefault('dimension', dimension)
        if existing is None:
            f['dimensions'] = [dimension]
            merged[key] = f
        else:
            dims = existing.get('dimensions', [existing.get('dimension')])
            if dimension not in dims:
                dims.append(dimension)
            existing['dimensions'] = dims
            # keep the higher-severity representative
            if SEV_RANK.get(f.get('severity', 'info'), 0) > SEV_RANK.get(existing.get('severity', 'info'), 0):
                f['dimensions'] = dims
                merged[key] = f

findings = sorted(merged.values(),
                  key=lambda f: SEV_RANK.get(f.get('severity', 'info'), 0), reverse=True)

# Overall readiness score/verdict from the deduped findings.
score, blockers = 100, 0
for f in findings:
    sev = f.get('severity', 'info')
    score -= SEV_WEIGHT.get(sev, 0)
    if sev in ('critical', 'high'):
        blockers += 1
score = max(score, 0)
verdict = 'FAIL' if blockers else ('PASS' if score >= 85 else 'CONDITIONAL')

with open(os.environ['FINDINGS_FILE'], 'w', encoding='utf-8') as fh:
    json.dump(findings, fh, indent=2)
with open(os.environ['SCANNER_ERRORS_FILE'], 'w', encoding='utf-8') as fh:
    json.dump(scanner_errors, fh, indent=2)
with open(os.environ['META_FILE'], 'w', encoding='utf-8') as fh:
    json.dump({'audit_verdict': verdict, 'audit_score': score,
               'dimension_coverage': coverage}, fh, indent=2)
PY

DATE="$(date -u +%Y-%m-%d)"
export FINDINGS_FILE SCANNER_ERRORS_FILE
export TARGET_MODULE TARGET_PATH SCOPE OUTPUT_DIR
export SKILL_NAME="magento2-audit"
export SKILL_VERSION
export OUTPUT_KIND="audit"
export SKILL_VERSIONS_JSON="[\"magento2-audit@${SKILL_VERSION}\",\"magento2-context@1.9.0\"]"
export META_FILE

DATE="$DATE" BASENAME_KIND="audit" \
POST_JSON_HOOK="${SCRIPT_DIR}/audit-verdict.sh" \
    bash "$EMIT_FINDINGS"
