#!/usr/bin/env bash
# emit-json.sh — write a findings JSON document to the output path.
#
# Skill-agnostic: the calling skill controls labelling and output naming via env vars.
# Defaults preserve the original magento2-module-review behaviour for back-compat.
#
# Inputs (env vars):
#   FINDINGS_FILE   Path to a JSON file containing the `findings` array (required).
#   TARGET_MODULE   e.g. "Acme_OrderS3Export" (required)
#   TARGET_PATH     e.g. "src/app/code/Acme/OrderS3Export" (required)
#   MODE            "full" | "quick" | "diff" (default: full)
#   SCOPE           "module" (default) | "site" | "diff" | "vendor"
#   SKILL_NAME      default: magento2-module-review
#   SKILL_VERSION  default: 2.3.0
#   SKILL_VERSIONS_JSON  Optional JSON array string (e.g. '["foo@1","bar@2"]')
#                  When set, used verbatim as skillVersions[]; otherwise auto-built.
#   OUTPUT_KIND     "review" | "security" | "performance" | "upgrade" (default: review)
#   OUTPUT_BASENAME default: "{TARGET_MODULE}-{OUTPUT_KIND}-{YYYY-MM-DD}"
#   CONTEXT_FILE    default: .claude/.cache/magento2-context.json
#   SKIPPED_FILE    Optional JSON array of skipped checks
#   TOOLS_FILE      Optional JSON object of executed/unavailable tools
#   DOCS_ROOT       default: .docs — project-root artifact dir ({ctx.docs_root}).
#                   Pass an absolute or project-root path so an in-`src/` cwd cannot
#                   redirect output into the Magento tree. See the "Artifact location"
#                   rule in magento2-context/SKILL.md.
#   OUTPUT_DIR      default: {DOCS_ROOT}/reviews
#
# Output:
#   Writes {OUTPUT_DIR}/{OUTPUT_BASENAME}.json to stdout AND saves to file.

set -euo pipefail

: "${FINDINGS_FILE:?FINDINGS_FILE is required}"
: "${TARGET_MODULE:?TARGET_MODULE is required}"
: "${TARGET_PATH:?TARGET_PATH is required}"

MODE="${MODE:-full}"
SCOPE="${SCOPE:-module}"
SKILL_NAME="${SKILL_NAME:-magento2-module-review}"
SKILL_VERSION="${SKILL_VERSION:-2.3.0}"
SKILL_VERSIONS_JSON="${SKILL_VERSIONS_JSON:-}"
OUTPUT_KIND="${OUTPUT_KIND:-review}"
CONTEXT_FILE="${CONTEXT_FILE:-.claude/.cache/magento2-context.json}"
SKIPPED_FILE="${SKIPPED_FILE:-}"
TOOLS_FILE="${TOOLS_FILE:-}"
DOCS_ROOT="${DOCS_ROOT:-.docs}"
OUTPUT_DIR="${OUTPUT_DIR:-${DOCS_ROOT}/reviews}"

[ -f "$FINDINGS_FILE" ] || { echo "emit-json: findings file not found: $FINDINGS_FILE" >&2; exit 3; }

mkdir -p "$OUTPUT_DIR"
DATE="$(date -u +%Y-%m-%d)"
OUTPUT_BASENAME="${OUTPUT_BASENAME:-${TARGET_MODULE}-${OUTPUT_KIND}-${DATE}}"
OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_BASENAME}.json"

if ! command -v python3 >/dev/null 2>&1; then
    echo "emit-json: python3 required" >&2
    exit 2
fi

FINDINGS_FILE="$FINDINGS_FILE" \
TARGET_MODULE="$TARGET_MODULE" \
TARGET_PATH="$TARGET_PATH" \
MODE="$MODE" \
SCOPE="$SCOPE" \
SKILL_NAME="$SKILL_NAME" \
SKILL_VERSION="$SKILL_VERSION" \
SKILL_VERSIONS_JSON="$SKILL_VERSIONS_JSON" \
OUTPUT_KIND="$OUTPUT_KIND" \
CONTEXT_FILE="$CONTEXT_FILE" \
SKIPPED_FILE="$SKIPPED_FILE" \
TOOLS_FILE="$TOOLS_FILE" \
OUTPUT_FILE="$OUTPUT_FILE" \
python3 <<'PY' | tee "$OUTPUT_FILE"
import json
import os
import sys
from datetime import datetime, timezone


def read_json(path: str, default):
    if not path or not os.path.exists(path):
        return default
    try:
        with open(path, encoding='utf-8') as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        print(f"emit-json: failed to read {path}: {exc}", file=sys.stderr)
        return default


def project_context(ctx: dict) -> dict:
    if not isinstance(ctx, dict):
        return {}
    keys = ('vendor', 'magento_version', 'edition', 'php_version', 'runner')
    return {k: ctx.get(k) for k in keys}


def summarize(findings: list) -> dict:
    by_severity = {k: 0 for k in ('critical', 'high', 'medium', 'low', 'info')}
    by_category: dict = {}
    for f in findings:
        sev = f.get('severity', 'info')
        cat = f.get('category', 'uncategorized')
        by_severity[sev] = by_severity.get(sev, 0) + 1
        by_category[cat] = by_category.get(cat, 0) + 1
    return {
        'total': len(findings),
        'bySeverity': by_severity,
        'byCategory': by_category,
    }


findings = read_json(os.environ['FINDINGS_FILE'], [])
if not isinstance(findings, list):
    print("emit-json: findings file must contain a JSON array", file=sys.stderr)
    sys.exit(4)

context = project_context(read_json(os.environ.get('CONTEXT_FILE', ''), {}))
skipped = read_json(os.environ.get('SKIPPED_FILE', ''), [])
tools = read_json(os.environ.get('TOOLS_FILE', ''), {})

skill_name = os.environ.get('SKILL_NAME', 'magento2-module-review')
skill_version = os.environ.get('SKILL_VERSION', '2.3.0')
output_kind = os.environ.get('OUTPUT_KIND', 'review')

raw_versions = os.environ.get('SKILL_VERSIONS_JSON', '').strip()
if raw_versions:
    try:
        skill_versions = json.loads(raw_versions)
        if not isinstance(skill_versions, list):
            print("emit-json: SKILL_VERSIONS_JSON must decode to a JSON array", file=sys.stderr)
            sys.exit(5)
    except ValueError as exc:
        print(f"emit-json: invalid SKILL_VERSIONS_JSON: {exc}", file=sys.stderr)
        sys.exit(5)
else:
    skill_versions = [
        f'{skill_name}@{skill_version}',
        'magento2-context@1.6.0',
    ]

document = {
    'schemaVersion': '1.0',
    'skill': skill_name,
    'skillVersion': skill_version,
    'skillVersions': skill_versions,
    'outputKind': output_kind,
    'target': {
        'module': os.environ['TARGET_MODULE'],
        'path': os.environ['TARGET_PATH'],
        'scope': os.environ.get('SCOPE', 'module'),
    },
    'runAt': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'mode': os.environ.get('MODE', 'full'),
    'context': context,
    'summary': summarize(findings),
    'findings': findings,
    'skipped': skipped,
    'tools': tools,
}

print(json.dumps(document, indent=2, ensure_ascii=False))
PY

echo "emit-json: wrote $OUTPUT_FILE" >&2
