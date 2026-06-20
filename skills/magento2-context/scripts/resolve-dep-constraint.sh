#!/usr/bin/env bash
# =============================================================================
# Resolve a BOUNDED composer version constraint for a dependency — never `*`.
#
# Usage: ./resolve-dep-constraint.sh <vendor/package> [project_root]
#
# Resolution order (first hit wins):
#   1. `composer show <package>` — the installed version (host or dockerized php).
#   2. <project_root>/composer.lock, then <project_root>/src/composer.lock.
#   3. <project_root>/src/composer.json (or composer.json) `require` value — reused
#      verbatim when it is already a bounded constraint.
#
# From a resolved X.Y.Z it prints `>=X.Y.0` (a stable, bounded floor; EQP rejects
# only `*` / `dev-` / `@dev`). Mirror the operator style of the store's own
# composer.json where it differs.
#
# Prints the constraint to stdout and exits 0 on success. On failure prints nothing
# and exits 1 — callers must ask the user, never fall back to `*`.
#
# Set NO_COMPOSER=1 to skip the composer probe (used by the test harness).
# =============================================================================
set -uo pipefail

pkg="${1:-}"
root="${2:-.}"

if [[ -z "$pkg" ]]; then
    echo "Usage: $0 <vendor/package> [project_root]" >&2
    exit 2
fi

# floor: vX.Y.Z | X.Y.Z(.anything) -> >=X.Y.0  (empty if not a recognisable version)
floor_from_version() {
    local v="${1#v}"
    if [[ "$v" =~ ^([0-9]+)\.([0-9]+)\. ]]; then
        printf '>=%s.%s.0' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    elif [[ "$v" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        printf '>=%s.%s.0' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    fi
}

# --- 1. composer show (installed version) ---
if [[ "${NO_COMPOSER:-0}" != "1" ]]; then
    COMPOSER_CMD=""
    if command -v composer >/dev/null 2>&1; then
        COMPOSER_CMD="composer"
    elif command -v docker >/dev/null 2>&1 && docker compose ps php 2>/dev/null | grep -q running; then
        COMPOSER_CMD="docker compose exec -T -u magento php composer"
    fi
    if [[ -n "$COMPOSER_CMD" ]]; then
        ver="$($COMPOSER_CMD show "$pkg" 2>/dev/null \
            | grep -E '^versions' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
        f="$(floor_from_version "${ver:-}")"
        if [[ -n "$f" ]]; then printf '%s\n' "$f"; exit 0; fi
    fi
fi

# --- 2. composer.lock (locked version) ---
parse_lock_version() { # <lockfile> <package>
    local lock="$1" p="$2"
    [[ -f "$lock" ]] || return 1
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$lock" "$p" <<'PY' || return 1
import json, sys
lock, pkg = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(lock, encoding="utf-8"))
except Exception:
    sys.exit(1)
for key in ("packages", "packages-dev"):
    for entry in data.get(key, []):
        if entry.get("name") == pkg and entry.get("version"):
            print(entry["version"]); sys.exit(0)
sys.exit(1)
PY
    else
        # best-effort grep fallback: version within ~20 lines after the name
        grep -A20 "\"name\": \"$p\"" "$lock" 2>/dev/null \
            | grep -m1 '"version":' \
            | sed -E 's/.*"version": *"([^"]+)".*/\1/'
    fi
}

for lock in "$root/composer.lock" "$root/src/composer.lock"; do
    ver="$(parse_lock_version "$lock" "$pkg" || true)"
    f="$(floor_from_version "${ver:-}")"
    if [[ -n "$f" ]]; then printf '%s\n' "$f"; exit 0; fi
done

# --- 3. existing require constraint in the project's composer.json ---
for cj in "$root/src/composer.json" "$root/composer.json"; do
    [[ -f "$cj" ]] || continue
    if command -v python3 >/dev/null 2>&1; then
        existing="$(python3 - "$cj" "$pkg" <<'PY' || true
import json, sys
cj, pkg = sys.argv[1], sys.argv[2]
try:
    data = json.load(open(cj, encoding="utf-8"))
except Exception:
    sys.exit(0)
val = data.get("require", {}).get(pkg) or data.get("require-dev", {}).get(pkg)
if val and val.strip() != "*":
    print(val.strip())
PY
)"
        if [[ -n "${existing:-}" ]]; then printf '%s\n' "$existing"; exit 0; fi
    fi
done

exit 1
