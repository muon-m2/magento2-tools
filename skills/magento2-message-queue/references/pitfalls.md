# Common Pitfalls — Message Queues

## 1. Topic / queue / consumer name drift across the XML files (the #1 bug)

**Pitfall:** the topic in `communication.xml` is `acme.orders.order.export` but
`queue_publisher.xml` says `acme.orders.orders.export` (typo), or the `queue` in
`queue_consumer.xml` doesn't match the `destination` in `queue_topology.xml`.

**Why it matters:** there is **no error**. Messages publish successfully to an exchange
that has no binding for that topic, or a consumer drains a queue nothing routes to. The
feature silently does nothing and looks like a "the consumer never runs" mystery.

**Fix:** the SAME `{TopicName}` string must appear in `communication.xml`,
`queue_topology.xml`, `queue_publisher.xml`, and the publisher's `TOPIC` constant. The SAME
`{QueueName}` in `queue_topology.xml` (`destination`) + `queue_consumer.xml` (`queue`). The
SAME `{ConsumerName}` in `queue_consumer.xml` (`name` + handler FQCN) + the consumer class
+ its test. Verify byte-for-byte after substitution — read all wiring points side by side.
Keep the PHP topic literal in a single `TOPIC` class const, never inline.

---

## 2. Non-idempotent consumer

**Pitfall:** the handler inserts a row / sends an email / charges a card every time it
receives a message. A broker retry (the worker crashed after doing the work but before
ack-ing) re-delivers the message and the side effect happens twice.

**Why it matters:** message delivery is *at-least-once*, not exactly-once. Redelivery is
normal, not exceptional.

**Fix:** make `process()` idempotent. Guard the side effect on a processed-marker:
- check a status flag / `processed_at` column and return early if already done;
- use `INSERT … ON DUPLICATE KEY UPDATE` / a unique constraint;
- key external calls on an idempotency token derived from the message.

A second delivery of the same message must be a safe no-op — this is exactly what the
consumer unit test asserts.

---

## 3. Poison messages re-queued forever

**Pitfall:** a malformed or permanently-failing message throws on every attempt; the broker
keeps re-queuing it. The consumer is stuck reprocessing the same bad message and never
drains the rest of the queue (head-of-line blocking).

**Fix:** distinguish *retryable* from *un-retryable* failures.
- Un-retryable (bad data, missing referenced entity): catch it, log with the message
  payload, and let it drop — do NOT re-throw, or configure a dead-letter queue (DLQ) so it
  is parked for inspection instead of looping.
- Retryable (transient DB/network error): re-throw so the broker redelivers, ideally with a
  bounded retry count.

Never let an un-recoverable message block the queue indefinitely.

---

## 4. Heavy synchronous work inside the consumer

**Pitfall:** the consumer does the full expensive operation (image processing, a slow
external API call, a multi-minute report) inline, holding the message and blocking the
worker for the whole duration.

**Why it matters:** the queue exists to *decouple* slow work — but a single oversized unit
of work per message just moves the bottleneck. It also widens the redelivery window (longer
work = more chance of a crash mid-processing).

**Fix:** keep each message a small, well-bounded unit of work. Pass an **id** in the
message and re-load the entity inside the handler; process one entity per message. For
fan-out, publish many small messages rather than one giant one. Delegate the actual domain
logic to an injected service the consumer calls — the consumer class only decodes the
message and dispatches.

---

## 5. Serialization mismatch (DTO ↔ topic request)

**Pitfall:** the topic's `request` in `communication.xml` is the interface FQCN, but the
`di.xml` `<preference>` for that interface is missing, or the message model exposes setters
without matching getters. The payload fails to (de)serialize.

**Fix:**
- Always ship the `di.xml` `<preference>` binding the message interface to its model.
- Every field that must round-trip needs a typed **getter** (the serializer reflects over
  getters). A setter-only field is silently dropped.
- Keep payload fields scalar/nullable-scalar; pass ids, not nested entity graphs.

---

## 6. Publishing a bare array instead of the typed DTO

**Pitfall:** `$this->publisher->publish($topic, ['id' => 5])` — an array slips past at
publish time but the consumer's typed `process({EntityName}Interface $message)` cannot
accept it, or the framework cannot map it to the declared `request` type.

**Fix:** build and publish the typed DTO. The topic `request` type and the consumer
parameter type must be the same interface. See `message-dto.md`.

---

## 7. Wrong `connection` or assuming AMQP exists

**Pitfall:** setting `connection="amqp"` on a project with no RabbitMQ broker — the
publish/consume layer throws connection errors at runtime.

**Fix:** default to `connection="db"` (MySQL-backed, no broker needed). Only use `amqp`
after confirming a reachable, configured RabbitMQ. Keep the `connection` value identical
across `queue_publisher.xml`, `queue_topology.xml`, and `queue_consumer.xml`.

---

## 8. Consumer never appears in `queue:consumers:list`

**Pitfall:** after deploy the consumer doesn't show up, so `queue:consumers:start` reports
an unknown consumer.

**Fix:** confirm the file is `etc/queue_consumer.xml` (not `consumer.xml`), the schema URN
is `urn:magento:framework-message-queue:etc/consumer.xsd`, and you ran
`setup:upgrade` + `cache:flush`. See `consumer-runtime.md`.
