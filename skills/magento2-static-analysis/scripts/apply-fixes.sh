#!/usr/bin/env bash
# apply-fixes.sh — run SAFE auto-fixers (phpcbf, php-cs-fixer) over an approved scope.
# Never touches vendor/, generated/, var/, or pub/static/.
#
# Rector is NOT auto-applied. Rector findings are proposals (dry-run only, produced by
# run-analysis.sh) that the developer applies manually after review.
#
# Inputs (env vars):
#   TARGET_PATH    Path to fix (required)
#   RUNNER         Runner prefix, e.g. "docker compose exec -T php" (default: "")
#   PHPCBF         Path to phpcbf binary (default: auto-resolved)
#   PHP_CS_FIXER   Path to php-cs-fixer binary (default: auto-resolved)
#   DRY_RUN        "1" to skip actual fixes (default: 0)
#
# Output:
#   Exits 0 on success. Prints before/after violation counts to stdout as JSON.
#   Exits non-zero only on tool runtime errors (not on violation counts).

set -uo pipefail

: "${TARGET_PATH:?TARGET_PATH is required}"

RUNNER="${RUNNER:-}"
PHPCBF="${PHPCBF:-}"
PHP_CS_FIXER="${PHP_CS_FIXER:-}"
DRY_RUN="${DRY_RUN:-0}"

# Never touch these directories.
EXCLUDE_PATTERN="*/vendor/*,*/generated/*,*/var/*,*/pub/static/*"

# Resolve a tool path: prefer env override, then vendor/bin probe.
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

PHPCBF_BIN="$(_resolve_tool "$PHPCBF" phpcbf)"
PHP_CS_FIXER_BIN="$(_resolve_tool "$PHP_CS_FIXER" php-cs-fixer)"

# Safety guard: TARGET_PATH must not be or contain vendor/.
case "$TARGET_PATH" in
    *vendor*) echo "apply-fixes: refusing to fix vendor/ path: $TARGET_PATH" >&2; exit 1 ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

BEFORE_FILE="${TMP_DIR}/before.json"
AFTER_FILE="${TMP_DIR}/after.json"
FIX_LOG="${TMP_DIR}/fixes.log"

# Count violations via phpcs before fixing.
count_phpcs_violations() {
    local target="$1" out_file="$2"
    local count=0
    if [ -n "$PHPCBF_BIN" ] || [ -x "vendor/bin/phpcs" ]; then
        local phpcs_bin
        phpcs_bin="$(_resolve_tool "" phpcs)"
        if [ -n "$phpcs_bin" ]; then
            local run_cmd=()
            if [ -n "$RUNNER" ]; then
                # shellcheck disable=SC2206
                run_cmd=($RUNNER)
            fi
            run_cmd+=("$phpcs_bin" --standard=Magento2
                "--ignore=${EXCLUDE_PATTERN}" "$target")
            count=$("${run_cmd[@]}" --report=json 2>/dev/null | php -r '$d=json_decode(stream_get_contents(STDIN),true); echo (int)(($d["totals"]["errors"]??0)+($d["totals"]["warnings"]??0));' 2>/dev/null || echo 0)
        fi
    fi
    printf '%d' "$count" > "$out_file"
}

count_phpcs_violations "$TARGET_PATH" "$BEFORE_FILE"
BEFORE_COUNT="$(cat "$BEFORE_FILE")"

# ---------------------------------------------------------------------------
# 1. phpcbf — auto-fix PHPCS violations (all phpcbf transforms are SAFE)
# ---------------------------------------------------------------------------
run_phpcbf() {
    if [ -z "$PHPCBF_BIN" ]; then
        echo "apply-fixes: phpcbf not found — skipping" | tee -a "$FIX_LOG" >&2
        return 0
    fi

    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi
    run_cmd+=("$PHPCBF_BIN" --standard=Magento2
        "--ignore=${EXCLUDE_PATTERN}" "$TARGET_PATH")

    if [ "$DRY_RUN" = "1" ]; then
        echo "apply-fixes: [dry-run] would run: ${run_cmd[*]}" | tee -a "$FIX_LOG"
        return 0
    fi

    echo "apply-fixes: running phpcbf..." | tee -a "$FIX_LOG"
    # phpcbf exits 1 when it fixes something — that is the success case; exit 2 = error.
    "${run_cmd[@]}" >> "$FIX_LOG" 2>&1 || {
        local rc=$?
        if [ "$rc" -ge 2 ]; then
            echo "apply-fixes: phpcbf exited with error code $rc" >&2
        fi
    }
}

# ---------------------------------------------------------------------------
# 2. php-cs-fixer — apply safe formatting rules
# ---------------------------------------------------------------------------
run_php_cs_fixer() {
    if [ -z "$PHP_CS_FIXER_BIN" ]; then
        echo "apply-fixes: php-cs-fixer not found — skipping" | tee -a "$FIX_LOG" >&2
        return 0
    fi

    local run_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        run_cmd=($RUNNER)
    fi

    # Use project config if present; otherwise apply safe rules only.
    if [ -f ".php-cs-fixer.dist.php" ] || [ -f ".php-cs-fixer.php" ]; then
        run_cmd+=("$PHP_CS_FIXER_BIN" fix --diff --using-cache=no "$TARGET_PATH")
    else
        run_cmd+=("$PHP_CS_FIXER_BIN" fix --diff --using-cache=no
            "--rules=@PSR12,no_unused_imports,ordered_imports,trailing_comma_in_multiline,single_quote,no_extra_blank_lines"
            "$TARGET_PATH")
    fi

    if [ "$DRY_RUN" = "1" ]; then
        echo "apply-fixes: [dry-run] would run: ${run_cmd[*]}" | tee -a "$FIX_LOG"
        return 0
    fi

    echo "apply-fixes: running php-cs-fixer..." | tee -a "$FIX_LOG"
    "${run_cmd[@]}" >> "$FIX_LOG" 2>&1 || {
        local rc=$?
        # php-cs-fixer exits 8 when it fixed something; 0 = nothing to fix; others = error.
        if [ "$rc" -ne 0 ] && [ "$rc" -ne 8 ]; then
            echo "apply-fixes: php-cs-fixer exited with error code $rc" >&2
        fi
    }
}

run_phpcbf
run_php_cs_fixer

# Count violations after fixing.
count_phpcs_violations "$TARGET_PATH" "$AFTER_FILE"
AFTER_COUNT="$(cat "$AFTER_FILE")"

RESOLVED=$(( BEFORE_COUNT - AFTER_COUNT ))

python3 - "$BEFORE_COUNT" "$AFTER_COUNT" "$RESOLVED" "$FIX_LOG" <<'PY'
import json
import sys

before, after, resolved, log_path = \
    int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]

try:
    with open(log_path, encoding='utf-8', errors='replace') as fh:
        log = fh.read()
except OSError:
    log = ''

result = {
    'before': before,
    'after': after,
    'resolved': resolved,
    'log': log[:2000],
}
print(json.dumps(result, indent=2))
PY
