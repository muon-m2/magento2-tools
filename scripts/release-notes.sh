#!/usr/bin/env bash
# release-notes.sh — validate version consistency and emit GitHub-release notes for a tag.
#
# Usage:
#   scripts/release-notes.sh <version>          # print the CHANGELOG [<version>] section BODY (notes)
#   scripts/release-notes.sh --title <version>  # print the section HEADING text (release title)
#
# Files are read under RELEASE_NOTES_ROOT (default: repo root) so tests can use a fixture.
# Exits: 2 = no python3; 3 = a manifest is not at <version>; 4 = no CHANGELOG [<version>] section.
set -euo pipefail

MODE=body
if [ "${1:-}" = "--title" ]; then MODE=title; shift; fi
VERSION="${1:?usage: release-notes.sh [--title] <version>}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${RELEASE_NOTES_ROOT:-$HERE}"
CHANGELOG="$ROOT/CHANGELOG.md"

command -v python3 >/dev/null 2>&1 || { echo "release-notes: python3 required" >&2; exit 2; }

# 1. both manifests must be at <version>
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    ok="$(python3 - "$ROOT/$f" "$VERSION" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1])); want = sys.argv[2]
vers = []
if isinstance(doc.get("version"), str): vers.append(doc["version"])
for p in (doc.get("plugins") or []):
    if isinstance(p.get("version"), str): vers.append(p["version"])
print("yes" if want in vers else "no")
PY
)" || { echo "release-notes: cannot read $ROOT/$f" >&2; exit 3; }
    [ "$ok" = "yes" ] || { echo "release-notes: $f is not at version $VERSION" >&2; exit 3; }
done

# 2. a CHANGELOG section for <version> must exist
[ -f "$CHANGELOG" ] || { echo "release-notes: $CHANGELOG not found" >&2; exit 4; }
grep -qF "## [$VERSION]" "$CHANGELOG" || { echo "release-notes: no CHANGELOG section [$VERSION]" >&2; exit 4; }

# 3. emit heading (title) or body (notes)
awk -v ver="$VERSION" -v mode="$MODE" '
    index($0, "## [" ver "]") == 1 {
        insec=1
        if (mode == "title") { h=$0; sub(/^## /, "", h); print h }
        next
    }
    insec && /^## \[/ { insec=0 }
    insec && mode == "body" { print }
' "$CHANGELOG"
