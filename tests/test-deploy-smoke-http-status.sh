#!/usr/bin/env bash
# smoke.sh's HTTP checks must report what the endpoint actually did.
#
# Regression test for three defects that made a healthy local stack read as broken:
#   1. `curl -w '%{http_code}' … || echo 000` — on a connection failure curl has ALREADY printed
#      000, so the fallback appended a second one. The status became "000000", the GraphQL
#      `000) … skipped` branch never matched, and an unreachable endpoint was recorded as `fail`.
#   2. No `-k`: on the self-signed HTTPS every local Docker Magento uses, every check failed the TLS
#      handshake (and, with 1, read "HTTP 000000").
#   3. The admin path was hard-coded to /admin/, so an install with a custom backend frontName
#      returned 404 there and was recorded as `fail` although its admin was healthy.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

command -v python3 >/dev/null 2>&1 || { echo "skip: python3 not on PATH"; exit 77; }
command -v curl >/dev/null 2>&1 || { echo "skip: curl not on PATH"; exit 77; }

SCRIPT="$PWD/skills/deploy/scripts/smoke.sh"
[ -f "$SCRIPT" ] || { echo "FAIL: $SCRIPT not found"; exit 1; }

WORK="$(mktemp -d)"
SRV_PID=""
trap '[ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; rm -rf "$WORK"' EXIT

FAIL=0
fail() { echo "FAIL: $*"; FAIL=1; }

# result <json-file> <check-name> → "<result>\t<detail>"
result() {
    python3 - "$1" "$2" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
for r in doc['smoke']['results']:
    if r['name'] == sys.argv[2]:
        print('%s\t%s' % (r['result'], r['detail']))
        break
else:
    print('missing\t')
PY
}

# Every run happens from an empty cwd so no project's .claude/.cache/context.json or app/etc/env.php
# leaks in, and with MAGENTO_CLI set-but-empty so no CLI check runs.
run_smoke() {
    local out="$1"; shift
    (cd "$WORK/cwd" && env "$@" MODULES=Acme_Probe MAGENTO_CLI= bash "$SCRIPT") > "$out" 2>/dev/null
}
mkdir -p "$WORK/cwd"

# --- 1. unreachable endpoint (real curl): no doubled status, GraphQL is skipped ----------------
run_smoke "$WORK/unreachable.json" BASE_URL=https://127.0.0.1:9
grep -q '000000' "$WORK/unreachable.json" && fail "a detail still carries the doubled status 000000"
IFS=$'\t' read -r res detail < <(result "$WORK/unreachable.json" graphql)
[ "$res" = "skipped" ] || fail "unreachable GraphQL recorded as '$res' ($detail), expected skipped"

# --- 2. admin path (real curl against a local HTTP server) --------------------------------------
SITE="$WORK/site"; mkdir -p "$SITE/admin_xs1"
echo ok > "$SITE/admin_xs1/index.html"
python3 - "$SITE" "$WORK/port" <<'PY' &
import http.server, os, sys
root, port_file = sys.argv[1], sys.argv[2]
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=root, **kw)
    def log_message(self, *a):
        pass
srv = http.server.HTTPServer(('127.0.0.1', 0), Handler)
with open(port_file + '.tmp', 'w') as fh:
    fh.write(str(srv.server_address[1]))
os.rename(port_file + '.tmp', port_file)
srv.serve_forever()
PY
SRV_PID=$!
for _ in $(seq 1 50); do [ -s "$WORK/port" ] && break; sleep 0.1; done
[ -s "$WORK/port" ] || { echo "FAIL: local HTTP server did not start"; exit 1; }
BASE="http://127.0.0.1:$(cat "$WORK/port")"

# 2a. Nothing says where the admin is, and the guessed /admin/ is a 404: that is "unknown", not a
#     failed admin.
run_smoke "$WORK/guess.json" BASE_URL="$BASE"
IFS=$'\t' read -r res detail < <(result "$WORK/guess.json" admin-ui)
[ "$res" = "skipped" ] || fail "404 on the guessed /admin/ recorded as '$res' ($detail), expected skipped"

# 2b. The install's own app/etc/env.php names the frontName: probe that path, and it passes.
mkdir -p "$WORK/cwd/src/app/etc"
cat > "$WORK/cwd/src/app/etc/env.php" <<'PHP'
<?php
return [
    'backend' => [
        'frontName' => 'admin_xs1'
    ],
    'install' => [
        'date' => 'Mon, 01 Jan 2026 00:00:00 +0000'
    ]
];
PHP
run_smoke "$WORK/envphp.json" BASE_URL="$BASE"
IFS=$'\t' read -r res detail < <(result "$WORK/envphp.json" admin-ui)
[ "$res" = "pass" ] || fail "admin at env.php frontName recorded as '$res' ($detail), expected pass"
case "$detail" in *admin_xs1*) ;; *) fail "admin detail does not name the probed path: $detail" ;; esac
rm -rf "$WORK/cwd/src"

# 2c. An EXPLICIT ADMIN_PATH that 404s is a real failure — the caller said the admin lives there.
run_smoke "$WORK/explicit.json" BASE_URL="$BASE" ADMIN_PATH=nope
IFS=$'\t' read -r res detail < <(result "$WORK/explicit.json" admin-ui)
[ "$res" = "fail" ] || fail "404 on an explicit ADMIN_PATH recorded as '$res' ($detail), expected fail"

# --- 3. -k for local HTTPS only (curl stub records its argv) ------------------------------------
STUB="$WORK/stub"; mkdir -p "$STUB"
cat > "$STUB/curl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CURL_LOG"
printf '200'
SH
chmod +x "$STUB/curl"

insecure_flag_used() {
    # $1 = log; true when any logged curl invocation carried -k / --insecure.
    grep -qE '(^| )(-k|--insecure)( |$)' "$1"
}

: > "$WORK/local.log"
run_smoke "$WORK/k-local.json" PATH="$STUB:$PATH" CURL_LOG="$WORK/local.log" BASE_URL=https://shop.localhost
insecure_flag_used "$WORK/local.log" || fail "no -k for a *.localhost HTTPS base URL"

: > "$WORK/public.log"
run_smoke "$WORK/k-public.json" PATH="$STUB:$PATH" CURL_LOG="$WORK/public.log" BASE_URL=https://shop.example.com
insecure_flag_used "$WORK/public.log" && fail "-k used for a public HTTPS base URL"

: > "$WORK/forced.log"
run_smoke "$WORK/k-forced.json" PATH="$STUB:$PATH" CURL_LOG="$WORK/forced.log" \
    BASE_URL=https://shop.example.com SMOKE_CURL_INSECURE=1
insecure_flag_used "$WORK/forced.log" || fail "SMOKE_CURL_INSECURE=1 did not add -k"

if [ "$FAIL" = "0" ]; then
    echo "PASS: smoke HTTP checks report single statuses, skip unknown/unreachable, find the admin"
    echo "      frontName, and relax TLS only for local hosts"
    exit 0
fi
for f in unreachable guess envphp explicit; do echo "--- $f.json ---"; cat "$WORK/$f.json" 2>/dev/null; echo; done
exit 1
