#!/usr/bin/env bash
# `distribution_version` = "the version of what you actually installed".
#
# On the magento/* editions the distribution IS Magento, so it mirrors magento_version:
# the product metapackages version in lockstep with the release. Mirroring (rather than
# nulling on non-forks) is what lets every consumer read one field unconditionally —
# `ctx.distribution_version` — with no edition branching at the call site.
#
# Mage-OS, where the two genuinely diverge, is covered by
# tests/test-context-mageos-base-version.sh.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v php >/dev/null 2>&1; then
    echo "skip: php not on PATH"
    exit 77
fi
if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp -r skills "$WORK/" 2>/dev/null || true

cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-community-edition": "2.4.9"
  }
}
EOF

OUT="$(cd "$WORK" && bash skills/magento2-context/scripts/resolve-context.sh --no-cache 2>/dev/null || true)"

if [ -z "$OUT" ]; then
    echo "FAIL: resolver produced no output"
    exit 1
fi

python3 - "$OUT" <<'PY'
import sys, json
d = json.loads(sys.argv[1])

edition = d.get("edition")
mv = d.get("magento_version")
dv = d.get("distribution_version")
src = d.get("resolution_source", {}).get("distribution_version") or ""

if edition != "open-source":
    print(f"FAIL: edition={edition!r} (expected 'open-source')")
    sys.exit(1)

if mv != "2.4.9":
    print(f"FAIL: magento_version={mv!r} (expected '2.4.9')")
    sys.exit(1)

# The mirror invariant.
if dv != mv:
    print(f"FAIL: distribution_version={dv!r} != magento_version={mv!r} — on a "
          f"magento/* edition the distribution IS Magento, so they must match")
    sys.exit(1)

# Mirrored is not the same as absent: a null here would force every consumer to
# coalesce, which is the design we rejected.
if dv is None:
    print("FAIL: distribution_version is null on open-source (expected the mirror)")
    sys.exit(1)

if not src:
    print("FAIL: distribution_version set but resolution_source.distribution_version "
          "is empty (honest-gap rule: every value states its provenance)")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

exit 0
