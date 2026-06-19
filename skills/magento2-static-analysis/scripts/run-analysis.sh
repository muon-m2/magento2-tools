#!/usr/bin/env bash
# run-analysis.sh — orchestrate READ-ONLY static-analysis tool passes over a module or
# diff scope and aggregate results into a findings JSON array file.
#
# Inputs (env vars or positional):
#   TARGET_PATH   Path to analyse (required, or $1)
#   SCOPE         "module" | "site" | "diff" (default: module)
#   RUNNER        Runner prefix, e.g. "docker compose exec -T php" (default: "")
#   PHPCS         Path to phpcs binary (default: vendor/bin/phpcs)
#   PHPSTAN       Path to phpstan binary (default: "")
#   PHPMD         Path to phpmd binary (default: "")
#   RECTOR        Path to rector binary (default: "")
#   FINDINGS_FILE Output path for the JSON findings array (default: auto tmp file printed to stdout)
#
# Output:
#   Writes a JSON array of finding objects (findings-schema.md shape) to FINDINGS_FILE.
#   Prints FINDINGS_FILE path to stdout for callers that chain into build-findings.sh.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_PATH="${TARGET_PATH:-${1:-}}"
: "${TARGET_PATH:?TARGET_PATH is required (pass as env var or \$1)}"

SCOPE="${SCOPE:-module}"
RUNNER="${RUNNER:-}"
PHPCS="${PHPCS:-}"
PHPSTAN="${PHPSTAN:-}"
PHPMD="${PHPMD_BIN:-${PHPMD:-}}"
RECTOR="${RECTOR:-}"

# Resolve tool paths — prefer env overrides, fall back to vendor/bin probes.
_resolve_tool() {
    local env_val="$1" bin_name="$2"
    if [ -n "$env_val" ]; then
        printf '%s' "$env_val"
        return
    fi
    for candidate in "vendor/bin/${bin_name}" "src/vendor/bin/${bin_name}"; do
        if [ -x "$candidate" ]; then
            printf '%s' "$candidate"
            return
        fi
    done
}

PHPCS_BIN="$(_resolve_tool "$PHPCS" phpcs)"
PHPSTAN_BIN="$(_resolve_tool "$PHPSTAN" phpstan)"
PHPMD_BIN_RESOLVED="$(_resolve_tool "$PHPMD" phpmd)"
RECTOR_BIN="$(_resolve_tool "$RECTOR" rector)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PHPCS_OUT="${TMP_DIR}/phpcs.json"
PHPSTAN_OUT="${TMP_DIR}/phpstan.json"
PHPMD_OUT="${TMP_DIR}/phpmd.json"
RECTOR_OUT="${TMP_DIR}/rector.json"
PHPCS_ERR="${TMP_DIR}/phpcs.err"
PHPSTAN_ERR="${TMP_DIR}/phpstan.err"
PHPMD_ERR="${TMP_DIR}/phpmd.err"
RECTOR_ERR="${TMP_DIR}/rector.err"

# Exclude dirs common to all tools.
EXCLUDE_PATTERN="*/vendor/*,*/generated/*,*/var/*,*/pub/static/*"

echo "[]" > "$PHPCS_OUT"
echo "[]" > "$PHPSTAN_OUT"
echo "[]" > "$PHPMD_OUT"
echo "[]" > "$RECTOR_OUT"

# ---------------------------------------------------------------------------
# phpcs — detect coding-standard violations (read-only)
# ---------------------------------------------------------------------------
run_phpcs() {
    if [ -z "$PHPCS_BIN" ]; then
        echo "run-analysis: phpcs not found — skipping" >&2
        return 0
    fi

    local raw_file="${TMP_DIR}/phpcs_raw.json"
    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi
    run_cmd+=("$PHPCS_BIN" --standard=Magento2 --report=json
        "--ignore=${EXCLUDE_PATTERN}" "$TARGET_PATH")

    # phpcs exits 1 when violations found — that is expected; capture output regardless.
    "${run_cmd[@]}" > "$raw_file" 2> "$PHPCS_ERR" || true

    python3 - "$raw_file" > "$PHPCS_OUT" 2>> "$PHPCS_ERR" <<'PY'
import json
import sys

raw_path = sys.argv[1]
try:
    with open(raw_path, encoding='utf-8') as fh:
        raw = json.load(fh)
except Exception as exc:
    print(f"run-analysis/phpcs: could not parse phpcs JSON: {exc}", file=sys.stderr)
    print("[]")
    sys.exit(0)

out = []
seq = 1
for file_path, file_data in raw.get('files', {}).items():
    for msg in file_data.get('messages', []):
        msg_type = msg.get('type', 'WARNING')
        severity_map = {'ERROR': 'high', 'WARNING': 'medium'}
        severity = severity_map.get(msg_type.upper(), 'low')
        fixable = bool(msg.get('fixable', False))
        out.append({
            'id': f'quality-phpcs-{seq:04d}',
            'severity': severity,
            'category': 'style',
            'subcategory': msg.get('source', 'phpcs'),
            'title': msg.get('message', 'PHPCS violation'),
            'evidence': [{'file': file_path, 'line': msg.get('line', 1)}],
            'recommendation': 'Run phpcbf --standard=Magento2 to auto-fix' if fixable
                              else f"Fix manually: {msg.get('source', 'phpcs')}",
            'verification': 'Re-run phpcs --standard=Magento2 after fixing',
            'tags': ['phpcs', 'magento2-standard', 'auto-fixable' if fixable else 'manual'],
        })
        seq += 1

print(json.dumps(out, indent=2))
PY
}

# ---------------------------------------------------------------------------
# phpstan — detect type errors and dead code (read-only, report-only)
# ---------------------------------------------------------------------------
run_phpstan() {
    if [ -z "$PHPSTAN_BIN" ]; then
        echo "run-analysis: phpstan not found — skipping" >&2
        return 0
    fi

    local raw_file="${TMP_DIR}/phpstan_raw.json"
    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi
    run_cmd+=("$PHPSTAN_BIN" analyse --error-format=json --no-progress "$TARGET_PATH")

    # phpstan exits 1 when errors found — expected.
    "${run_cmd[@]}" > "$raw_file" 2> "$PHPSTAN_ERR" || true

    python3 - "$raw_file" > "$PHPSTAN_OUT" 2>> "$PHPSTAN_ERR" <<'PY'
import json
import sys

raw_path = sys.argv[1]
try:
    with open(raw_path, encoding='utf-8') as fh:
        raw = json.load(fh)
except Exception as exc:
    print(f"run-analysis/phpstan: could not parse phpstan JSON: {exc}", file=sys.stderr)
    print("[]")
    sys.exit(0)

out = []
seq = 1
for file_errors in raw.get('files', {}).values():
    for err in file_errors.get('messages', []):
        ignorable = bool(err.get('ignorable', False))
        out.append({
            'id': f'quality-phpstan-{seq:04d}',
            'severity': 'medium',
            'category': 'type',
            'subcategory': 'phpstan',
            'title': err.get('message', 'PHPStan error'),
            'evidence': [{'file': err.get('file', '?'), 'line': err.get('line', 1)}],
            'recommendation': 'Fix the type error or add a PHPStan ignore annotation.',
            'verification': 'Re-run phpstan analyse after fixing.',
            'tags': ['phpstan', 'manual', 'ignorable' if ignorable else 'must-fix'],
        })
        seq += 1

print(json.dumps(out, indent=2))
PY
}

# ---------------------------------------------------------------------------
# phpmd — detect code-complexity and clean-code violations (report-only)
# ---------------------------------------------------------------------------
run_phpmd() {
    if [ -z "$PHPMD_BIN_RESOLVED" ]; then
        echo "run-analysis: phpmd not found — skipping" >&2
        return 0
    fi

    local raw_file="${TMP_DIR}/phpmd_raw.json"
    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi
    run_cmd+=("$PHPMD_BIN_RESOLVED" "$TARGET_PATH" json
        cleancode,codesize,controversial,design,naming,unusedcode
        "--exclude=${EXCLUDE_PATTERN}")

    # phpmd exits 2 when violations found (non-zero).
    "${run_cmd[@]}" > "$raw_file" 2> "$PHPMD_ERR" || true

    python3 - "$raw_file" > "$PHPMD_OUT" 2>> "$PHPMD_ERR" <<'PY'
import json
import sys

raw_path = sys.argv[1]
try:
    with open(raw_path, encoding='utf-8') as fh:
        raw = json.load(fh)
except Exception as exc:
    print(f"run-analysis/phpmd: could not parse phpmd JSON: {exc}", file=sys.stderr)
    print("[]")
    sys.exit(0)

# phpmd priority: 1=critical, 2=high, 3=medium, 4=low, 5=info
priority_map = {1: 'critical', 2: 'high', 3: 'medium', 4: 'low', 5: 'info'}
out = []
seq = 1
for violation in raw.get('violations', []):
    priority = violation.get('priority', 3)
    severity = priority_map.get(priority, 'medium')
    out.append({
        'id': f'quality-phpmd-{seq:04d}',
        'severity': severity,
        'category': 'complexity',
        'subcategory': violation.get('rule', 'phpmd'),
        'title': violation.get('description', 'PHPMD violation'),
        'evidence': [{'file': violation.get('fileName', '?'),
                      'line': violation.get('beginLine', 1),
                      'endLine': violation.get('endLine')}],
        'recommendation': (
            f"Rule: {violation.get('rule', '?')} "
            f"(ruleset: {violation.get('ruleset', '?')}). "
            f"See: {violation.get('externalInfoUrl', '')}"
        ),
        'verification': 'Re-run phpmd after refactoring.',
        'tags': ['phpmd', 'manual', violation.get('ruleset', 'phpmd')],
    })
    seq += 1

print(json.dumps(out, indent=2))
PY
}

# ---------------------------------------------------------------------------
# rector --dry-run — detect refactoring opportunities (read-only)
# ---------------------------------------------------------------------------
run_rector_dry() {
    if [ -z "$RECTOR_BIN" ]; then
        echo "run-analysis: rector not found — skipping" >&2
        return 0
    fi

    local raw_file="${TMP_DIR}/rector_raw.json"
    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi
    run_cmd+=("$RECTOR_BIN" process --dry-run --output-format=json "$TARGET_PATH")

    # rector --dry-run exits non-zero when changes are proposed.
    "${run_cmd[@]}" > "$raw_file" 2> "$RECTOR_ERR" || true

    python3 - "$raw_file" > "$RECTOR_OUT" 2>> "$RECTOR_ERR" <<'PY'
import json
import sys

# Rector --dry-run JSON shape varies by version. Try both known shapes.
SAFE_SETS = {
    'TypeDeclaration\\AddVoidReturnTypeWhereNoReturnRector',
    'TypeDeclaration\\ReturnTypeFromReturnNewRector',
    'TypeDeclaration\\ParamTypeFromStrictTypedPropertyRector',
    'DeadCode\\RemoveUnusedVariableRector',
    'Php80\\UnionTypesRector',
}

raw_path = sys.argv[1]
try:
    with open(raw_path, encoding='utf-8') as fh:
        raw = json.load(fh)
except Exception as exc:
    print(f"run-analysis/rector: could not parse rector JSON: {exc}", file=sys.stderr)
    print("[]")
    sys.exit(0)

out = []
seq = 1
# Rector JSON may have `file_diffs` list or `changed_files` list.
diffs = raw.get('file_diffs', raw.get('changed_files', []))
for diff in diffs:
    file_path = diff.get('file', diff.get('absolute_file_path', '?'))
    for applied in diff.get('applied_rectors', []):
        rector_class = applied.split('\\')[-1] if '\\' in applied else applied
        is_safe = any(applied.endswith(s) for s in SAFE_SETS)
        tags = ['rector', 'safe-auto-apply' if is_safe else 'review-required']
        out.append({
            'id': f'quality-rector-{seq:04d}',
            'severity': 'low' if is_safe else 'info',
            'category': 'refactoring',
            'subcategory': 'rector',
            'title': f'Rector: {rector_class}',
            'evidence': [{'file': file_path, 'line': 1}],
            'recommendation': (
                'Auto-apply in Phase 3 (safe transform).' if is_safe
                else f'Review and apply manually: {applied}'
            ),
            'verification': 'Re-run rector --dry-run after applying.',
            'tags': tags,
        })
        seq += 1

print(json.dumps(out, indent=2))
PY
}

# Run all scanners.
run_phpcs
run_phpstan
run_phpmd
run_rector_dry

# Merge all findings into one array.
FINDINGS_FILE="${FINDINGS_FILE:-${TMP_DIR}/findings.json}"

python3 - "$PHPCS_OUT" "$PHPSTAN_OUT" "$PHPMD_OUT" "$RECTOR_OUT" > "$FINDINGS_FILE" <<'PY'
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

echo "$FINDINGS_FILE"
