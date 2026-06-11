#!/usr/bin/env bash
# snapshot.sh — one-shot, read-only system snapshot for the debug skill's `snapshot` mode.
#
# Emits a single Markdown document (to stdout) suitable for pasting into a ticket. Every probe
# is best-effort: a missing tool/command is reported in-line rather than aborting the run.
#
# Resolution (no args needed): MAGENTO_CLI / RUNNER come from the env, else from the
# magento2-context cache at .claude/.cache/magento2-context.json.
set -uo pipefail

CONTEXT_FILE=".claude/.cache/magento2-context.json"

if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json;print(json.load(open('$CONTEXT_FILE')).get('magento_cli') or '')" 2>/dev/null || echo "")"
fi
if [ -z "${RUNNER:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    RUNNER="$(python3 -c "import json;print(json.load(open('$CONTEXT_FILE')).get('runner') or '')" 2>/dev/null || echo "")"
fi
MAGENTO_CLI="${MAGENTO_CLI:-}"
RUNNER="${RUNNER:-}"

# Run a Magento CLI sub-command best-effort; print its output or a "not available" note.
mg() {
    if [ -z "$MAGENTO_CLI" ]; then
        echo "_(Magento CLI not available — run \`bin/magento $*\` manually.)_"
        return
    fi
    # shellcheck disable=SC2086  # MAGENTO_CLI may be a multi-word runner+cli prefix
    if ! $MAGENTO_CLI "$@" 2>&1; then
        echo "_(\`$* \` failed or is unavailable in this environment.)_"
    fi
}

section() { printf '\n## %s\n\n```\n' "$1"; }
endsec() { printf '```\n'; }

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "# Magento debug snapshot"
echo
echo "- Captured: ${TS}"
echo "- Magento CLI: \`${MAGENTO_CLI:-<none>}\`"

section "Magento mode";            mg deploy:mode:show; endsec
section "Maintenance status";      mg maintenance:status; endsec
section "Indexer status";          mg indexer:status; endsec
section "Cache status";            mg cache:status; endsec
section "Queue consumers";         mg queue:consumers:list; endsec

section "PHP version"
if [ -n "$RUNNER" ]; then
    # shellcheck disable=SC2086
    $RUNNER php -v 2>&1 || echo "_(php not reachable via runner)_"
elif command -v php >/dev/null 2>&1; then
    php -v 2>&1
else
    echo "_(php not available)_"
fi
endsec

section "PHP extensions"
if [ -n "$RUNNER" ]; then
    # shellcheck disable=SC2086
    $RUNNER php -m 2>&1 | tr '\n' ' ' || echo "_(php -m not reachable)_"
elif command -v php >/dev/null 2>&1; then
    php -m 2>&1 | tr '\n' ' '
else
    echo "_(php not available)_"
fi
echo
endsec

section "Pending cron jobs"
echo "There is no bin/magento command that lists pending cron jobs. Query the DB instead:"
echo "  SELECT job_code, status, COUNT(*) FROM cron_schedule"
echo "  WHERE status IN ('pending','running') GROUP BY job_code, status;"
endsec

section "Composer outdated (direct deps)"
if command -v composer >/dev/null 2>&1; then
    composer outdated --direct 2>&1 | head -50 || echo "_(composer outdated failed)_"
else
    echo "_(composer not on PATH — run \`composer outdated --direct\` in the project)_"
fi
endsec

echo
echo "_Read-only snapshot — no state was modified._"
