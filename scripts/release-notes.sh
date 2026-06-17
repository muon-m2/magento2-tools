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

# 1. both manifests must be at <version> — matched by the plugin's NAME (not "any entry"),
#    mirroring tests/test-plugin-marketplace-sync.sh.
verdict="$(python3 - "$ROOT" "$VERSION" <<'PY'
import json, os, sys
root, want = sys.argv[1], sys.argv[2]
def load(rel):
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        return json.load(fh)
try:
    plugin = load(".claude-plugin/plugin.json")
    market = load(".claude-plugin/marketplace.json")
except Exception as exc:
    print(f"err:cannot read manifest: {exc}"); sys.exit(0)
name = plugin.get("name")
if plugin.get("version") != want:
    print(f"err:plugin.json {name} is at {plugin.get('version')}, not {want}"); sys.exit(0)
entries = [p for p in (market.get("plugins") or []) if p.get("name") == name]
if not entries:
    print(f"err:marketplace.json has no plugin entry named {name}"); sys.exit(0)
if entries[0].get("version") != want:
    print(f"err:marketplace.json {name} is at {entries[0].get('version')}, not {want}"); sys.exit(0)
print("ok")
PY
)"
if [ "$verdict" != "ok" ]; then
    echo "release-notes: ${verdict#err:}" >&2
    exit 3
fi

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
