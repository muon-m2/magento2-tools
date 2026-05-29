#!/usr/bin/env bash
# preflight.sh — run the pre-flight check catalogue.
#
# Inputs:
#   MODULES         space-separated list of {Vendor}_{Module} (required)
#   ENV             local | staging | production (default: local)
#   STRICT          1 to require PHPCS + PHPStan (default: 0)
#   RUNNER          PHP runner prefix (default: from .claude/.cache/magento2-context.json)
#   MAGENTO_CLI     Magento CLI invocation (default: from context)
#   MODULE_DIR      module root (default: src/app/code)
#   OUTPUT_FILE     where to write JSON summary (default: stdout only)
#
# Output:
#   JSON summary of per-check results to stdout (also to OUTPUT_FILE when set).
#
# Exit code:
#   0 if all required checks passed.
#   1 if any required check failed.
#   2 on missing tools / bad input.

set -uo pipefail

MODULES="${MODULES:?MODULES is required, e.g. 'Acme_OrderS3Export Acme_Catalog'}"
ENV="${ENV:-local}"
STRICT="${STRICT:-0}"
MODULE_DIR="${MODULE_DIR:-$([[ -d app/code ]] && echo app/code || echo src/app/code)}"
CONTEXT_FILE=".claude/.cache/magento2-context.json"

if [ -z "${RUNNER:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    RUNNER="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('runner') or '')")"
fi
RUNNER="${RUNNER:-}"

# runner_kind tells us whether the empty RUNNER means "bare PHP on PATH" (valid) or
# "no PHP available" (invalid). Without this, an empty RUNNER is ambiguous.
if [ -z "${RUNNER_KIND:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    RUNNER_KIND="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('runner_kind') or 'null')")"
fi
RUNNER_KIND="${RUNNER_KIND:-null}"

# runner_available is true iff the context detected a usable PHP environment, whether
# that environment is a docker prefix or bare host PHP.
runner_available() {
    case "$RUNNER_KIND" in
        bare|docker-compose|docker-exec|custom) return 0 ;;
        *) return 1 ;;
    esac
}

# run_in_runner <argv...> — execute argv inside the runner environment.
# For bare mode, RUNNER is empty so the argv runs directly.
# For docker modes, RUNNER carries the wrapper command (e.g. "docker compose exec ... php").
# When the wrapper already ends in `php`, the argv is the PHP script/args to run.
# To probe file existence inside the env, callers use `runner_test_file <path>`.
runner_test_file() {
    local path="$1"
    if [ "$RUNNER_KIND" = "bare" ] || [ -z "$RUNNER" ]; then
        [ -f "$path" ]
    else
        $RUNNER test -f "$path" 2>/dev/null
    fi
}

if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('magento_cli') or '')")"
fi
MAGENTO_CLI="${MAGENTO_CLI:-}"

declare -a RESULTS

# record <name> <required:true|false> <result:pass|fail|skipped> <note>
#
# A required check (required=true) marked "skipped" is treated as a failure: the deploy
# docs say PHPUnit and setup:db:status are required for all deploys, so a missing tool
# must NOT silently green-light --validate-only. To intentionally allow skipping, the
# caller must pass required=false (i.e. the check is downgraded to optional).
record() {
    local name="$1" required="$2" result="$3" note="$4"
    # Sanitize note for safe JSON: escape quotes, collapse newlines and tabs to spaces.
    note="${note//\"/\\\"}"
    note="${note//$'\n'/ }"
    note="${note//$'\r'/ }"
    note="${note//$'\t'/ }"
    RESULTS+=("$(printf '{"name":"%s","required":%s,"result":"%s","note":"%s"}' \
        "$name" "$required" "$result" "$note")")
    if [ "$required" = "true" ] && { [ "$result" = "skipped" ] || [ "$result" = "fail" ]; }; then
        FAILED=1
    fi
}

# run_check <name> <required:true|false> <cmd...>
#
# argv-safe replacement for the old eval-based wrapper. Pass each command argument as a
# separate positional argument so quoting is preserved and no shell interpolation runs.
# Example: run_check "phpcs" "true" vendor/bin/phpcs --standard=Magento2 src/app/code/Acme/Foo
run_check() {
    local name="$1" required="$2"
    shift 2
    if "$@" >/tmp/preflight.out 2>&1; then
        record "$name" "$required" "pass" "exit 0"
        return 0
    else
        local exit_code=$?
        local note
        note="$(head -c 500 /tmp/preflight.out | tr -d '\n')"
        record "$name" "$required" "fail" "exit ${exit_code}: ${note}"
        if [ "$required" = "true" ]; then
            FAILED=1
        fi
        return $exit_code
    fi
}

FAILED=0

# Required: module registration files exist
for mod in $MODULES; do
    path="${MODULE_DIR}/${mod//_/\/}"
    if [ -f "${path}/registration.php" ]; then
        record "module-registration:${mod}" "true" "pass" "${path}/registration.php exists"
    else
        record "module-registration:${mod}" "true" "fail" "missing ${path}/registration.php"
        FAILED=1
    fi
done

# Optional but valuable: composer validate per module
if command -v composer >/dev/null 2>&1; then
    for mod in $MODULES; do
        path="${MODULE_DIR}/${mod//_/\/}"
        if [ -f "${path}/composer.json" ]; then
            run_check "composer-validate:${mod}" "true" composer validate --no-check-publish "${path}/composer.json"
        else
            record "composer-validate:${mod}" "false" "skipped" "no composer.json in ${path}"
        fi
    done
else
    record "composer-validate" "false" "skipped" "composer not available"
fi

# Required: dependency graph (cycles, missing sequence targets)
if command -v python3 >/dev/null 2>&1; then
    # Resolve the Magento root so we can find app/etc/config.php for enabled-state checks.
    # MODULE_DIR is e.g. src/app/code or app/code; the Magento root sits one level above
    # app/code. Pass it explicitly so the python block doesn't have to re-derive it.
    case "$MODULE_DIR" in
        */app/code) MAGENTO_ROOT_FOR_DEPS="${MODULE_DIR%/app/code}" ;;
        app/code)   MAGENTO_ROOT_FOR_DEPS="." ;;
        *)          MAGENTO_ROOT_FOR_DEPS="" ;;
    esac
    dep_out="$(MODULES="$MODULES" MODULE_DIR="$MODULE_DIR" \
        COMPOSER_LOCK="${COMPOSER_LOCK:-$([[ -f composer.lock ]] && echo composer.lock || echo src/composer.lock)}" \
        MAGENTO_ROOT_FOR_DEPS="${MAGENTO_ROOT_FOR_DEPS:-.}" \
        MAGENTO_CLI="$MAGENTO_CLI" \
        python3 - <<'PY' 2>&1
"""Validate the dependency graph implied by the supplied modules.

Requirements (from pre-flight-checks.md and deploy-plan-templates.md):
  - No cycles among supplied modules.
  - Every <sequence>/<module name="..."> target must exist either:
      a) on disk under MODULE_DIR, or
      b) in composer.lock as an installed package (covers vendor modules).
  - Missing targets fail preflight before deploy is attempted.

Best-effort design: when COMPOSER_LOCK is absent we skip the vendor existence check and
flag missing on-disk modules as warnings instead of failures, so preflight still works
for repos without a lockfile.
"""
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

mods = os.environ['MODULES'].split()
mdir = os.environ['MODULE_DIR']
lock_path = os.environ.get('COMPOSER_LOCK', '')

def load_module_xml(module_name):
    """Parse one module's etc/module.xml and return the list of <sequence> dependencies.

    Returns None when the module's module.xml is not on disk (the caller decides if that
    is a hard failure for supplied modules or a leaf for transitive deps).
    """
    p = os.path.join(mdir, module_name.replace('_', '/'), 'etc', 'module.xml')
    if not os.path.exists(p):
        return None
    try:
        text = open(p).read()
        # Strip xmlns and xsi:* attributes so ET doesn't choke on namespace prefixes.
        text = re.sub(r'\sxmlns(:\w+)?="[^"]+"', '', text)
        text = re.sub(r'\sxsi:\w+="[^"]+"', '', text)
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        print(f"FAIL: cannot parse {p}: {exc}")
        sys.exit(1)
    declared = []
    for seq in root.iter('sequence'):
        for child in seq.findall('module'):
            name = child.get('name')
            if name:
                declared.append(name)
    return declared


# 1. Load module.xml for every supplied module (hard failure if missing) AND for any
#    transitive local dependency reachable from those modules. This lets cycle detection
#    catch loops that include local modules outside the supplied list.
deps = {}   # module_name -> list of dependency module_names (loaded from disk)
worklist = list(mods)
visited = set()
for m in mods:
    declared = load_module_xml(m)
    if declared is None:
        print(f"FAIL: missing {os.path.join(mdir, m.replace('_', '/'), 'etc', 'module.xml')}")
        sys.exit(1)
    deps[m] = declared
    visited.add(m)

# Walk transitively. Local modules contribute their edges; vendor modules (no on-disk
# module.xml under MODULE_DIR) are leaves and stay out of `deps`.
pending = []
for m in mods:
    pending.extend(deps[m])
while pending:
    d = pending.pop()
    if d in visited:
        continue
    visited.add(d)
    sub = load_module_xml(d)
    if sub is None:
        # Not a local module — leaf for cycle purposes. Existence is still verified later.
        continue
    deps[d] = sub
    pending.extend(sub)

# 2. Build the set of "known" module names: anything supplied, anything resolvable from
#    on-disk module.xml under MODULE_DIR, anything listed in composer.lock as a
#    magento2-module package.
known = set(mods)

# Discover on-disk modules (scan MODULE_DIR for */*/etc/module.xml).
if os.path.isdir(mdir):
    for vendor_dir in os.listdir(mdir):
        vendor_path = os.path.join(mdir, vendor_dir)
        if not os.path.isdir(vendor_path):
            continue
        for module_dir in os.listdir(vendor_path):
            mxml = os.path.join(vendor_path, module_dir, 'etc', 'module.xml')
            if os.path.exists(mxml):
                known.add(f"{vendor_dir}_{module_dir}")

# Discover vendor modules from composer.lock.
if lock_path and os.path.exists(lock_path):
    try:
        lock = json.load(open(lock_path))
        for pkg in lock.get('packages', []) + lock.get('packages-dev', []):
            extra = pkg.get('extra', {})
            for mod_id in (extra.get('magento', {}).get('module-name'), ):
                if mod_id:
                    known.add(mod_id)
            # Some packages declare module name via Magento\Framework registration; fall
            # back to package-name → Vendor_Module heuristic for `magento2-module` types.
            if pkg.get('type') == 'magento2-module':
                # composer name is e.g. "vendor/module-name"; module identifier is
                # typically Vendor_Module. We accept anything matching that shape that's
                # listed in <sequence> later.
                pass  # heuristic capture happens in the missing-target check below.
        # Also capture every package name string so a sequence referencing a vendor name
        # at least matches against composer presence.
        composer_names = {
            pkg.get('name') for pkg in lock.get('packages', []) + lock.get('packages-dev', [])
        }
    except (json.JSONDecodeError, OSError) as exc:
        composer_names = set()
        print(f"WARN: composer.lock unreadable: {exc}", file=sys.stderr)
else:
    composer_names = set()

# 3. Verify every <sequence> dependency exists somewhere.
missing_targets = []
for m, lst in deps.items():
    for d in lst:
        if d in known:
            continue
        # As a last resort, accept the dependency if any composer.lock package's name
        # matches lowercased "vendor/module" form.
        guess = d.lower().replace('_', '/')
        if guess in composer_names:
            continue
        # Magento core modules (Magento_*) are present via magento/magento2-base. We
        # always consider Magento_* known to avoid flagging legitimate core deps.
        if d.startswith('Magento_'):
            continue
        missing_targets.append((m, d))

if missing_targets:
    print("FAIL: missing <sequence> targets:")
    for parent, dep in missing_targets:
        print(f"  {parent} declares dependency on {dep}, which is not on disk or in composer.lock")
    sys.exit(1)

# 3b. Enabled-state verification for external sequence targets.
#
# A module can depend (via <sequence>) on another module that exists on disk or in
# composer.lock but is currently disabled. Magento's `setup:upgrade` then fails at
# enable time. Preflight must catch this before any state change.
#
# Strategy:
#   - Build the set of "external sequence targets": deps[supplied_module] entries that
#     are NOT themselves being supplied to this deploy (i.e. the user is not enabling
#     them in this run) and that ARE local (have on-disk module.xml).
#   - Read enabled state from app/etc/config.php's `modules` array.
#   - When the Magento CLI is also available, the caller's outer shell layer can run
#     `module:status --enabled` as a richer source; we use config.php here because the
#     python block runs without shell access.
#   - Fail when any external sequence target is present but disabled (=0).
#   - When config.php is absent (fresh project), record uncertainty as a non-fatal note
#     so the rest of the graph check still runs.

supplied = set(mods)
# All external sequence targets — local custom modules, vendor modules from composer.lock,
# Magento core modules — except those already in the deploy list. Each is a candidate for
# the enabled-state check.
external_all_deps = set()
for m in mods:
    for d in deps.get(m, []):
        if d in supplied:
            continue
        external_all_deps.add(d)

magento_root = os.environ.get('MAGENTO_ROOT_FOR_DEPS', '.')
config_php_candidates = [
    os.path.join(magento_root, 'app', 'etc', 'config.php'),
    'app/etc/config.php',
]
config_php = next((p for p in config_php_candidates if os.path.isfile(p)), '')

disabled_deps = []
enabled_check_status = 'skipped'
enabled_check_reason = ''
enabled_check_targets = 0
if external_all_deps:
    if not config_php:
        enabled_check_reason = (
            "external sequence targets exist but app/etc/config.php is missing; "
            "cannot verify enabled state"
        )
    else:
        # Parse the modules array from config.php. Format:
        #   'modules' => [ 'Vendor_Module' => 1, ... ]
        text = open(config_php).read()
        modules_match = re.search(
            r"'modules'\s*=>\s*\[(?P<body>.*?)\]\s*,?\s*\]?",
            text,
            re.DOTALL,
        )
        module_states = {}
        if modules_match:
            body = modules_match.group('body')
            for m_kv in re.finditer(r"'([A-Za-z0-9_]+)'\s*=>\s*(\d)", body):
                module_states[m_kv.group(1)] = int(m_kv.group(2))
        if not module_states:
            enabled_check_reason = "app/etc/config.php has no parseable modules array"
        else:
            enabled_check_status = 'ran'
            for d in sorted(external_all_deps):
                state = module_states.get(d)
                if state is None:
                    # Module not yet registered in config.php (e.g. brand-new local module
                    # whose enable will happen during this deploy). After `setup:upgrade`
                    # it would be auto-added enabled, so treat as enabled.
                    continue
                enabled_check_targets += 1
                if state == 0:
                    disabled_deps.append(d)

if disabled_deps:
    print("FAIL: external <sequence> targets are disabled in app/etc/config.php:")
    for d in disabled_deps:
        print(f"  {d} is present but disabled — include it in this deploy or "
              f"enable it first")
    sys.exit(1)

# 4. Cycle detection across the *transitive* graph rooted at supplied modules and any
#    local dependencies loaded above. Vendor modules without on-disk module.xml are not
#    in `deps` and act as leaves.
WHITE, GRAY, BLACK = 0, 1, 2
color = {m: WHITE for m in deps}

def visit(n, stack):
    if n not in deps:
        return None
    color[n] = GRAY
    for d in deps[n]:
        if d in color and color[d] == GRAY:
            return stack + [n, d]
        if d in color and color[d] == WHITE:
            r = visit(d, stack + [n])
            if r:
                return r
    color[n] = BLACK
    return None

for m in deps:
    if color[m] == WHITE:
        cyc = visit(m, [])
        if cyc:
            print(f"FAIL: dependency cycle: {' -> '.join(cyc)}")
            sys.exit(1)

# Emit a machine-readable status line that the outer shell parses into the
# dependency-graph check note. This preserves enabled-state uncertainty in saved
# preflight JSON instead of silently passing.
if enabled_check_status == 'ran':
    print(f"ENABLED-STATE: ran ({enabled_check_targets} target(s) verified)")
elif external_all_deps:
    print(f"ENABLED-STATE: skipped ({enabled_check_reason})")
else:
    print("ENABLED-STATE: not-applicable (no external sequence targets)")

print("OK")
PY
)"
    if echo "$dep_out" | grep -q '^OK'; then
        enabled_state_line="$(echo "$dep_out" | grep '^ENABLED-STATE:' | head -1)"
        enabled_state_note="${enabled_state_line#ENABLED-STATE: }"
        record "dependency-graph" "true" "pass" "all sequence targets resolved; no cycles"
        # Surface enabled-state outcome as its own check so saved JSON preserves it.
        case "$enabled_state_note" in
            ran*)
                record "dependency-enabled-state" "true" "pass" "$enabled_state_note"
                ;;
            skipped*)
                # Skipped without app/etc/config.php (e.g. fresh project). Not a hard
                # failure — the graph itself is sound — but flag so consumers know the
                # enabled-state gate did NOT run.
                record "dependency-enabled-state" "false" "skipped" "$enabled_state_note"
                ;;
            *)
                record "dependency-enabled-state" "false" "pass" "$enabled_state_note"
                ;;
        esac
    else
        record "dependency-graph" "true" "fail" "$dep_out"
        FAILED=1
    fi
else
    record "dependency-graph" "true" "skipped" "python3 not available"
fi

# Required: unit tests (PHPUnit) for the supplied modules
PHPUNIT_BIN="vendor/bin/phpunit"
if runner_available && runner_test_file "$PHPUNIT_BIN"; then
    unit_paths=()
    for mod in $MODULES; do unit_paths+=("${MODULE_DIR}/${mod//_/\/}/Test/Unit"); done
    # $RUNNER may be empty (bare PHP) or a multi-word docker prefix; build argv accordingly.
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206  # intentional word-splitting of the runner prefix
        runner_argv=($RUNNER)
        run_check "phpunit-unit" "true" "${runner_argv[@]}" "$PHPUNIT_BIN" --no-coverage "${unit_paths[@]}"
    else
        run_check "phpunit-unit" "true" "$PHPUNIT_BIN" --no-coverage "${unit_paths[@]}"
    fi
else
    record "phpunit-unit" "true" "fail" "phpunit not available (runner_kind='${RUNNER_KIND}', RUNNER='${RUNNER}')"
fi

# Required: setup:db:status reports no pending schema/data changes
if [ -n "$MAGENTO_CLI" ]; then
    if $MAGENTO_CLI setup:db:status >/tmp/db-status.out 2>&1; then
        record "db-status" "true" "pass" "no pending schema/data changes"
    else
        note="$(head -c 500 /tmp/db-status.out | tr -d '\n')"
        record "db-status" "true" "fail" "pending changes: ${note}"
        FAILED=1
    fi
else
    # Required check: no Magento CLI means we cannot verify DB state. Fail rather than skip
    # so --validate-only cannot green-light a release without a runnable Magento install.
    record "db-status" "true" "fail" "magento CLI not available"
fi

# Required (production): composer install --dry-run
if [ "$ENV" = "production" ]; then
    if ! command -v composer >/dev/null 2>&1; then
        record "composer-install-dryrun" "true" "fail" "composer not available on PATH"
    else
        # Pick whichever composer.json exists. Prefer the project root, fall back to src/.
        composer_dir=""
        if [ -f "composer.json" ]; then
            composer_dir="."
        elif [ -f "src/composer.json" ]; then
            composer_dir="src"
        fi
        if [ -n "$composer_dir" ]; then
            run_check "composer-install-dryrun" "true" composer install --no-dev --optimize-autoloader --dry-run --working-dir="${composer_dir}"
        else
            record "composer-install-dryrun" "true" "fail" "no composer.json found in project root or src/"
        fi
    fi
fi

# Required (production): maintenance-mode flag writeable
if [ "$ENV" = "production" ]; then
    flag_dir="var"
    [ -d "src/var" ] && flag_dir="src/var"
    if [ -d "$flag_dir" ] && [ -w "$flag_dir" ]; then
        record "maintenance-writeable" "true" "pass" "$flag_dir is writeable"
    else
        record "maintenance-writeable" "true" "fail" "${flag_dir} not writeable; maintenance:enable would fail"
        FAILED=1
    fi
fi

build_runner_argv() {
    # Word-split $RUNNER into runner_argv if non-empty; leave runner_argv as () for bare.
    runner_argv=()
    if [ -n "$RUNNER" ]; then
        # shellcheck disable=SC2206
        runner_argv=($RUNNER)
    fi
}

# Optional strict: PHPCS
if [ "$STRICT" = "1" ]; then
    if runner_available && runner_test_file vendor/bin/phpcs; then
        paths=()
        for mod in $MODULES; do paths+=("${MODULE_DIR}/${mod//_/\/}"); done
        build_runner_argv
        run_check "phpcs" "true" "${runner_argv[@]}" vendor/bin/phpcs --standard=Magento2 "${paths[@]}"
    else
        record "phpcs" "true" "fail" "--strict set but phpcs not available"
        FAILED=1
    fi
fi

# Optional strict: PHPStan
if [ "$STRICT" = "1" ]; then
    if runner_available && runner_test_file vendor/bin/phpstan; then
        paths=()
        for mod in $MODULES; do paths+=("${MODULE_DIR}/${mod//_/\/}"); done
        build_runner_argv
        run_check "phpstan" "true" "${runner_argv[@]}" vendor/bin/phpstan analyse --level=8 "${paths[@]}"
    else
        record "phpstan" "true" "fail" "--strict set but phpstan not available"
        FAILED=1
    fi
fi

# Required: disk space
free_kb="$(df -Pk . 2>/dev/null | awk 'NR==2 {print $4}')"
free_kb="${free_kb:-0}"
threshold_kb=1048576
if [ "$ENV" = "production" ]; then
    threshold_kb=5242880
fi
if [ "$free_kb" -ge "$threshold_kb" ]; then
    record "disk-space" "true" "pass" "${free_kb} KB free (threshold ${threshold_kb})"
else
    record "disk-space" "true" "fail" "${free_kb} KB free, need ${threshold_kb}"
    FAILED=1
fi

# Required (production): git tree clean
if [ "$ENV" = "production" ]; then
    if command -v git >/dev/null 2>&1; then
        if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
            record "git-clean" "true" "pass" "working tree clean"
        else
            record "git-clean" "true" "fail" "uncommitted changes present"
            FAILED=1
        fi
    else
        record "git-clean" "true" "fail" "git not available"
        FAILED=1
    fi
fi

# Compose JSON
joined="$(IFS=','; echo "${RESULTS[*]}")"
passed_flag="true"
[ "$FAILED" = "1" ] && passed_flag="false"
json=$(printf '{"preflight":{"env":"%s","passed":%s,"checks":[%s]}}' "$ENV" "$passed_flag" "$joined")

echo "$json"
if [ -n "${OUTPUT_FILE:-}" ]; then
    echo "$json" > "$OUTPUT_FILE"
fi

if [ "$FAILED" = "1" ]; then
    exit 1
fi
exit 0
