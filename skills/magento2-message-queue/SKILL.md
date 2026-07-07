---
name: magento2-message-queue
description:
    Scaffold a full async message-queue surface on an existing module — communication.xml
    topic, queue_topology/publisher/consumer.xml bindings, a typed message DTO, a publisher,
    and an idempotent consumer/handler. Use for 'process X asynchronously' / 'add a queue
    consumer'. Goes beyond magento2-module-create's queue stub. For a new module use
    `magento2-module-create` first.
---

# Magento 2 Message Queue

Scaffold a full **async message-queue** surface onto an **existing** Magento 2 module: a
`communication.xml` topic, the `queue_topology.xml` / `queue_publisher.xml` /
`queue_consumer.xml` bindings, a typed message DTO (interface + model + `di.xml`
preference), a `PublisherInterface`-backed publisher, and an idempotent consumer that
decodes the typed message and delegates to a domain handler.

This goes beyond the bare queue stub `magento2-module-create` emits: it wires all five
XML config files so the topic ↔ topology ↔ publisher ↔ consumer ↔ queue chain actually
resolves, and bakes in idempotency + poison-message handling. For a brand-new module run
`magento2-module-create` first.

## Core Rules

- **Topic name convention:** `{vendor_lower}.{module_lower}.{entity}.{action}` (all
  lowercase, dot-separated). The SAME topic string is the join key across
  `communication.xml`, `queue_topology.xml`, `queue_publisher.xml`, and the publisher's
  `TOPIC` constant — drift across these files is the #1 message-queue bug. See
  `magento2-context/references/naming.md` §9 Queue.
- **Default `connection="db"`.** Use the MySQL-backed queue (`db`) unless the project has
  a confirmed, running AMQP/RabbitMQ broker. Only set `connection="amqp"` when AMQP is
  confirmed; `db` requires no broker and is the safe default.
- **Messages are typed DTOs, never arrays.** The message payload is a typed interface
  (`Api/Data/{EntityName}Interface`) + implementation (`Model/{EntityName}`) bound by a
  `di.xml` `<preference>`. `communication.xml` declares the topic `request` as the
  interface FQCN so the framework (de)serializes it. NEVER publish a bare array — it
  defeats schema validation and breaks the consumer's typed signature.
- **Consumers must be idempotent.** A redelivered message (broker retry, crash between
  ack and commit) must produce the same end state — a second delivery of the same message
  is a safe no-op. Guard with a processed-marker / status flag in the handler.
- **Handle poison messages.** A message that can never succeed must be rejected (not
  re-queued forever). Catch the un-retryable case, log it, and let it drop / route to a
  dead-letter queue — see `${CLAUDE_SKILL_DIR}/references/pitfalls.md`.
- **Never hardcode an infinite loop.** Document `--max-messages` and `max_idle_time`
  guidance for `queue:consumers:start`; rely on the `consumers_runner` cron rather than a
  hand-rolled `while (true)`. See `${CLAUDE_SKILL_DIR}/references/consumer-runtime.md`.
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2
  coding standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the
  gate. See `magento2-context/references/php-coding-style.md`.
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `magento2-context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture the
JSON as `{ctx}`. Abort if `{ctx.magento_root}` is unresolved.

**Hard stop if the target module does not exist.** Offer `magento2-module-create` and do
not scaffold a queue surface into a non-existent module.

### Phase 1 — Resolve Inputs

Ask for any missing values in one batch.

| Input | Default | Notes |
|-------|---------|-------|
| Module | (ask) | Existing `{Vendor}_{Module}` |
| Topic name | (ask) | `{vendor_lower}.{module_lower}.{entity}.{action}`, e.g. `acme.orders.order.export` |
| Message DTO | (ask) | `{EntityName}` (PascalCase) + its typed fields (name + type each) |
| Publisher class name | (ask) | PascalCase, e.g. `OrderExportPublisher`; placed in `Model/` |
| Consumer name | (ask) | PascalCase, e.g. `OrderExportConsumer`; placed in `Model/Consumer/`; also the `consumer.xml` `name` |
| Handler method | (ask) | The domain service method the consumer delegates to (e.g. `process`) |
| Connection | `db` | `db` (MySQL, no broker) or `amqp` (confirmed RabbitMQ only) |
| Queue name | (ask) | `{vendor_lower}.{module_lower}.{queue}`, e.g. `acme.orders.export` |
| Exchange name | `magento` (db) / (ask, AMQP) | AMQP only; `db` connection uses the implicit `magento` exchange |

See `${CLAUDE_SKILL_DIR}/references/mq-architecture.md` and
`${CLAUDE_SKILL_DIR}/references/message-dto.md`.

### Phase 2 — Plan

Present every file to create or modify. Typical file set:

- `etc/communication.xml` (merge — topic declaration)
- `etc/queue_topology.xml` (merge — exchange + binding)
- `etc/queue_publisher.xml` (merge — publisher → connection/exchange)
- `etc/queue_consumer.xml` (merge — consumer → queue/handler)
- `etc/di.xml` (merge — DTO `<preference>`)
- `Api/Data/{EntityName}Interface.php`
- `Model/{EntityName}.php`
- `Model/{PublisherName}.php`
- `Model/Consumer/{ConsumerName}.php`
- `Test/Unit/Model/Consumer/{ConsumerName}Test.php`

Wait for "proceed."

### Phase 3 — Test First, then Generate

**3A — Write the failing test (RED).** Before generating implementation code, write the
consumer unit test and confirm it fails for the right reason (class-not-found, not a setup
error):

- **Consumer test** (`Test/Unit/Model/Consumer/{ConsumerName}Test.php`): mock the typed
  `{EntityName}Interface` message and the injected domain handler/service. Assert
  `process($message)` calls the handler `expects(self::once())` with the decoded message.
  Then assert that a **second** delivery of the **same** message is a safe no-op for the
  consumer class itself (idempotency-safety). Mock expectations ARE assertions — no
  `markTestIncomplete`, no `self::assertTrue(true)`.
- **Prerequisite:** the injected domain handler/service (e.g. `{EntityName}Handler`) must
  already exist or be stubbed before running the RED test, otherwise the failure is a
  handler-not-found error rather than the intended consumer-not-found RED.

Follow `magento2-context/references/tdd-discipline.md`.

**3B — Generate implementation (GREEN).** Write the minimal code to make the 3A test
pass, using the templates:

- `${CLAUDE_SKILL_DIR}/templates/communication.xml`
- `${CLAUDE_SKILL_DIR}/templates/queue_topology.xml`
- `${CLAUDE_SKILL_DIR}/templates/queue_publisher.xml`
- `${CLAUDE_SKILL_DIR}/templates/queue_consumer.xml`
- `${CLAUDE_SKILL_DIR}/templates/queue-di.xml`
- `${CLAUDE_SKILL_DIR}/templates/message-interface.php`
- `${CLAUDE_SKILL_DIR}/templates/message-model.php`
- `${CLAUDE_SKILL_DIR}/templates/publisher.php`
- `${CLAUDE_SKILL_DIR}/templates/consumer.php`
- `${CLAUDE_SKILL_DIR}/templates/test-consumer-unit.php`

The SAME topic string must appear in `communication.xml`, `queue_topology.xml`,
`queue_publisher.xml`, and the publisher's `TOPIC` const; the SAME queue name in
`queue_topology.xml` + `queue_consumer.xml`; the SAME consumer name in
`queue_consumer.xml` + the consumer class + its test. See
`${CLAUDE_SKILL_DIR}/references/mq-architecture.md` and
`${CLAUDE_SKILL_DIR}/references/pitfalls.md`.

### Phase 4 — Verify

- `php -l` on every generated `.php` file.
- `xmllint --noout` on every generated `.xml` file.
- Run the Phase 3A test with `{ctx.runner} vendor/bin/phpunit` and confirm it now
  **passes** (it failed before 3B); run the module suite to confirm nothing else broke.
- Run `magento2-module-review --diff` (gate: zero Critical/High findings).
- **Apply the shared module-hygiene baseline (required).** After generating or modifying PHP
  files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` (idempotent — it skips files that
  already carry it). When adding a `composer.json` `require` entry, resolve a **bounded**
  constraint via
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>` —
  never `"*"`. See `magento2-context/references/module-hygiene.md`.
- Consult `${CLAUDE_SKILL_DIR}/references/pitfalls.md` before declaring Phase 4 done —
  verify the topic/queue/consumer names are byte-identical across all wiring points.

### Phase 5 — Report

Write a brief Markdown report to
`{output_root}/message-queues/{Vendor}_{Module}-{topic}-{date}.md` listing:

- Topic name, queue name, consumer name, connection
- Files generated
- Test path + red→green evidence
- `bin/magento setup:upgrade` + `bin/magento cache:flush` commands
- How to run the consumer: `bin/magento queue:consumers:start {ConsumerName} --max-messages=1000`
- How to verify wiring: `bin/magento queue:consumers:list`

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/message-queues/`; otherwise default to
`{ctx.docs_root}/message-queues/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

> **Docs may now be stale.** This change modified module code. Run
> `magento2-docs-generate --module={Vendor}_{Module}` to refresh the module's README,
> CHANGELOG, and `docs/*.md` (technical reference, guides, and API references as
> applicable).

## Inputs

```
/magento2-message-queue --module=Acme_Orders --topic=acme.orders.order.export \
  --entity=OrderExport --publisher=OrderExportPublisher --consumer=OrderExportConsumer \
  --queue=acme.orders.export --connection=db [--docs-root=<path>]
```

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/communication.xml             # merge
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/queue_topology.xml            # merge
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/queue_publisher.xml           # merge
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/queue_consumer.xml            # merge
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/di.xml                        # merge
{ctx.magento_root}/app/code/{Vendor}/{Module}/Api/Data/{EntityName}Interface.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/{EntityName}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/{PublisherName}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Consumer/{ConsumerName}.php
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Model/Consumer/{ConsumerName}Test.php

{output_root}/message-queues/{Vendor}_{Module}-{topic}-{date}.md
```

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/mq-architecture.md` — how the topic ↔ topology
  exchange/binding ↔ publisher ↔ consumer ↔ queue fit together; `db` vs `amqp`.
- `${CLAUDE_SKILL_DIR}/references/message-dto.md` — the typed message DTO (interface +
  impl + `di.xml` preference), serialization, why not arrays.
- `${CLAUDE_SKILL_DIR}/references/consumer-runtime.md` — `queue:consumers:start`,
  `queue:consumers:list`, the `consumers_runner` cron, `--max-messages`, `max_idle_time`.
- `${CLAUDE_SKILL_DIR}/references/pitfalls.md` — idempotency, poison messages / DLQ, no
  heavy synchronous work, serialization mismatch, topic/queue name drift across the XML.
- `magento2-context/references/naming.md` — topic/queue/consumer naming conventions.
- `magento2-context/references/tdd-discipline.md` — shared test-first RED/GREEN loop.
- `magento2-context/references/php-coding-style.md` — PER-CS + Magento coding style.
- `magento2-context/references/placeholder-schema.md` — token registry.
- `magento2-context/references/source-of-truth.md`: source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

- `templates/communication.xml` → `etc/communication.xml` (merge)
- `templates/queue_topology.xml` → `etc/queue_topology.xml` (merge)
- `templates/queue_publisher.xml` → `etc/queue_publisher.xml` (merge)
- `templates/queue_consumer.xml` → `etc/queue_consumer.xml` (merge)
- `templates/queue-di.xml` → `etc/di.xml` (merge)
- `templates/message-interface.php` → `Api/Data/{EntityName}Interface.php`
- `templates/message-model.php` → `Model/{EntityName}.php`
- `templates/publisher.php` → `Model/{PublisherName}.php`
- `templates/consumer.php` → `Model/Consumer/{ConsumerName}.php`
- `templates/test-consumer-unit.php` → `Test/Unit/Model/Consumer/{ConsumerName}Test.php`

All templates follow the placeholder registry in
`magento2-context/references/placeholder-schema.md`. Every token used must be in the
Registry there — `tests/test-placeholder-tokens.sh` enforces it.

## Acceptance Criteria

- All generated files pass `php -l` / `xmllint --noout`.
- Topic name follows `{vendor_lower}.{module_lower}.{entity}.{action}`; the SAME topic
  string appears in `communication.xml`, `queue_topology.xml`, `queue_publisher.xml`, and
  the publisher's `TOPIC` const.
- The same queue name appears in `queue_topology.xml` + `queue_consumer.xml`; the same
  consumer name in `queue_consumer.xml` + the consumer class + its test.
- `connection="db"` unless AMQP is confirmed.
- Message payload is a typed DTO (interface + model + `di.xml` preference), never an array.
- Consumer test: handler mock uses `expects(self::once())` with the decoded message; a
  second delivery is a safe no-op; no `markTestIncomplete`, no `self::assertTrue(true)`.
- `magento2-module-review --diff` returns zero Critical/High findings.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| Before (if module absent) | `magento2-module-create` |
| The bare queue stub | `magento2-module-create` |
| After | `magento2-module-review --diff` |
