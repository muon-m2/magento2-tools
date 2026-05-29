# Queue Health

## Probes

```
{ctx.magento_cli} queue:consumers:list
```

Lists registered consumers. A finding fires when a module declares a consumer in
`queue_consumer.xml` but the consumer is not in the runtime registry.

## Backlog Thresholds

| Backlog | Severity | Action |
|---------|----------|--------|
| < 100 messages | Info | Normal |
| 100–1000 | Low | Watch |
| 1000–10000 | Medium | Investigate consumer throughput |
| > 10000 | High | Consumer is failing or under-provisioned |

Measured via:
- RabbitMQ Management API: `GET /api/queues/%2F/{queue-name}`
- Or DB queue (legacy): `SELECT COUNT(*) FROM queue_message WHERE topic_name = ?`

## Dead-Letter Handling

Every consumer must handle poison messages:
- Catch unmarshalling errors → log + move to DLQ
- Catch processing errors → retry with backoff up to N times → DLQ
- Never re-throw to RabbitMQ → that causes infinite redelivery

A finding fires when consumer code:
```php
public function process($message) {
    $data = json_decode($message); // unguarded — bad input crashes consumer
    $this->service->doStuff($data);
}
```

Recommended pattern:
```php
public function process($message) {
    try {
        $data = json_decode($message, true, 512, JSON_THROW_ON_ERROR);
        $this->service->doStuff($data);
    } catch (\JsonException $e) {
        $this->logger->error('Bad message', ['raw' => $message, 'error' => $e->getMessage()]);
        return; // ack to remove from queue
    } catch (\Exception $e) {
        $this->logger->error('Processing failed', ['error' => $e->getMessage()]);
        throw $e; // requeue (with retry limit)
    }
}
```

## Batching

Consumers processing > 100 messages/second benefit from batching:

```xml
<consumer name="...">
    <handler service="..." method="processBatch"/>
    <maxMessages>100</maxMessages>
</consumer>
```

A finding fires when a high-throughput consumer is configured for single-message
processing.

## Consumer Starvation

When multiple consumers exist:
- If only some consumers run, the others starve.
- Use `bin/magento queue:consumers:start --multi-process=N` for parallel processing.
- For Magento 2.4.5+: `bin/magento queue:consumers:start --max-messages=N --batch-size=M`.

## Cron-Driven Consumers

`cron_consumers_runner` is the default Magento bootstrap for consumers. It runs every
minute and starts each registered consumer if not already running.

A finding fires when `cron_consumers_runner` is disabled and no alternative consumer
runner is documented.

## Recommended Findings

| Pattern | Severity |
|---------|---------|
| Consumer without DLQ handling | High |
| Consumer crashes on bad input (no try/catch around json_decode) | High |
| High-throughput consumer without batch | Medium |
| Queue backlog > 10K | High |
| `cron_consumers_runner` disabled | Medium |
