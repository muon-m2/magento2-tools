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
#   PHPSTAN_MEMORY_LIMIT
#                 Value for phpstan's --memory-limit (default: 2G). php.ini's default (commonly
#                 128M) crashes phpstan on a Magento codebase and yields an apparently-clean run.
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
SURFACE_OUT="${TMP_DIR}/surface.json"
PHPCS_ERR="${TMP_DIR}/phpcs.err"
PHPSTAN_ERR="${TMP_DIR}/phpstan.err"
PHPMD_ERR="${TMP_DIR}/phpmd.err"
RECTOR_ERR="${TMP_DIR}/rector.err"

# Exclude dirs common to all tools.
EXCLUDE_PATTERN="*/vendor/*,*/generated/*,*/var/*,*/pub/static/*"

# Where a Magento install's own configs live, relative to the cwd these scanners run from.
# `src/` is this toolchain's convention; a bare install has them at the root.
MAGENTO_ROOT_GUESS="$([ -d src/vendor ] && echo src || echo .)"

echo "[]" > "$PHPCS_OUT"
echo "[]" > "$PHPSTAN_OUT"
echo "[]" > "$PHPMD_OUT"
echo "[]" > "$RECTOR_OUT"
echo "[]" > "$SURFACE_OUT"

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

    # PHP_CodeSniffer writes deprecation notices to STDOUT, ahead of the --report=json payload:
    #   DEPRECATED: Support for custom tokenizers will be removed in PHP_CodeSniffer 4.0.
    #   The Magento2.GraphQL.ValidFieldName sniff is listening for GRAPHQL.
    # (3.13.x, triggered by the Magento2 standard's custom-tokenizer sniffs.) That makes the file
    # invalid JSON, so the parser below used to fail and silently fall back to [] — losing every
    # violation. Drop everything before the first line that starts an object.
    if [ -s "$raw_file" ] && ! head -c 1 "$raw_file" | grep -q '{'; then
        sed -n '/^{/,$p' "$raw_file" > "${raw_file}.stripped" 2>/dev/null || true
        if [ -s "${raw_file}.stripped" ]; then
            echo "run-analysis/phpcs: stripped non-JSON preamble from phpcs stdout" >> "$PHPCS_ERR"
            mv "${raw_file}.stripped" "$raw_file"
        fi
    fi

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
    # A CONFIG, if the project has one. phpstan auto-discovers phpstan.neon only in the CURRENT
    # directory, and these scanners run from the project root while a Magento config lives under
    # the Magento root (src/phpstan.neon) — so without -c it ran with no bootstrap and no autoloader
    # and reported every framework class as unknown. Measured on a real module: three "class not
    # found" errors that the project's own config turns into "[OK] No errors". A findings document
    # full of confident false positives is worse than no phpstan pass at all, because a reader
    # cannot tell which it is.
    #
    # PHPSTAN_CONFIG overrides; otherwise probe the conventional locations, nearest first. Magento
    # ships its own bootstrap under dev/tests/static/framework, which is what a project config
    # normally wires up.
    local phpstan_config="${PHPSTAN_CONFIG:-}"
    if [ -z "$phpstan_config" ]; then
        for candidate in \
            "${TARGET_PATH%/}/phpstan.neon" \
            "$(dirname "${TARGET_PATH%/}")"/phpstan-devpath.neon \
            "$(dirname "${TARGET_PATH%/}")"/phpstan.neon \
            "${MAGENTO_ROOT_GUESS}/phpstan.neon" \
            "${MAGENTO_ROOT_GUESS}/phpstan.neon.dist" \
            "phpstan.neon" \
            "phpstan.neon.dist"
        do
            if [ -n "$candidate" ] && [ -f "$candidate" ]; then
                phpstan_config="$candidate"
                break
            fi
        done
    fi

    # Without an explicit limit phpstan inherits php.ini's default (commonly 128M) and dies with
    # "PHPStan process crashed because it reached configured PHP memory limit" on a Magento
    # codebase, returning {"totals":{"errors":1},"files":[]} — an empty, apparently-clean result.
    run_cmd+=("$PHPSTAN_BIN" analyse --error-format=json --no-progress
        "--memory-limit=${PHPSTAN_MEMORY_LIMIT:-2G}")

    if [ -n "$phpstan_config" ]; then
        run_cmd+=("-c" "$phpstan_config")
    else
        echo "run-analysis/phpstan: no phpstan.neon found (looked in ${TARGET_PATH%/}/, ${MAGENTO_ROOT_GUESS}/ and the cwd) — running without a config, so framework classes will not resolve and 'unknown class' errors are likely to be false positives" >&2
    fi

    run_cmd+=("$TARGET_PATH")

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

# phpstan reports run-level failures (crashes, config errors) in a top-level "errors" list and
# then returns files: []. Dropping those made a crashed run indistinguishable from a clean one.
for run_error in raw.get('errors', []) or []:
    print(f"run-analysis/phpstan: {run_error}", file=sys.stderr)

# "files" is a dict keyed by path on success, but phpstan emits a LIST (usually []) when the run
# failed. Calling .values() on that raised an uncaught AttributeError, so nothing was written.
files = raw.get('files', {})
if not isinstance(files, dict):
    files = {}

# The file path is the dict KEY — phpstan's per-message objects carry `message`/`line`/`ignorable`
# but no `file`. Iterating .values() and reading err['file'] therefore resolved to '?' for EVERY
# phpstan finding, which strands it: `evidence.file` is what the SARIF emitter anchors a result to,
# so Code Scanning had nothing to attach the finding to. Latent until now only because phpstan was
# crashing before this release and produced no findings at all to mis-anchor.
for file_path, file_errors in files.items():
    if not isinstance(file_errors, dict):
        continue
    for err in file_errors.get('messages', []) or []:
        ignorable = bool(err.get('ignorable', False))
        out.append({
            'id': f'quality-phpstan-{seq:04d}',
            'severity': 'medium',
            'category': 'type',
            'subcategory': 'phpstan',
            'title': err.get('message', 'PHPStan error'),
            # Prefer a per-message `file` if some formatter version does emit one; the key is truth.
            'evidence': [{'file': err.get('file') or file_path, 'line': err.get('line', 1)}],
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
    # Prefer the module's own ruleset when it ships one. Running the built-in rulesets against a
    # module that has deliberately excluded rules re-reports exactly what the project chose to
    # suppress — e.g. `_resetState()`, whose name is MANDATED by Magento's
    # ResetAfterRequestInterface, trips CamelCaseMethodName. The module ruleset is also what
    # validate-module.sh and the seeded module CI enforce, so this keeps the audit aligned with
    # the gate the project actually ships.
    #
    # The probe runs on the HOST while phpmd may run inside a container via $RUNNER. A path under
    # $TARGET_PATH is safe either way — it is the same string the tool is handed, so a host hit
    # means the mount resolves. A BARE relative path is not: it resolves against the container's
    # cwd, which need not be the host's, so that fallback is taken only when running locally.
    local phpmd_ruleset="cleancode,codesize,controversial,design,naming,unusedcode"
    if [ -f "${TARGET_PATH}/phpmd.xml" ]; then
        phpmd_ruleset="${TARGET_PATH}/phpmd.xml"
    elif [ -z "$RUNNER" ] && [ -f "phpmd.xml" ]; then
        phpmd_ruleset="phpmd.xml"
    fi

    run_cmd+=("$PHPMD_BIN_RESOLVED" "$TARGET_PATH" json
        "$phpmd_ruleset"
        "--exclude=${EXCLUDE_PATTERN}")

    # phpmd exits 2 when violations found (non-zero).
    "${run_cmd[@]}" > "$raw_file" 2> "$PHPMD_ERR" || true

    # Which rules judged the module is provenance the report must carry: with a module ruleset the
    # findings reflect the rules that module chose for itself, not the built-in set. Appended
    # AFTER the run — `2> "$PHPMD_ERR"` truncates, so anything written earlier is lost.
    if [ "$phpmd_ruleset" != "cleancode,codesize,controversial,design,naming,unusedcode" ]; then
        echo "run-analysis/phpmd: using the module's own ruleset ${phpmd_ruleset} \
(findings reflect the rules this module selected, not the built-in set)" >> "$PHPMD_ERR"
    fi

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

# PHPMD "priority" ranks how important a RULE is, not how severe a defect is: its CamelCase* rules
# ship at priority 1, so a 1:1 map made "method is not named in camelCase" a Critical.
#
# In a consolidated audit that is load-bearing. magento2-audit's verdict blocks on BOTH tiers —
# `if sev in ('critical', 'high'): blockers += 1`, then `FAIL if blockers` (audit/scripts/
# consolidate.sh) — so demoting critical→high would have kept the exact failure it was meant to
# stop: `_resetState()`, whose name is MANDATED by Magento's ResetAfterRequestInterface, would
# still FAIL the audit of every module that does not ship its own phpmd.xml.
#
# So the map is CAPPED at medium: no phpmd finding can be a blocker on its own. That is the whole
# invariant — a lint rule should raise concern, not veto a release — and the test asserts it
# against the blocking tiers rather than against 'critical' alone. Anything phpmd finds that truly
# warrants High is a defect another dimension (security, architecture) is meant to catch on merit.
priority_map = {1: 'medium', 2: 'medium', 3: 'medium', 4: 'low', 5: 'info'}
out = []
seq = 1

# PHPMD's JSON renderer nests violations under files:
#   {"files": [{"file": "/abs/path.php", "violations": [{...}, ...]}, ...]}
# There is NO top-level "violations" key. Reading one meant the loop ran zero times while the
# JSON still parsed cleanly, so every violation was dropped with no error raised anywhere.
# Accept the top-level form too, in case a future renderer emits it.
violations = []
for file_entry in raw.get('files', []) or []:
    if not isinstance(file_entry, dict):
        continue
    file_name = file_entry.get('file')
    for violation in file_entry.get('violations', []) or []:
        if isinstance(violation, dict):
            violation.setdefault('fileName', file_name)
            violations.append(violation)
violations.extend(raw.get('violations', []) or [])

for violation in violations:
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

    # Rector 1.x is not PHP 8.5 compatible; Rector 2.x is. On 8.5, 1.x emits
    # "ReflectionProperty::setAccessible() is deprecated" plus a full stack trace for essentially
    # every rule it loads — measured at 495 MB of stderr and ~2,535 repetitions on one module — and
    # its JSON never arrives, so the pass contributes nothing while looking like it ran. Verified
    # side by side on PHP 8.5.7: rector 1.2.10 produced that flood, rector 2.5.8 produced valid
    # JSON and ZERO bytes of stderr.
    #
    # So this gates on the pairing, not on the PHP version alone — a project already on 2.x must
    # still get its refactoring pass. RECTOR_FORCE=1 overrides.
    if [ "${RECTOR_FORCE:-0}" != "1" ]; then
        local rector_php rector_ver
        rector_php="$( { [ -n "$RUNNER" ] && $RUNNER php -r 'echo PHP_VERSION;'; } 2>/dev/null || php -r 'echo PHP_VERSION;' 2>/dev/null )"
        rector_ver="$( { [ -n "$RUNNER" ] && $RUNNER "$RECTOR_BIN" --version; } 2>/dev/null || "$RECTOR_BIN" --version 2>/dev/null )"
        rector_ver="$(printf '%s' "$rector_ver" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"

        case "${rector_php}|${rector_ver}" in
            8.5*\|1.*|8.6*\|1.*|9.*\|1.*)
                echo "run-analysis/rector: SKIPPED — rector ${rector_ver} is not compatible with PHP ${rector_php}. It floods stderr with ReflectionProperty::setAccessible deprecations and emits no parseable JSON, so refactoring opportunities were NOT checked. Upgrade to rector ^2.5, which runs clean on 8.5. Set RECTOR_FORCE=1 to run it anyway." >&2
                return 0
                ;;
        esac
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

# ---------------------------------------------------------------------------
# surface invariants — cross-file completeness checks (no external tool needed)
# ---------------------------------------------------------------------------
run_surface_invariants() {
    # Module scope only: every rule reasons about ONE module's file set (a topic here needs a
    # publisher there). At site/diff scope the caller should invoke it per changed module.
    if [ "$SCOPE" != "module" ]; then
        echo "run-analysis/surface-invariants: scope '$SCOPE' is not module — surface \
completeness was NOT checked; invoke per module to cover it" >&2
        return
    fi
    local magento_root=""
    if [ -d "src/vendor" ]; then
        magento_root="src"
    elif [ -d vendor ]; then
        magento_root="."
    fi
    TARGET_PATH="$TARGET_PATH" \
    SCAN_ROOT="${SCAN_ROOT:-}" \
    MAGENTO_ROOT="$magento_root" \
    FINDINGS_FILE="$SURFACE_OUT" \
        bash "${SCRIPT_DIR}/surface-invariants.sh" >/dev/null || true
    # stderr is deliberately NOT captured to a temp file: build-findings.sh turns this script's
    # stderr into the document's `scanner_errors`, which is the only channel that distinguishes
    # "checked and clean" from "not checked". The other scanners write to *_ERR temp files instead,
    # which forward_tool_errors() streams to this same stderr once every pass has run; writing here
    # directly is equivalent, just without a temp file to relay.
    if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SURFACE_OUT" 2>/dev/null; then
        echo "run-analysis/surface-invariants: produced invalid JSON — surface completeness \
findings were dropped" >&2
        echo "[]" > "$SURFACE_OUT"
    fi
}

# Run all scanners.
run_phpcs
run_phpstan
run_phpmd
run_rector_dry
run_surface_invariants

# Forward each tool's captured stderr to OUR stderr. build-findings.sh turns this script's stderr
# into the document's `scanner_errors`, which is the only channel that distinguishes "checked and
# clean" from "never ran". These files were previously written and then dropped on the floor, which
# is what let three separate parser failures each report findings: [] with scanner_errors: [] —
# a false clean, the worst failure mode a quality gate has.
forward_tool_errors() {
    local name err line
    for name in phpcs phpstan phpmd rector; do
        case "$name" in
            phpcs) err="$PHPCS_ERR" ;;
            phpstan) err="$PHPSTAN_ERR" ;;
            phpmd) err="$PHPMD_ERR" ;;
            rector) err="$RECTOR_ERR" ;;
        esac
        [ -s "$err" ] || continue

        # Streamed line by line rather than flattened through a command substitution: a tool's
        # stderr can be long (phpstan prints multi-line traces), and collapsing it would cost the
        # structure that makes it readable in `scanner_errors`. Lines the parsers already tagged
        # keep their own prefix instead of being tagged twice.
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                '') ;;
                run-analysis/*) printf '%s\n' "$line" >&2 ;;
                *) printf 'run-analysis/%s: %s\n' "$name" "$line" >&2 ;;
            esac
        done < "$err"
    done
}
forward_tool_errors

# Merge all findings into one array.
FINDINGS_FILE="${FINDINGS_FILE:-${TMP_DIR}/findings.json}"

python3 - "$PHPCS_OUT" "$PHPSTAN_OUT" "$PHPMD_OUT" "$RECTOR_OUT" "$SURFACE_OUT" > "$FINDINGS_FILE" <<'PY'
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
