#!/usr/bin/env bash
# test-plugin-marketplace-sync.sh — the plugin's version must match in both manifests.
#
# .claude-plugin/plugin.json `version` MUST equal the matching plugin entry's `version`
# in .claude-plugin/marketplace.json. They drift silently otherwise (PKG gap).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

PLUGIN=".claude-plugin/plugin.json"
MARKET=".claude-plugin/marketplace.json"

for f in "$PLUGIN" "$MARKET"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: $f not found"
        exit 1
    fi
done

python3 - "$PLUGIN" "$MARKET" <<'PY'
import json
import sys

plugin_path, market_path = sys.argv[1], sys.argv[2]
plugin = json.load(open(plugin_path))
market = json.load(open(market_path))

name = plugin.get("name")
pv = plugin.get("version")
if not name or not pv:
    print(f"FAIL: plugin.json missing name/version (name={name!r}, version={pv!r})")
    sys.exit(1)

entries = [p for p in market.get("plugins", []) if p.get("name") == name]
if not entries:
    print(f"FAIL: marketplace.json has no plugin entry named {name!r}")
    sys.exit(1)

mv = entries[0].get("version")
if mv != pv:
    print(f"FAIL: version drift — plugin.json {name}@{pv} != marketplace.json {name}@{mv}")
    sys.exit(1)

print(f"plugin/marketplace versions in sync: {name}@{pv}")
PY
exit $?
