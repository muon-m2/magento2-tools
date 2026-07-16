#!/usr/bin/env bash
# Mage-OS: `magento_version` must carry the MAGENTO BASE version, never the Mage-OS
# distribution version.
#
# Mage-OS versions its distribution independently of Magento — Mage-OS 3.2.0 is based on
# Magento 2.4.9, and "3.2.0" is not a Magento version at all. The base is published as
# `extra.magento_version` on the mage-os/product-community-edition metapackage, which is
# why composer.lock (the installed, pinned metadata) is the source of truth here and the
# root composer.json `require` constraint is not.
#
# REGRESSION GUARD (CTX-Mage-OS): the resolver used to strip the operators off the
# composer.json constraint ("~3.2.0" -> "3.2.0") and emit that as magento_version. Every
# downstream consumer compares that value against 2.4.x ranges, so it silently matched
# NOTHING: cve-scan.sh's version_in_range() returned false for every advisory, and the
# BC-break matrix found no entries. Silent false negatives on a security scan are worse
# than no scan, so this test pins the base version explicitly.
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
    "mage-os/product-community-edition": "~3.2.0"
  }
}
EOF

# Mirrors the real metapackage metadata served from https://repo.mage-os.org/ —
# mage-os/product-community-edition 3.2.0 carries extra.magento_version = 2.4.9.
cat > "$WORK/composer.lock" <<'EOF'
{
  "packages": [
    {
      "name": "mage-os/product-community-edition",
      "version": "3.2.0",
      "type": "metapackage",
      "extra": { "magento_version": "2.4.9" }
    }
  ]
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
version = d.get("magento_version")
src = d.get("resolution_source", {}).get("magento_version") or ""

if edition != "mage-os":
    print(f"FAIL: edition={edition!r} (expected 'mage-os')")
    sys.exit(1)

# The bug: "3.2.0" is the Mage-OS distribution version, not a Magento version.
if version == "3.2.0":
    print("FAIL: magento_version=3.2.0 — that is the Mage-OS distribution version, "
          "not the Magento base. Expected 2.4.9 from extra.magento_version.")
    sys.exit(1)

if version != "2.4.9":
    print(f"FAIL: magento_version={version!r} (expected '2.4.9' from "
          f"composer.lock extra.magento_version)")
    sys.exit(1)

# Provenance must point at the lock, not the composer.json constraint — otherwise a
# future reader cannot tell a resolved base version from a stripped constraint.
if "composer.lock" not in src:
    print(f"FAIL: resolution_source.magento_version={src!r} "
          f"(expected it to cite composer.lock)")
    sys.exit(1)

# The distribution version is the Mage-OS release actually installed — and the ONLY
# signal that distinguishes a patched store from an unpatched one, since 3.0.0, 3.1.0
# and 3.2.0 all report base 2.4.9 while only 3.2.0 carries Adobe's July patch.
dv = d.get("distribution_version")
dv_src = d.get("resolution_source", {}).get("distribution_version") or ""

if dv != "3.2.0":
    print(f"FAIL: distribution_version={dv!r} (expected '3.2.0' from the "
          f"composer.lock package version)")
    sys.exit(1)

if dv == d.get("magento_version"):
    print("FAIL: distribution_version mirrors magento_version on Mage-OS — the two "
          "MUST diverge here (3.2.0 is based on 2.4.9)")
    sys.exit(1)

if "composer.lock" not in dv_src:
    print(f"FAIL: resolution_source.distribution_version={dv_src!r} "
          f"(expected it to cite composer.lock)")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

# --- Honest gap: Mage-OS with no lock ----------------------------------------
# Without the lock there is no way to map the distribution version onto a Magento base.
# The tempting "fallback" is the composer.json constraint — which is exactly the bug this
# file guards, so null is the only correct answer here. A future reader may see the null
# as a gap worth "fixing" with that fallback; this pins it shut.
rm -f "$WORK/composer.lock"

OUT="$(cd "$WORK" && bash skills/magento2-context/scripts/resolve-context.sh --no-cache 2>/dev/null || true)"

python3 - "$OUT" <<'PY'
import sys, json
d = json.loads(sys.argv[1])

version = d.get("magento_version")
src = d.get("resolution_source", {}).get("magento_version") or ""

if version == "3.2.0":
    print("FAIL: fell back to the composer.json constraint (3.2.0) when the lock was "
          "absent — that is the Mage-OS distribution version, not a Magento version.")
    sys.exit(1)

if version is not None:
    print(f"FAIL: magento_version={version!r} with no lock (expected JSON null)")
    sys.exit(1)

# A null must always explain itself — an unexplained null is indistinguishable from a
# resolver crash.
if not src:
    print("FAIL: magento_version is null but resolution_source.magento_version is empty "
          "(honest-gap rule: a gap must say why)")
    sys.exit(1)

# edition must survive: we still know it is a Mage-OS store, we just lack the base.
if d.get("edition") != "mage-os":
    print(f"FAIL: edition={d.get('edition')!r} (expected 'mage-os' even without a lock)")
    sys.exit(1)

# Losing the base is no reason to also suppress the distribution. Unlike the base, the
# composer.json constraint IS a distribution constraint, so stripping "~3.2.0" -> "3.2.0"
# is legitimate here. This asymmetry is deliberate: the same fallback is FORBIDDEN for
# magento_version above.
dv = d.get("distribution_version")
dv_src = d.get("resolution_source", {}).get("distribution_version") or ""

if dv != "3.2.0":
    print(f"FAIL: distribution_version={dv!r} with no lock (expected '3.2.0' stripped "
          f"from the composer.json constraint)")
    sys.exit(1)

if not dv_src:
    print("FAIL: distribution_version set but resolution_source is empty")
    sys.exit(1)

# The source must reveal this came from a constraint, not a pinned version — a reader
# must be able to tell an exact release from an approximation.
if "constraint" not in dv_src:
    print(f"FAIL: resolution_source.distribution_version={dv_src!r} does not disclose "
          f"that the value came from a constraint rather than a pinned version")
    sys.exit(1)
PY
[ $? -eq 0 ] || exit 1

exit 0
