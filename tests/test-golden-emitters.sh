#!/usr/bin/env bash
# test-golden-emitters.sh — golden/snapshot test for the shared findings emitters
# (emit-json.sh + emit-sarif.sh). Pins the full emitted shape against checked-in golden
# files so any regression in the document structure fails loudly.
#
# The only non-deterministic field is emit-json's `runAt` (a UTC timestamp); it is
# normalized to a fixed placeholder before comparison. emit-sarif derives its only
# timestamp (endTimeUtc) from that runAt, so feeding it the normalized JSON makes the
# SARIF deterministic too.
#
# Refresh goldens after an intentional emitter change:
#   UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

GOLDEN_DIR="tests/golden"
FIX_DIR="$GOLDEN_DIR/fixtures"
EMIT_JSON="skills/magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="skills/magento2-module-review/scripts/emit-sarif.sh"
PLACEHOLDER="1970-01-01T00:00:00Z"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. Run emit-json.sh with fixed inputs; capture stdout (the JSON document).
FINDINGS_FILE="$FIX_DIR/findings.json" \
CONTEXT_FILE="$FIX_DIR/context.json" \
TARGET_MODULE="Acme_Golden" \
TARGET_PATH="src/app/code/Acme/Golden" \
MODE="full" \
SCOPE="module" \
OUTPUT_KIND="review" \
SKILL_NAME="magento2-module-review" \
SKILL_VERSION="2.3.0" \
SKILL_VERSIONS_JSON='["magento2-module-review@2.3.0","magento2-context@1.6.0"]' \
OUTPUT_DIR="$WORK" \
OUTPUT_BASENAME="golden" \
bash "$EMIT_JSON" > "$WORK/emit-json.raw.json" 2>"$WORK/emit-json.err" || {
    echo "FAIL: emit-json.sh exited non-zero:"; sed 's/^/    /' "$WORK/emit-json.err" >&2; exit 1; }

# 2. Normalize the runAt timestamp value.
sed 's#"runAt": "[^"]*"#"runAt": "'"$PLACEHOLDER"'"#g' \
    "$WORK/emit-json.raw.json" > "$WORK/emit-json.norm.json"

# 3. Feed the normalized JSON into emit-sarif.sh; capture stdout (the SARIF).
OUTPUT_DIR="$WORK" bash "$EMIT_SARIF" "$WORK/emit-json.norm.json" \
    > "$WORK/emit-sarif.out.sarif" 2>"$WORK/emit-sarif.err" || {
    echo "FAIL: emit-sarif.sh exited non-zero:"; sed 's/^/    /' "$WORK/emit-sarif.err" >&2; exit 1; }

JSON_GOLDEN="$GOLDEN_DIR/emit-json.expected.json"
SARIF_GOLDEN="$GOLDEN_DIR/emit-sarif.expected.sarif"

# 4. Refresh mode.
if [ "${UPDATE_GOLDEN:-}" = "1" ]; then
    mkdir -p "$GOLDEN_DIR"
    cp "$WORK/emit-json.norm.json" "$JSON_GOLDEN"
    cp "$WORK/emit-sarif.out.sarif" "$SARIF_GOLDEN"
    echo "updated goldens: $JSON_GOLDEN, $SARIF_GOLDEN"
    exit 0
fi

# 5. Compare against goldens.
FAIL=0
compare() { # name actual golden
    local name="$1" actual="$2" golden="$3"
    if [ ! -f "$golden" ]; then
        echo "FAIL: $name golden missing: $golden (run UPDATE_GOLDEN=1 to create it)"
        FAIL=1
        return
    fi
    if ! diff -u "$golden" "$actual"; then
        echo "FAIL: $name output drifted from golden ($golden)."
        echo "      If intentional, regenerate: UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh"
        FAIL=1
    fi
}
compare emit-json  "$WORK/emit-json.norm.json"  "$JSON_GOLDEN"
compare emit-sarif "$WORK/emit-sarif.out.sarif" "$SARIF_GOLDEN"

[ "$FAIL" -eq 0 ] || exit 1
echo "golden emitters: emit-json + emit-sarif match goldens"
exit 0
