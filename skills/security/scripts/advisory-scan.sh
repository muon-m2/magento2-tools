#!/usr/bin/env bash
# advisory-scan.sh — live dependency-advisory + Adobe patch-state scan.
#
# Replaces the pre-2.0 cve-scan.sh. No advisory data ships with the skill: everything
# is resolved live at scan time from two self-contained sources —
#
#   1. `composer audit` (Packagist + FriendsOfPHP advisory DB; needs network). When it
#      cannot run (offline, composer missing, no lockfile) the scan degrades to [] and
#      records WHY on stderr, which build-findings.sh routes into scanner_errors — so
#      "advisories skipped" is never silently read as "no advisories".
#   2. `vendor/bin/patch-status` — Adobe's own per-CVE verdict tool, when the store
#      ships it. It consults Adobe's advisory registry and answers "is APSB-XX applied?"
#      directly; VULNERABLE verdicts become findings. Absence is recorded on stderr.
#
# Inputs:
#   $1                Path to composer.lock (default: composer.lock or src/composer.lock)
#   RUNNER            Runner prefix for vendor/bin/patch-status, e.g.
#                     "docker compose exec -T -u magento php" (default: "" — host).
#                     The tool is PHP and shells out to patch(1), so on a Dockerised
#                     stack it usually only works through the runner.
#   SCOPE, TARGET_PATH  At module/vendor scope (SCOPE unset counts as module) with a
#                     TARGET_PATH/composer.json, advisories for packages outside the target's
#                     dependency closure (resolved from composer.lock) drop to info as
#                     site-scope findings. Site scope, or no target composer.json: unchanged.
#   PATCH_STATUS      "0" disables running vendor/bin/patch-status, for operators who
#                     would rather the scanner not execute a binary from the scanned
#                     tree (default: "1"). CVE_PATCH_STATUS is honoured as a legacy alias.
#
# Output: a findings-schema JSON array on stdout. Degradations on stderr.

set -uo pipefail

COMPOSER_LOCK="${1:-$([[ -f composer.lock ]] && echo composer.lock || echo src/composer.lock)}"

if ! command -v python3 >/dev/null 2>&1; then
    echo "[]"
    exit 0
fi

# --- composer audit -----------------------------------------------------------
# IMPORTANT (SEC-1): `composer audit` exits NON-ZERO precisely when it finds advisories.
# Capture stdout regardless of exit code (the JSON is authoritative) and let the Python
# pass surface any parse failure on stderr.
AUDIT_OUTPUT=""
if [ ! -f "$COMPOSER_LOCK" ]; then
    echo "advisory-scan: no composer.lock at ${COMPOSER_LOCK} — dependency advisories were NOT checked" >&2
elif ! command -v composer >/dev/null 2>&1; then
    echo "advisory-scan: composer not on PATH — dependency advisories were NOT checked" >&2
else
    AUDIT_OUTPUT="$(composer audit --working-dir="$(dirname "$COMPOSER_LOCK")" --format=json 2>/dev/null)" || true
    if [ -z "$AUDIT_OUTPUT" ]; then
        echo "advisory-scan: composer audit produced no output (composer error, missing deps, or no network) — dependency advisories were NOT checked" >&2
    fi
fi

# --- vendor/bin/patch-status --------------------------------------------------
# Adobe decoupled "is this fixed" from "what version am I": isolated patches carry
# security fixes with no version bump, so composer.lock cannot see patch state. The
# tool ships INSIDE the security patches and consults Adobe's advisory registry, so its
# verdicts are authoritative. Its exit code is NOT a success signal (without patch(1)
# it prints an error and still exits 0) — validity is decided by parsing the JSON.
PATCH_STATUS_FILE=""
PATCH_STATUS="${PATCH_STATUS:-${CVE_PATCH_STATUS:-1}}"
RUNNER="${RUNNER:-}"
MAGENTO_ROOT="$(dirname "$COMPOSER_LOCK")"
[ -z "$MAGENTO_ROOT" ] && MAGENTO_ROOT="."

if [ "$PATCH_STATUS" != "0" ] && [ -x "${MAGENTO_ROOT}/vendor/bin/patch-status" ]; then
    _ps_raw="$(mktemp)"
    trap 'rm -f "$_ps_raw"' EXIT
    # RUNNER is a command PREFIX that word-splits into argv, so it is collected into an
    # array rather than left unquoted at the point of use.
    _ps_cmd=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        _ps_cmd=($RUNNER)
    fi
    _ps_cmd+=(vendor/bin/patch-status --format json)
    (cd "$MAGENTO_ROOT" && timeout 120 "${_ps_cmd[@]}") > "$_ps_raw" 2>/dev/null || true
    if python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
sys.exit(0 if isinstance(d.get('vulnerability_status'), dict) else 1)
" "$_ps_raw" 2>/dev/null; then
        PATCH_STATUS_FILE="$_ps_raw"
    else
        rm -f "$_ps_raw"
        echo "advisory-scan: vendor/bin/patch-status present but produced no usable JSON — it failed to run, or emitted something unparseable. Most often patch(1) is missing or it needs the app container (pass RUNNER=...); a PHP error, a missing timeout(1), or permissions look the same. Adobe patch-state verdicts unavailable this run." >&2
    fi
elif [ "$PATCH_STATUS" != "0" ]; then
    echo "advisory-scan: vendor/bin/patch-status not installed — Adobe patch-state verdicts (is APSB-XX applied?) unavailable; composer-level advisories above still apply" >&2
fi

AUDIT_OUTPUT="$AUDIT_OUTPUT" \
COMPOSER_LOCK="$COMPOSER_LOCK" \
PATCH_STATUS_FILE="$PATCH_STATUS_FILE" \
ADV_SCOPE="${SCOPE:-module}" \
ADV_TARGET_PATH="${TARGET_PATH:-}" \
python3 <<'PY'
import json
import os
import sys


def severity_norm(sev):
    sev = (sev or 'medium').lower()
    return sev if sev in ('critical', 'high', 'medium', 'low', 'info') else 'medium'


lock_path = os.environ['COMPOSER_LOCK']
audit_raw = os.environ.get('AUDIT_OUTPUT', '')
audit = {}
if audit_raw.strip():
    try:
        audit = json.loads(audit_raw)
    except Exception:
        # Do NOT swallow this: a parse failure here means real advisories may be going
        # unreported. Surface it on stderr so build-findings.sh records it in scanner_errors.
        sys.stderr.write(
            "advisory-scan: composer audit output was not valid JSON; dependency advisories "
            "were NOT parsed — investigate manually with `composer audit`.\n"
        )
        audit = {}

def _is_platform(name):
    return name in ('php', 'php-64bit', 'hhvm', 'composer', 'composer-plugin-api',
                    'composer-runtime-api') or name.startswith(('ext-', 'lib-'))


def dependency_closure(target_json, lock):
    """Package names reachable from target_json's `require` through the lock's `require`s.

    Pure function over parsed JSON. `replace`/`provide` names resolve to the package that
    declares them. require-dev is not followed: a module's dev deps never ship with it.
    """
    pkgs = {}
    alias = {}
    for p in (lock.get('packages') or []) + (lock.get('packages-dev') or []):
        if not isinstance(p, dict) or not p.get('name'):
            continue
        name = p['name'].lower()
        pkgs[name] = p
        for key in ('replace', 'provide'):
            for virt in (p.get(key) or {}):
                alias.setdefault(virt.lower(), name)
    seen = set()
    own = (target_json.get('name') or '').lower()
    todo = [own] if own else []
    todo += list(target_json.get('require') or {})
    while todo:
        name = todo.pop().lower()
        if _is_platform(name):
            continue
        name = alias.get(name, name) if name not in pkgs else name
        if name in seen:
            continue
        seen.add(name)
        todo += list((pkgs.get(name) or {}).get('require') or {})
    return seen


# Module/vendor scope: resolve the target's closure, or None to leave severities alone.
closure = None
target_name = ''
target_path = os.environ.get('ADV_TARGET_PATH', '')
if os.environ.get('ADV_SCOPE', 'module') != 'site' and target_path:
    tj = os.path.join(target_path, 'composer.json')
    lock_dir = os.path.dirname(os.path.abspath(lock_path))
    # The project root's own composer.json IS the site — its closure is everything.
    if os.path.isfile(tj) and os.path.abspath(target_path) != lock_dir:
        try:
            with open(tj, encoding='utf-8') as fh:
                target_json = json.load(fh)
            with open(lock_path, encoding='utf-8') as fh:
                lock = json.load(fh)
            closure = dependency_closure(target_json, lock)
            target_name = target_json.get('name') or os.path.basename(os.path.abspath(target_path))
        except (OSError, ValueError, AttributeError) as exc:
            sys.stderr.write(f"advisory-scan: could not resolve the dependency tree of {tj} ({exc}); "
                             "all advisories reported at their own severity.\n")
            closure = None

out = []
fid = 1

# --- composer audit advisories ---
advisories = audit.get('advisories') or {}
for pkg, items in advisories.items():
    for adv in items:
        sev = severity_norm(adv.get('severity'))
        # reportedAt and sources are defensively coerced: composer audit can emit a
        # non-string reportedAt or an empty sources list.
        reported = adv.get('reportedAt')
        reported = reported if isinstance(reported, str) else ''
        sources = adv.get('sources') or [{}]
        first_source = sources[0] if (sources and isinstance(sources[0], dict)) else {}
        remote_id = first_source.get('remoteId') or ''
        out.append({
            'id': f'security-adv-{fid:03d}',
            'severity': sev,
            'category': 'cve',
            'confidence': 'confirmed',
            'title': f"{adv.get('title') or 'Advisory'} ({pkg})",
            'description': (reported + ' — ' + remote_id).strip(' —'),
            'evidence': [{'file': lock_path, 'line': 1, 'snippet': pkg}],
            # `or`-chained, NOT adv.get('cve', <fallback>): composer audit emits the `cve`
            # key with a JSON null for GHSA-only advisories, and dict.get returns that null
            # instead of the default whenever the KEY EXISTS. remote_id BEFORE advisoryId:
            # remote_id is the upstream identifier an operator can look up (GHSA-…), while
            # advisoryId is Packagist's internal key (PKSA-…).
            'recommendation': (
                f"Upgrade {pkg} to a version not affected by "
                f"{adv.get('cve') or remote_id or adv.get('advisoryId') or 'this advisory'}."
            ),
            'verification': 'Re-run composer audit; advisory should disappear.',
            'cve': adv.get('cve'),
            'tags': [pkg, 'composer-audit'],
        })
        # Outside the target's tree: a site-wide CVE, not this module's. Title stays
        # module-neutral so the same finding dedupes across per-module reports.
        if closure is not None and pkg.lower() not in closure:
            f = out[-1]
            f['description'] = (
                f"{pkg} is not in {target_name}'s dependency tree; site-scope finding "
                f"(advisory severity {sev}). " + f['description']
            ).strip()
            f['severity'] = 'info'
            f['title'] += ' [site-scope: outside module dependency tree]'
            f['tags'].append('site-scope')
        fid += 1

# --- Adobe patch-status verdicts ---
# Only VULNERABLE becomes a finding: it is proven-unpatched, strictly better evidence
# than an in-range version number. PROTECTED and NOT_APPLICABLE are nothing-to-do by
# Adobe's own definition; UNKNOWN carries no information worth a finding.
ps_path = os.environ.get('PATCH_STATUS_FILE', '')
if ps_path and os.path.isfile(ps_path):
    try:
        with open(ps_path, encoding='utf-8') as fh:
            status_map = json.load(fh).get('vulnerability_status') or {}
    except (OSError, ValueError):
        status_map = {}
    for cve, entry in sorted(status_map.items()):
        status = entry.get('status') if isinstance(entry, dict) else entry
        if not (isinstance(cve, str) and isinstance(status, str)):
            continue
        if status.strip().upper() != 'VULNERABLE':
            continue
        cve_id = cve.strip().upper()
        out.append({
            'id': f'security-adv-{fid:03d}',
            'severity': 'high',
            'category': 'cve',
            'confidence': 'confirmed',
            'title': f"Magento core unpatched against {cve_id} (Adobe patch-status: VULNERABLE)",
            'description': (
                "vendor/bin/patch-status — Adobe's own per-advisory verdict tool — reports "
                f"this store VULNERABLE to {cve_id}. Isolated patches carry security fixes "
                "with no version bump, so composer.lock cannot see this."
            ),
            'evidence': [{'file': lock_path, 'line': 1, 'snippet': cve_id}],
            'recommendation': (
                f"Apply the Adobe isolated patch or hotfix covering {cve_id} "
                "(see the matching APSB bulletin), or upgrade to a release that includes the fix."
            ),
            'verification': 'Re-run vendor/bin/patch-status --format json; the verdict should become PROTECTED.',
            'cve': cve_id,
            'tags': ['magento-core', 'patch-status'],
        })
        fid += 1

print(json.dumps(out, indent=2))
PY
