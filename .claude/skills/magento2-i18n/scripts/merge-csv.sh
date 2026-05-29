#!/usr/bin/env bash
# merge-csv.sh — merge a freshly-extracted phrase CSV into an existing locale CSV.
#
# Guarantees:
#   - Existing translations are preserved byte-for-byte (no overwrite, ever).
#   - New phrases are appended at the end with empty translation columns.
#   - Phrases present in the locale CSV but missing from the fresh extraction are
#     considered obsolete and written to <locale>.obsolete.csv (NOT commented in-line —
#     comments break Magento's translation loader).
#   - Output is always valid Magento i18n CSV: two columns ("source","translation"),
#     CRLF or LF preserved from the original locale CSV.
#
# Usage:
#   merge-csv.sh <fresh-extracted.csv> <locale.csv>
#
# Behaviour:
#   - Overwrites <locale.csv> in place (preserving translations).
#   - Writes <locale>.obsolete.csv next to <locale.csv> when obsolete phrases exist;
#     deletes that file when there are none.
#
# Exit codes:
#   0   success (writes summary to stderr)
#   2   bad arguments / file missing
#   3   python3 not available

set -uo pipefail

FRESH="${1:?usage: merge-csv.sh <fresh-extracted.csv> <locale.csv>}"
LOCALE="${2:?usage: merge-csv.sh <fresh-extracted.csv> <locale.csv>}"

[ -f "$FRESH" ]  || { echo "merge-csv: fresh file not found: $FRESH" >&2;  exit 2; }
[ -f "$LOCALE" ] || { echo "merge-csv: locale file not found: $LOCALE" >&2; exit 2; }

if ! command -v python3 >/dev/null 2>&1; then
    echo "merge-csv: python3 is required" >&2
    exit 3
fi

OBSOLETE="${LOCALE%.csv}.obsolete.csv"

FRESH="$FRESH" LOCALE="$LOCALE" OBSOLETE="$OBSOLETE" python3 <<'PY'
import csv
import io
import os
import sys


def read_rows(path):
    """Return (rows, line_terminator). rows is a list of [source, translation]."""
    with open(path, 'rb') as fh:
        raw = fh.read()
    # Detect line terminator from the first newline.
    nl = '\r\n' if b'\r\n' in raw else '\n'
    text = raw.decode('utf-8-sig')  # tolerate BOM
    reader = csv.reader(io.StringIO(text))
    rows = []
    for row in reader:
        if not row:
            continue
        # Magento i18n format is exactly 2 columns. Tolerate stragglers.
        if len(row) == 1:
            row = [row[0], '']
        rows.append([row[0], row[1] if len(row) > 1 else ''])
    return rows, nl


def write_rows(path, rows, nl):
    with open(path, 'w', encoding='utf-8', newline='') as fh:
        writer = csv.writer(fh, lineterminator=nl, quoting=csv.QUOTE_ALL)
        for r in rows:
            writer.writerow(r)


fresh_path = os.environ['FRESH']
locale_path = os.environ['LOCALE']
obsolete_path = os.environ['OBSOLETE']

fresh_rows, _ = read_rows(fresh_path)
locale_rows, nl = read_rows(locale_path)

fresh_keys = {r[0]: r for r in fresh_rows}
locale_keys = {r[0]: r for r in locale_rows}

merged = []
# 1. Preserve every locale row in original order, with original translation.
seen_in_locale = set()
for src, tr in locale_rows:
    if src in seen_in_locale:
        continue
    seen_in_locale.add(src)
    if src in fresh_keys:
        merged.append([src, tr])  # keep existing translation
    # else: source is no longer in fresh — handled below as obsolete

# 2. Append new phrases from fresh, in fresh order, with empty translation.
for src, _ in fresh_rows:
    if src not in seen_in_locale:
        merged.append([src, ''])
        seen_in_locale.add(src)

# 3. Collect obsolete phrases.
obsolete = [r for r in locale_rows if r[0] not in fresh_keys]

# Write merged locale CSV.
write_rows(locale_path, merged, nl)

# Write or remove obsolete CSV.
if obsolete:
    write_rows(obsolete_path, obsolete, nl)
else:
    if os.path.exists(obsolete_path):
        os.remove(obsolete_path)

added = sum(1 for r in merged if r[0] not in {x[0] for x in locale_rows})
sys.stderr.write(
    f"merge-csv: kept={len(merged) - added} added={added} obsolete={len(obsolete)} "
    f"(locale={locale_path})\n"
)
if obsolete:
    sys.stderr.write(f"merge-csv: wrote obsolete phrases to {obsolete_path}\n")
PY
