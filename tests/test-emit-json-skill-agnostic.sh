#!/usr/bin/env bash
# emit-json.sh must label its output with the SKILL_NAME env var (not hard-coded).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo '[]' > "$WORK/findings.json"

FINDINGS_FILE="$WORK/findings.json" \
TARGET_MODULE="Acme_Test" \
TARGET_PATH="src/app/code/Acme/Test" \
SKILL_NAME="magento2-security-audit" \
SKILL_VERSION="9.9.9" \
OUTPUT_KIND="security" \
OUTPUT_DIR="$WORK/out" \
OUTPUT_BASENAME="custom-name" \
SKILL_VERSIONS_JSON='["magento2-security-audit@9.9.9","magento2-context@1.0.0"]' \
bash skills/magento2-context/scripts/emit-json.sh > "$WORK/stdout.json" 2>/dev/null

if [ ! -f "$WORK/out/custom-name.json" ]; then
    echo "FAIL: expected output file at $WORK/out/custom-name.json"
    exit 1
fi

SKILL=$(python3 -c "import json; print(json.load(open('$WORK/out/custom-name.json'))['skill'])")
KIND=$(python3 -c "import json; print(json.load(open('$WORK/out/custom-name.json')).get('outputKind') or '')")
VERSIONS=$(python3 -c "import json; print(','.join(json.load(open('$WORK/out/custom-name.json')).get('skillVersions') or []))")

if [ "$SKILL" != "magento2-security-audit" ]; then
    echo "FAIL: skill='$SKILL' (expected magento2-security-audit)"
    exit 1
fi
if [ "$KIND" != "security" ]; then
    echo "FAIL: outputKind='$KIND' (expected security)"
    exit 1
fi
if [ "$VERSIONS" != "magento2-security-audit@9.9.9,magento2-context@1.0.0" ]; then
    echo "FAIL: skillVersions='$VERSIONS'"
    exit 1
fi

exit 0
