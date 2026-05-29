#!/usr/bin/env bash
# i18n merge-csv must: preserve existing translations, append new phrases with empty
# translation, and write obsolete phrases to <locale>.obsolete.csv.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../../.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/fresh.csv" <<'EOF'
"Hello",""
"Goodbye",""
"New Phrase",""
EOF
cat > "$WORK/de_DE.csv" <<'EOF'
"Hello","Hallo"
"Goodbye","Auf Wiedersehen"
"Removed Old","Entfernt"
EOF

bash .claude/skills/magento2-i18n/scripts/merge-csv.sh "$WORK/fresh.csv" "$WORK/de_DE.csv" 2>/dev/null

# Translation preserved
if ! grep -q '"Hello","Hallo"' "$WORK/de_DE.csv"; then
    echo "FAIL: existing translation for 'Hello' not preserved"
    cat "$WORK/de_DE.csv"
    exit 1
fi
# New phrase appended with empty translation
if ! grep -q '"New Phrase",""' "$WORK/de_DE.csv"; then
    echo "FAIL: new phrase not appended with empty translation"
    cat "$WORK/de_DE.csv"
    exit 1
fi
# Obsolete phrase NOT in merged locale
if grep -q '"Removed Old"' "$WORK/de_DE.csv"; then
    echo "FAIL: obsolete phrase still in merged locale CSV"
    exit 1
fi
# Obsolete phrase IS in obsolete file
if [ ! -f "$WORK/de_DE.obsolete.csv" ] || ! grep -q '"Removed Old","Entfernt"' "$WORK/de_DE.obsolete.csv"; then
    echo "FAIL: obsolete phrase not written to <locale>.obsolete.csv"
    exit 1
fi

exit 0
