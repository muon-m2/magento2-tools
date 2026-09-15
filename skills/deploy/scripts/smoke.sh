#!/usr/bin/env bash
# smoke.sh — run smoke tests after a deploy.
#
# Inputs:
#   MODULES       space-separated module list
#   BASE_URL      http://... (default: from env or http://localhost)
#   MAGENTO_CLI   (default: from .claude/.cache/context.json)
#   MAGENTO_ROOT  install root holding app/etc/env.php and var/ (default: src/, then ./)
#   ADMIN_PATH    admin frontName to probe (default: app/etc/env.php backend.frontName, else a
#                 guessed "admin" — a 404 on the guess is recorded as skipped, not fail)
#   SMOKE_CURL_INSECURE
#                 1 to skip TLS certificate verification for any host (default: skipped only
#                 for https on localhost, *.localhost, *.test and loopback addresses)
#   SINCE_TS      deploy start, ISO 8601 or epoch seconds (default: a 15-minute window)
#   OUTPUT_FILE   where to write JSON summary
#
# Output:
#   JSON summary of smoke results (also to OUTPUT_FILE when set).

set -uo pipefail

MODULES="${MODULES:?MODULES is required}"
BASE_URL="${BASE_URL:-http://localhost}"
CONTEXT_FILE=".claude/.cache/context.json"

if [ -z "${MAGENTO_CLI:-}" ] && [ -f "$CONTEXT_FILE" ] && command -v python3 >/dev/null 2>&1; then
    MAGENTO_CLI="$(python3 -c "import json; print(json.load(open('${CONTEXT_FILE}')).get('magento_cli') or '')")"
fi

declare -a RESULTS

record() {
    local name="$1" result="$2" detail="$3"
    # Escape backslash BEFORE quote, else the quote's own escape gets doubled. A detail can
    # legitimately contain both — Magento class names are backslash-separated.
    detail="${detail//\\/\\\\}"
    detail="${detail//\"/\\\"}"
    detail="$(printf '%s' "$detail" | tr '\n\r\t' '   ')"
    RESULTS+=("$(printf '{"name":"%s","result":"%s","detail":"%s"}' "$name" "$result" "$detail")")
}

# Module status — every deployed module must appear individually in the ENABLED list.
# `module:status` (no flag) prints BOTH the enabled and disabled sections, so a disabled
# module still matched the old alternation; and the alternation passed if ANY one module
# matched, not all. `--enabled` lists only enabled module names, one per line, so an exact
# whole-line match per module is both disabled-safe and all-modules-required.
if [ -n "${MAGENTO_CLI:-}" ]; then
    enabled_list="$(eval "$MAGENTO_CLI module:status --enabled" 2>&1)"
    missing=""
    for mod in $MODULES; do
        printf '%s\n' "$enabled_list" | grep -qx "$mod" || missing="${missing:+$missing }$mod"
    done
    if [ -z "$missing" ]; then
        record "module-status" "pass" "all deployed modules listed as enabled"
    else
        record "module-status" "fail" "not in enabled list: $missing"
    fi

    if eval "$MAGENTO_CLI setup:db:status" 2>&1 | grep -qi "up to date"; then
        record "db-status" "pass" "schema up to date"
    else
        record "db-status" "fail" "schema not up to date"
    fi
else
    record "module-status" "skipped" "magento_cli not available"
    record "db-status" "skipped" "magento_cli not available"
fi

# --- HTTP checks --------------------------------------------------------------------------------

# TLS verification. A local stack serves HTTPS with a self-signed certificate, so without -k every
# check failed the handshake and a healthy deploy read as broken. Verification is relaxed ONLY for
# hosts that cannot be a public site — localhost, the RFC 6761 reserved *.localhost and *.test names,
# loopback — or when the caller sets SMOKE_CURL_INSECURE=1.
url_host() {
    local host="${1#*://}"
    host="${host%%/*}"
    host="${host##*@}"
    case "$host" in
        \[*) host="${host%%]*}]" ;;
        *) host="${host%%:*}" ;;
    esac
    printf '%s' "$host" | tr '[:upper:]' '[:lower:]'
}
CURL_INSECURE=0
if [ "${SMOKE_CURL_INSECURE:-0}" = "1" ]; then
    CURL_INSECURE=1
else
    case "$BASE_URL" in
        [Hh][Tt][Tt][Pp][Ss]://*)
            case "$(url_host "$BASE_URL")" in
                localhost|*.localhost|*.test|127.*|\[::1\]) CURL_INSECURE=1 ;;
            esac
            ;;
    esac
fi
TLS_NOTE=""
[ "$CURL_INSECURE" = "1" ] && TLS_NOTE=" (TLS certificate not verified)"

# http_status <curl args…> — the response's status code, or 000 when there was no response.
# curl's -w '%{http_code}' ALREADY prints 000 on a connection or TLS failure; the old `|| echo 000`
# fallback appended a second 000, producing "000000" — which matched no case, so an unreachable
# GraphQL endpoint was recorded as `fail` instead of `skipped`.
http_status() {
    local code
    if [ "$CURL_INSECURE" = "1" ]; then
        code="$(curl -k -s -o /dev/null -w '%{http_code}' "$@" 2>/dev/null)"
    else
        code="$(curl -s -o /dev/null -w '%{http_code}' "$@" 2>/dev/null)"
    fi
    printf '%s' "${code:-000}"
}

# Admin path. The admin lives at the install's backend frontName, which is rarely `admin` on a real
# install — /admin/ was hard-coded, so a healthy admin at a custom frontName returned 404 and was
# recorded as `fail`. Resolved from ADMIN_PATH, then app/etc/env.php `backend.frontName` (same root
# lookup as the error-signal scan: MAGENTO_ROOT, then src/, then ./), then guessed as `admin`. A 404
# on the GUESS means the path is unknown, not that the admin is down.
ADMIN_PATH="${ADMIN_PATH:-}"
ADMIN_PATH_SOURCE="ADMIN_PATH"
if [ -z "$ADMIN_PATH" ]; then
    for root in "${MAGENTO_ROOT:-}" src .; do
        [ -n "$root" ] && [ -f "${root}/app/etc/env.php" ] || continue
        ADMIN_PATH="$(sed -n "s/.*['\"]frontName['\"][[:space:]]*=>[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" \
            "${root}/app/etc/env.php" | head -n 1)"
        ADMIN_PATH_SOURCE="${root}/app/etc/env.php backend.frontName"
        break
    done
fi
if [ -z "$ADMIN_PATH" ]; then
    ADMIN_PATH="admin"
    ADMIN_PATH_SOURCE="guessed"
fi
ADMIN_PATH="${ADMIN_PATH#/}"
ADMIN_PATH="${ADMIN_PATH%/}"

if command -v curl >/dev/null 2>&1; then
    admin_url="${BASE_URL%/}/${ADMIN_PATH}/"
    code="$(http_status "$admin_url")"
    case "$code" in
        200|302|301) record "admin-ui" "pass" "HTTP $code at /${ADMIN_PATH}/${TLS_NOTE}" ;;
        404)
            if [ "$ADMIN_PATH_SOURCE" = "guessed" ]; then
                record "admin-ui" "skipped" "HTTP 404 at the guessed /${ADMIN_PATH}/ — admin frontName unknown; pass ADMIN_PATH, or MAGENTO_ROOT so app/etc/env.php can be read"
            else
                record "admin-ui" "fail" "HTTP 404 at /${ADMIN_PATH}/ (from ${ADMIN_PATH_SOURCE})${TLS_NOTE}"
            fi
            ;;
        000) record "admin-ui" "fail" "no response from ${admin_url} (connection or TLS failure)${TLS_NOTE}" ;;
        *) record "admin-ui" "fail" "HTTP $code at /${ADMIN_PATH}/${TLS_NOTE}" ;;
    esac

    code="$(http_status -X POST "${BASE_URL%/}/graphql" \
        -H 'Content-Type: application/json' \
        -d '{"query":"query{__schema{queryType{name}}}"}')"
    case "$code" in
        200) record "graphql" "pass" "HTTP 200${TLS_NOTE}" ;;
        000) record "graphql" "skipped" "graphql endpoint unreachable (no response)${TLS_NOTE}" ;;
        *) record "graphql" "fail" "HTTP $code${TLS_NOTE}" ;;
    esac
else
    record "http-checks" "skipped" "curl not available"
fi

# --- Error signals written since the deploy started ---------------------------------------
# An HTTP 200 does not mean nothing broke. Magento records failures in three places and two of
# them never touch exception.log:
#   * var/report/api/{id}  — Webapi\ErrorProcessor::apiShutdownFunction() writes it on a PHP
#     fatal with NO logger call at all (framework/Webapi/ErrorProcessor.php:298-326).
#   * var/log/system.log and module channels — Logger\Handler\System::write() only routes a
#     record to exception.log when $record['context']['exception'] is set, so a string-level
#     critical (e.g. "Type Error occurred when creating object: …" from the ObjectManager)
#     lands in system.log alone.
# Window-based, not baseline-based: a deploy knows when it started. Set SINCE_TS to the deploy
# start (ISO 8601 or epoch seconds); the default 15-minute window is reported explicitly.
if command -v python3 >/dev/null 2>&1; then
    signal_json="$(MAGENTO_ROOT="${MAGENTO_ROOT:-}" MODULES="$MODULES" SINCE_TS="${SINCE_TS:-}" python3 - <<'PY'
import json
import os
import re
from datetime import datetime, timedelta, timezone

LEVELS = ('EMERGENCY', 'ALERT', 'CRITICAL', 'ERROR')
HEADER = re.compile(r'^\[([^\]]+)\]\s+[\w.\-]+\.(%s):\s?(.*)$' % '|'.join(LEVELS))


def resolve_root():
    explicit = os.environ.get('MAGENTO_ROOT') or ''
    if explicit and os.path.isdir(explicit):
        return explicit
    for cand in ('src', '.'):
        if os.path.isfile(os.path.join(cand, 'app/etc/env.php')):
            return cand
    return ''


def parse_ts(text):
    text = text.strip()
    try:
        return datetime.fromisoformat(text.replace('Z', '+00:00'))
    except ValueError:
        pass
    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S'):
        try:
            return datetime.strptime(text[:19], fmt).replace(tzinfo=timezone.utc)
        except ValueError:
            continue
    return None


since_raw = os.environ.get('SINCE_TS') or ''
defaulted = False
since = None
if since_raw:
    try:
        since = datetime.fromtimestamp(float(since_raw), tz=timezone.utc)
    except ValueError:
        since = parse_ts(since_raw)
if since is None:
    since = datetime.now(timezone.utc) - timedelta(minutes=15)
    defaulted = True

window = 'since %s%s' % (since.isoformat(), ' (default 15m window — pass SINCE_TS for the '
                                            'real deploy start)' if defaulted else '')

root = resolve_root()
out = []
if not root:
    out.append({'name': 'error-signals', 'result': 'skipped',
                'detail': 'no Magento root found (looked for app/etc/env.php in ./ and src/)'})
else:
    ns_tokens = []
    for mod in os.environ.get('MODULES', '').split():
        parts = mod.replace('\\', '_').replace('/', '_').split('_')
        ns_tokens += [mod, '_'.join(parts), '\\'.join(parts), '/'.join(parts)]
    ns_tokens = [t for t in dict.fromkeys(ns_tokens) if t]

    # var/report/** — any file touched inside the window
    report_root = os.path.join(root, 'var', 'report')
    hits = []
    if os.path.isdir(report_root):
        for dirpath, _dirs, files in os.walk(report_root):
            for name in files:
                path = os.path.join(dirpath, name)
                try:
                    if datetime.fromtimestamp(os.path.getmtime(path),
                                              tz=timezone.utc) >= since:
                        hits.append(os.path.relpath(path, root))
                except OSError:
                    continue
        if hits:
            out.append({'name': 'error-reports', 'result': 'fail',
                        'detail': '%d error report(s) written %s: %s' % (
                            len(hits), window, ', '.join(sorted(hits)[:5]))})
        else:
            out.append({'name': 'error-reports', 'result': 'pass',
                        'detail': 'no new var/report files %s' % window})
    else:
        out.append({'name': 'error-reports', 'result': 'pass',
                    'detail': 'var/report does not exist (no report ever written)'})

    # var/log/*.log — ERROR+ entries inside the window, attributed to the deployed modules
    log_root = os.path.join(root, 'var', 'log')
    attributed, other = {}, {}
    scanned = 0
    if os.path.isdir(log_root):
        for name in sorted(os.listdir(log_root)):
            if not name.endswith('.log') or name == 'debug.log':
                continue
            path = os.path.join(log_root, name)
            if not os.path.isfile(path):
                continue
            scanned += 1
            try:
                # Tail the last 2 MiB — a deploy window cannot be further back than that in
                # any realistic log, and it keeps a multi-GB cron.log cheap to check.
                size = os.path.getsize(path)
                with open(path, 'rb') as fh:
                    if size > 2 * 1024 * 1024:
                        fh.seek(size - 2 * 1024 * 1024)
                        fh.readline()
                    text = fh.read().decode('utf-8', 'replace')
            except OSError:
                continue
            for line in text.splitlines():
                m = HEADER.match(line)
                if not m:
                    continue
                ts = parse_ts(m.group(1))
                if ts is None or ts < since:
                    continue
                bucket = attributed if any(t in line for t in ns_tokens) else other
                key = '%s: %s' % (name, m.group(3)[:120])
                bucket[key] = bucket.get(key, 0) + 1
    if not scanned:
        out.append({'name': 'error-logs', 'result': 'skipped',
                    'detail': 'no readable var/log/*.log files'})
    elif attributed:
        top = sorted(attributed.items(), key=lambda kv: -kv[1])[:3]
        out.append({'name': 'error-logs', 'result': 'fail',
                    'detail': '%d ERROR+ entr(ies) naming a deployed module %s: %s' % (
                        sum(attributed.values()), window,
                        ' | '.join('%s (x%d)' % (k, v) for k, v in top))})
    elif other:
        top = sorted(other.items(), key=lambda kv: -kv[1])[:3]
        out.append({'name': 'error-logs', 'result': 'warn',
                    'detail': '%d ERROR+ entr(ies) not naming a deployed module %s: %s' % (
                        sum(other.values()), window,
                        ' | '.join('%s (x%d)' % (k, v) for k, v in top))})
    else:
        out.append({'name': 'error-logs', 'result': 'pass',
                    'detail': 'no ERROR+ entries in %d log file(s) %s' % (scanned, window)})

print(json.dumps(out))
PY
)"
    if [ -n "$signal_json" ]; then
        while IFS=$'\t' read -r name result detail; do
            [ -n "$name" ] && record "$name" "$result" "$detail"
        done <<EOF
$(printf '%s' "$signal_json" | python3 -c "
import json,sys
for r in json.load(sys.stdin):
    print('%s\t%s\t%s' % (r['name'], r['result'], r['detail'].replace(chr(9), ' ')))
")
EOF
    else
        record "error-signals" "skipped" "signal scan produced no output"
    fi
else
    record "error-signals" "skipped" "python3 not available — var/report and var/log NOT checked"
fi

joined="$(IFS=','; echo "${RESULTS[*]}")"
json=$(printf '{"smoke":{"base_url":"%s","results":[%s]}}' "$BASE_URL" "$joined")
echo "$json"
if [ -n "${OUTPUT_FILE:-}" ]; then
    echo "$json" > "$OUTPUT_FILE"
fi
