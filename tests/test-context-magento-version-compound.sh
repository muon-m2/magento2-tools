#!/usr/bin/env bash
# `magento_version` must never be a glued-together fiction on the magento/* editions.
#
# REGRESSION GUARD (CTX-Compound-MagentoVersion): the mage-os `distribution_version`
# fallback (tests/test-context-mageos-base-version.sh) was already fixed to strip
# constraint operator CHARACTERS only (never the space) and validate the result before
# publishing it — a compound/range constraint like ">=3.0 <4.0" therefore nulls out
# instead of gluing into "3.04.0". The IDENTICAL bug was still live for `magento_version`
# on the commerce-cloud, commerce, and open-source branches, which have no lock-based
# fallback: the composer.json constraint is the SOLE source, and `magento_version` is the
# field cve-scan.sh actually matches CVEs against (distribution_version feeds nothing
# today). A store pinned to a compound or wildcard constraint therefore reported clean
# regardless of its real version:
#   ">=2.4.6 <2.4.8"  -> old: "2.4.62.4.8" -> parse_version() -> (2,4,62,0) -> no match
#   "2.4.*"           -> old: "2.4."       -> parse_version() -> None       -> no match
#   "^2.4"            -> old: "2.4"        -> parse_version() -> None       -> no match
# This test pins that all three shapes now null out honestly (with a reason naming the
# raw constraint) instead of publishing a plausible-but-wrong version, on all three
# magento/* editions. It also pins that a correctly 3-component constraint still resolves
# — the fix must not turn every constraint into a null.
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

run_resolver() {
    (cd "$WORK" && bash skills/magento2-context/scripts/resolve-context.sh --no-cache 2>/dev/null || true)
}

check_null_with_reason() {
    # $1 = OUT json, $2 = expected edition, $3 = raw constraint that must be cited
    python3 - "$1" "$2" "$3" <<'PY'
import sys, json
out, expected_edition, raw = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.loads(out)

edition = d.get("edition")
if edition != expected_edition:
    print(f"FAIL: edition={edition!r} (expected {expected_edition!r})")
    sys.exit(1)

mv = d.get("magento_version")
mv_src = d.get("resolution_source", {}).get("magento_version") or ""

# The bug signature: a glued/partial-but-parseable-looking string.
if mv is not None and mv != "null":
    print(f"FAIL: magento_version={mv!r} — expected JSON null for an unparseable "
          f"compound/wildcard constraint (raw={raw!r}); publishing a value here is "
          f"exactly the silent-false-negative bug this test guards.")
    sys.exit(1)

if not mv_src:
    print("FAIL: magento_version is null but resolution_source.magento_version is "
          "empty (honest-gap rule: a gap must say why)")
    sys.exit(1)

if raw not in mv_src:
    print(f"FAIL: resolution_source.magento_version={mv_src!r} does not cite the raw "
          f"constraint ({raw!r}) that could not be parsed")
    sys.exit(1)

# distribution_version mirrors magento_version on magento/* editions. When
# magento_version is null, the mirror must follow it honestly — not resurrect a stale
# or glued value.
dv = d.get("distribution_version")
if dv is not None and dv != "null":
    print(f"FAIL: distribution_version={dv!r} — expected JSON null: it mirrors "
          f"magento_version, which is null here")
    sys.exit(1)

dv_src = d.get("resolution_source", {}).get("distribution_version") or ""
if not dv_src:
    print("FAIL: distribution_version is null but resolution_source.distribution_version "
          "is empty (honest-gap rule)")
    sys.exit(1)
PY
}

# --- open-source: compound range constraint -----------------------------------------
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-community-edition": ">=2.4.6 <2.4.8"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (open-source compound)"; exit 1; }
check_null_with_reason "$OUT" "open-source" ">=2.4.6 <2.4.8" || exit 1

# --- open-source: wildcard constraint -------------------------------------------------
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-community-edition": "2.4.*"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (open-source wildcard)"; exit 1; }
check_null_with_reason "$OUT" "open-source" "2.4.*" || exit 1

# --- open-source: caret 2-component constraint ----------------------------------------
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-community-edition": "^2.4"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (open-source caret)"; exit 1; }
check_null_with_reason "$OUT" "open-source" "^2.4" || exit 1

# --- commerce: compound range constraint ----------------------------------------------
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-enterprise-edition": ">=2.4.6 <2.4.8"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (commerce compound)"; exit 1; }
check_null_with_reason "$OUT" "commerce" ">=2.4.6 <2.4.8" || exit 1

# --- commerce-cloud: compound range constraint ----------------------------------------
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-enterprise-edition": ">=2.4.6 <2.4.8",
    "magento/magento-cloud-metapackage": ">=2.4.6 <2.4.8"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (commerce-cloud compound)"; exit 1; }
check_null_with_reason "$OUT" "commerce-cloud" ">=2.4.6 <2.4.8" || exit 1

# --- Control: a correctly-resolvable 3-component constraint MUST still resolve --------
# The fix must reject unparseable shapes, not every constraint.
cat > "$WORK/composer.json" <<'EOF'
{
  "require": {
    "magento/product-community-edition": "2.4.6-p3"
  }
}
EOF
OUT="$(run_resolver)"
[ -n "$OUT" ] || { echo "FAIL: resolver produced no output (open-source control)"; exit 1; }
python3 - "$OUT" <<'PY'
import sys, json
d = json.loads(sys.argv[1])
mv = d.get("magento_version")
if mv != "2.4.6-p3":
    print(f"FAIL: magento_version={mv!r} (expected '2.4.6-p3' — a valid 3-component "
          f"constraint with a -pN suffix must still resolve; the fix must not reject "
          f"every constraint)")
    sys.exit(1)
dv = d.get("distribution_version")
if dv != mv:
    print(f"FAIL: distribution_version={dv!r} != magento_version={mv!r} on a resolved "
          f"magento/* edition (mirror invariant)")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

exit 0
