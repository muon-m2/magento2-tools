# Smoke Tests

Surface-driven smoke tests run after Phase 3 (Execute). A smoke failure does NOT trigger
rollback (the deploy completed) but it surfaces a "needs investigation" finding in the
report.

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
curl -s -o /dev/null -w '%{http_code}\n' "{base_url}/admin/"
```

Pass: 302 (redirect to login). Fail: 500 or 404.

If the module adds an admin route, also probe its URL (expect 302 to login, not 404 or
500).

### `frontend_ui`

```bash
curl -s -o /dev/null -w '%{http_code}\n' "{base_url}/{vendor_lower}_{module_lower}/{route}/"
```

Pass: 200, 302, 404 (if module doesn't expose a public route). Fail: 500.

### `cron`

```bash
{magento_cli} cron:status
```

Pass: output includes every cron job declared in the deployed modules' `crontab.xml`.

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
