# Smoke Tests

Surface-driven smoke tests run after Phase 3 (Execute). A smoke failure does NOT trigger
rollback (the deploy completed) but it surfaces a "needs investigation" finding in the
report.

> **Tooling.** These smokes are `curl` and `bin/magento` only, by policy — see
> `context/references/runtime-test-tooling.md`. Deploy smoke never drives a browser:
> it verifies reachability and error signals, not rendering, so a browser would add a
> dependency without adding signal.

## Default Smokes (Always Run)

### Module status

```bash
{magento_cli} module:status
```

Pass if every deployed module appears in the enabled list.

### DB status

```bash
{magento_cli} setup:db:status
```

Pass if output is "Magento Database is up to date" or equivalent zero-exit.

### Cache type status

```bash
{magento_cli} cache:status
```

Pass if no cache type is in an unexpected state (all "Enabled" or all "Disabled" per
project convention).

### Error signals since the deploy started

An HTTP 200 does not mean nothing broke. Magento records failures in three places, and two of
them never reach `exception.log`:

| Source | Written by | Reaches `exception.log`? |
|--------|-----------|--------------------------|
| `var/report/{sha256}` (nested under `xx/yy/` when `MAGE_ERROR_REPORT_DIR_NESTING_LEVEL` is set) | `pub/errors/processor.php::saveReport()` via `App\ExceptionHandler` | yes on 2.4.8 (`ExceptionHandler.php:252`), not on every version |
| `var/report/api/{id}` | `Webapi\ErrorProcessor::apiShutdownFunction()` on a PHP fatal | **no — that path makes no logger call at all** |
| `var/log/system.log`, `var/log/{vendor}_{module}.log` | any `$logger->error()/critical()` **without** an exception in the context | **no** — `Logger\Handler\System::write()` routes to `exception.log` only when `$record['context']['exception']` is set |

So `smoke.sh` scans both, windowed on the deploy start:

```bash
SINCE_TS="{deploy started_at}" MAGENTO_ROOT="{magento_root}" MODULES="{modules}" \
    ${CLAUDE_SKILL_DIR}/scripts/smoke.sh
```

| Check | Fail | Warn | Pass |
|-------|------|------|------|
| `error-reports` | any `var/report/**` file with mtime inside the window | — | none |
| `error-logs` | an ERROR+ entry inside the window naming a **deployed** module (`Vendor_Module` / `Vendor\Module`) | ERROR+ entries naming none of them (pre-existing site noise) | no ERROR+ entries |

Notes:

- `SINCE_TS` takes ISO 8601 or epoch seconds. **Pass the real deploy start** — without it the
  scan falls back to a 15-minute window and says so in the detail string.
- `debug.log` is skipped: it mirrors the other handlers, so it would double-count.
- Only the last 2 MiB of each log is read; a deploy window never reaches further back, and it
  keeps a multi-GB `cron.log` cheap.
- Without python3 the check records `skipped` with an explicit "var/report and var/log NOT
  checked" detail — it never reports pass on an unchecked source.
- A `fail` here does not roll back (the deploy completed) — it is a "needs investigation"
  finding, and `var/report` files decode to message + trace + URL for triage via
  `debug`.

## Surface-Driven Smokes

Run only for surfaces present in the deployed modules.

### `rest_api`

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
    "{base_url}/rest/V1/{vendor_lower}/{route}/health"
```

Pass: 200, 401 (unauth check enforced), or 403 (ACL enforced).
Fail: 500 (server error), connection refused, timeout.

For each declared route in `webapi.xml`, hit a representative endpoint. Don't try to
authenticate — a 401 is the right answer for an unauth call.

### `graphql`

```bash
curl -s -X POST "{base_url}/graphql" \
    -H "Content-Type: application/json" \
    -d '{"query":"query{__schema{queryType{name}}}"}' \
    | jq '.data.__schema.queryType.name'
```

Pass: returns `"Query"`. Fail: error in response, 500, connection refused.

If the module declares mutations: also probe one mutation's schema:

```bash
curl -s -X POST "{base_url}/graphql" \
    -H "Content-Type: application/json" \
    -d '{"query":"query{__type(name:\"Mutation\"){fields{name}}}"}'
```

### `admin_ui`

```bash
curl -s -o /dev/null -w '%{http_code}\n' "{base_url}/{admin_path}/"
```

`{admin_path}` is the install's backend frontName, which is rarely `admin` on a real install: take
it from `ADMIN_PATH`, else `app/etc/env.php` → `backend.frontName`, else guess `admin`.

Pass: 302 (redirect to login). Fail: 500, or 404 at a known frontName. A 404 at the *guessed*
`/admin/` is `skipped` — the path is unknown, which says nothing about the admin.

Use curl's status as printed: on a connection or TLS failure `-w '%{http_code}'` already prints
`000`, so a `|| echo 000` fallback turns it into `000000`. On a local stack with a self-signed
certificate pass `-k`; `smoke.sh` does so for `localhost`, `*.localhost`, `*.test` and loopback, or
for any host with `SMOKE_CURL_INSECURE=1`.

If the module adds an admin route, also probe its URL (expect 302 to login, not 404 or
500).

Stay with `curl` here even when a headless browser happens to be available. Confirming the admin
*renders* is Phase 6B's job in `feature`, not the deploy gate's.

### `frontend_ui`

```bash
curl -s -o /dev/null -w '%{http_code}\n' "{base_url}/{vendor_lower}_{module_lower}/{route}/"
```

Pass: 200, 302, 404 (if module doesn't expose a public route). Fail: 500.

Same rule as `admin_ui`: `curl` only. A 200 proves the route is wired; rendering is out of scope
for a deploy smoke.

### `cron`

There is no `bin/magento cron:status` command. Verify cron health without mutating state:

```bash
# 1. The OS crontab that drives Magento cron is installed:
crontab -l 2>/dev/null | grep -q "bin/magento cron:run" && echo "crontab installed" || echo "crontab MISSING"
# 2. Cron has run recently — inspect the cron_schedule table (rows in the last ~10 min):
{magento_cli} setup:db:status >/dev/null 2>&1 && echo "db reachable; check cron_schedule via DB client"
```

Pass: the crontab entry is installed and `cron_schedule` shows recent `success`/`pending`
rows. To confirm a newly declared job is registered, check Admin → System → Cron (Scheduled
Tasks) or query `cron_schedule` for the job code — the merged `crontab.xml` jobs appear there
after the first cron tick.

### `queue`

```bash
{magento_cli} queue:consumers:list
```

Pass: output includes every consumer declared in the deployed modules'
`queue_consumer.xml`.

## Optional Smokes

Run when the relevant infra is available.

### Redis hit rate (if Redis CLI present)

```bash
redis-cli INFO stats | grep -E 'keyspace_(hits|misses)'
```

Report: hit rate. No pass/fail — informational only.

### Varnish health (if Varnish detected)

```bash
curl -s -I "{base_url}/" | grep -i 'X-Magento-Cache-Debug'
```

Pass: header present (Varnish is in front). Fail: header absent (Varnish bypassed).

### Database connectivity

```bash
{magento_cli} setup:db:status
```

Already part of default smokes; mentioned again because it covers DB connectivity.

## Reporting Smoke Results

Append to deploy report:

```markdown
## Smoke Tests

| Surface | Test | Result | Detail |
|---------|------|--------|--------|
| Module status | enabled list | Pass | All 3 modules enabled |
| REST API | GET /V1/acme/orders/health | Pass | 200 |
| GraphQL | __schema query | Pass | Query |
| Admin UI | /admin/ | Pass | 302 |
| Frontend UI | /acme_orderexport/order/index | Fail | 500 (see investigation note) |
| Cron | jobs list | Pass | acme_export_run found |
```

## Smoke Failures Are Not Deploy Failures

A smoke fail means the deploy succeeded mechanically but post-deploy behaviour needs
investigation. The report flags it; the user decides whether to roll back manually or
patch forward. Auto-rollback on smoke failure is too aggressive — the deploy already
succeeded.
