# Consumer Runtime

A consumer declared in `queue_consumer.xml` does not run on its own — a worker process
must drain its queue. Magento provides the `queue:consumers:*` CLI plus a cron-based
auto-runner.

## Listing consumers

```
bin/magento queue:consumers:list
```

Prints every declared consumer name (from all modules' `queue_consumer.xml`). If your
`{ConsumerName}` is **not** in the list after `setup:upgrade` + `cache:flush`, the
`queue_consumer.xml` did not load — check the file location (`etc/queue_consumer.xml`) and
schema URN.

## Starting a consumer

```
bin/magento queue:consumers:start {ConsumerName} --max-messages=1000
```

Key flags:

| Flag | Purpose | Guidance |
|------|---------|----------|
| `--max-messages=N` | Process at most N messages, then exit | **Always set this.** Lets a supervisor (systemd / Docker) restart the worker on a clean boundary; prevents an ever-growing process. |
| `--batch-size=N` | Messages fetched per batch | Tune for throughput; default is fine for most. |
| `--single-thread` | One message at a time | Use when the handler is not concurrency-safe. |

**Never hardcode an infinite loop in PHP.** The CLI worker IS the loop; control its
lifetime with `--max-messages` and an external supervisor that restarts it. A hand-rolled
`while (true)` in a consumer class leaks memory and cannot be drained gracefully.

## The auto-runner cron (`consumers_runner`)

Magento ships a cron job, `consumers_runner`, that starts declared consumers automatically.
It is configured in `app/etc/env.php`:

```php
'cron_consumers_runner' => [
    'cron_run'     => true,        // false to disable the auto-runner entirely
    'max_messages' => 1000,        // messages per consumer per cron tick
    'consumers'    => [],          // empty = ALL consumers; or an allow-list of names
    'multiple_processes' => 1,
],
```

- `cron_run => true` is the default — every cron tick the runner starts each consumer for
  up to `max_messages` messages, then they exit. This makes `db`-connection queues "just
  work" with no extra supervisor.
- To run only specific consumers via cron, list them by name in `consumers`.
- For high-volume AMQP setups, set `cron_run => false` and run dedicated long-lived
  workers under systemd/supervisord instead, each with its own `--max-messages`.

## `max_idle_time`

For a long-lived worker (AMQP), `max_idle_time` (seconds) in the consumer config bounds how
long a consumer waits with no messages before exiting — so an idle worker releases its
memory and the supervisor restarts it fresh. Pair it with `--max-messages`: whichever limit
is hit first ends the run cleanly.

## Verifying end to end

1. `bin/magento setup:upgrade && bin/magento cache:flush`
2. `bin/magento queue:consumers:list` → confirm `{ConsumerName}` appears.
3. Publish a message (trigger the publisher path).
4. `bin/magento queue:consumers:start {ConsumerName} --max-messages=1` → confirm the
   handler ran exactly once and the message was acked.
5. Re-run step 4 with the same logical input → confirm the idempotency guard makes the
   second processing a no-op (no duplicate side effect).
