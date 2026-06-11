# Reproduction Patterns

Recipes for reproducing a Magento 2 bug deterministically.

## HTTP — Frontend / REST / GraphQL

### Frontend page

```
curl -sSL -o /tmp/page.html -D /tmp/headers.txt \
    -H "Cookie: PHPSESSID={session}" \
    "{base_url}/{path}"
```

Capture both body and headers. For pages requiring CSRF, fetch the form first and parse
the form key from the HTML.

### REST API

```
curl -sSL -X POST "{base_url}/rest/V1/{route}" \
    -H "Authorization: Bearer {token}" \
    -H "Content-Type: application/json" \
    -d '{"payload": ...}' | jq .
```

For admin tokens: `bin/magento admin:user:create` first, then exchange for a token via
`/V1/integration/admin/token`.

### GraphQL

```
curl -sSL -X POST "{base_url}/graphql" \
    -H "Content-Type: application/json" \
    -H "Store: default" \
    -d '{"query": "query { ... }"}' | jq .
```

For mutations requiring customer auth, include `Authorization: Bearer {customerToken}`.

## CLI

```
{ctx.magento_cli} {command} {args}
```

Example:

```
{ctx.magento_cli} indexer:reindex
{ctx.magento_cli} catalog:images:resize
{ctx.magento_cli} {vendor}:{module}:{action}
```

## Cron Job

```
{ctx.magento_cli} cron:run --group={group}
```

Common groups: `default`, `index`, `consumers`, `catalog_event`. Inspect `crontab.xml`
for the failing job's group.

To trigger a specific cron job:

```
{ctx.runner} php -r "..." # invoke the cron class directly with required deps
```

Or, in Magento 2.4.5+:

```
{ctx.magento_cli} cron:run --bootstrap=standaloneProcessStarted=1 --group={group}
```

## Queue Consumer

```
{ctx.magento_cli} queue:consumers:start {consumer-name} --max-messages=1
```

This runs one message and exits — perfect for reproducing a consumer crash without
flooding the queue.

For RabbitMQ, send a test message via the management API or `rabbitmqadmin`:

```
rabbitmqadmin publish exchange={ex} routing_key={topic} payload='{...}'
```

## Database State Setup

When the bug requires specific data:

```
{ctx.runner} mysql -u magento -p{pw} magento -e "SELECT ... FROM ..."
```

Or seed via a Setup/Patch/Data class in a throwaway test module — preferred for
repeatable reproduction.

## Browser Reproduction

For frontend bugs not captured by curl (KO, JS), record:

- Browser + version
- Steps (1, 2, 3...)
- Network HAR file path (if user can share)
- Console errors

The reproduction recipe says "open this URL, click X, expect Y, see Z."

## Reproduction Recipe Document

Save to `.docs/bug-fixes/{slug}/reproduction.md`:

```markdown
# Reproduction Recipe

## Prerequisites
- Magento mode: developer
- User: customer@example.com / Password123
- Cart contains: SKU-001 x 1
- Coupon applied: WELCOME10

## Steps
1. Open {base_url}/checkout
2. Select shipping: Flat Rate
3. Click "Place Order"
4. Observe error: "Undefined index: total_paid"

## Expected
Order is placed; redirect to /checkout/onepage/success.

## Actual
Exception thrown; logged to var/log/exception.log line {N}.

## Trigger Frequency
1 in 1 reproductions (deterministic) / 3 in 5 reproductions (intermittent).

## Last Verified
{YYYY-MM-DD HH:MM} by {user/agent}
```

## When Reproduction Fails

After 2 attempts:

1. Stop. Do not guess at the cause.
2. Report what was tried, what was observed.
3. Ask the user for:
    - Exact env where they saw it
    - Any preconditions you might have missed
    - HAR file, screen recording, or shell session

Do not proceed to Phase 3 (RCA) without a reproduction. Speculative RCAs lead to wrong
fixes. Note: a **failing automated test that captures the defect counts as a valid
reproduction** — per the SKILL, the test encodes the reproduction. A manual click-path is
not required when a unit/integration test reliably fails on the bug and passes once it is
fixed. "Deterministic" here means the *test* fails reliably, not that the bug must be
hand-triggered.
