# Magento 2 Tradeoffs Catalog

Document applicable tradeoffs from this catalog in the Phase 7 final report. For each tradeoff,
state which option was chosen and why. Never include tradeoffs that are not relevant to the feature.

---

## Architecture

### Observer vs Plugin

**Observer (event/observer):**
- Use when: reacting to Magento lifecycle events (`catalog_product_save_after`, `checkout_submit_all_after`, etc.)
- Pro: loose coupling, multiple observers can listen to the same event
- Con: cannot alter the return value; event data is not type-safe; firing order is not guaranteed
- When to prefer: side effects (sending notifications, logging, triggering async jobs)

**Plugin (interceptor):**
- Use when: modifying method input arguments, return values, or wrapping execution
- Pro: type-safe; can modify behavior without replacing the class; before/around/after control
- Con: cannot be applied to final classes; around plugins add call-stack depth; difficult to debug
  when chained
- When to prefer: altering catalog prices, modifying search results, adding validation to checkout

**Rule of thumb:** if you need the original return value or must change input args, use a plugin.
If you only need to react, use an observer.

---

### New Module vs Modify Existing

**New module:**
- Pro: single responsibility; independently versioned; can be disabled without affecting the host module
- Con: more boilerplate; another `setup:upgrade` step; increases module graph complexity
- When to prefer: new entity, new integration, new surface, or code that would make the existing
  module's name misleading

**Modify existing:**
- Pro: less boilerplate; shares existing DI wiring, ACL, and routes
- Con: couples unrelated concerns; harder to isolate in testing; may break the module's SRP
- When to prefer: small extensions (≤ 5 files) that genuinely belong to the module's stated concern

---

### Service Contract Abstraction Overhead

**Expose via interface (service contract):**
- Pro: future-proof; enables REST/GraphQL exposure; allows preference substitution in DI
- Con: additional interface file; boilerplate DTOs; callers must use factory for DTO construction
- When to prefer: anything that may be called from another module or exposed via API

**Direct model/repository call:**
- Pro: simpler, fewer files
- Con: tight coupling; cannot be replaced via DI without a class preference; not API-safe
- When to prefer: internal-only utilities or cron jobs that will never be called externally

---

## Async and Scheduling

### Cron vs Message Queue

**Cron:**
- Use when: work is time-triggered (nightly sync, hourly report), not event-triggered
- Pro: built into Magento; simple configuration; no broker required
- Con: fixed schedule; no retry mechanism beyond re-running the next tick; all-or-nothing per run
- Risk: long-running cron jobs may overlap if the previous run has not finished

**Message Queue (RabbitMQ):**
- Use when: work is event-triggered, high-volume, or must be retried on failure
- Pro: decoupled producer and consumer; built-in retry; scales horizontally
- Con: requires a running RabbitMQ broker; harder to debug; message schema must be versioned
- Risk: queue backlog if consumer is down; message ordering is not guaranteed by default

**Rule of thumb:** use cron for scheduled batch work; use queue for per-event async work at scale.

---

## API Design

### REST vs GraphQL

**REST:**
- Use when: the consumer is an external system, mobile app, or third-party integration
- Pro: widely supported; cacheable GET requests; Magento's `webapi.xml` wiring is straightforward
- Con: over-fetching (fixed response shape); versioning by URL is cumbersome

**GraphQL:**
- Use when: the consumer is a PWA/headless storefront needing flexible data fetching
- Pro: client specifies exact fields; single endpoint; well-suited for nested entity graphs
- Con: N+1 query risk without batch loaders; mutations are less ergonomic than REST for integrations;
  Magento GraphQL auth context is limited

**Rule of thumb:** expose REST for integrations; expose GraphQL for frontend/PWA consumers.
Both can coexist in the same module via separate `webapi.xml` and `schema.graphqls` files.

---

## Data

### EAV Extension Attributes vs New Table

**Extension attributes (EAV join):**
- Use when: adding 1–3 attributes to an existing Magento entity (product, order, customer)
- Pro: no migration risk; integrates with Magento's existing entity APIs
- Con: performance degrades with many attributes; not suitable for complex relationships or queries

**New table:**
- Use when: adding structured data with multiple columns, foreign keys, or query requirements
- Pro: explicit schema; indexed queries; first-class entity with its own repository
- Con: requires schema migration; a new entity type to maintain

**Rule of thumb:** ≤ 3 simple scalar attributes on an existing entity → extension attributes.
Structured data, relational queries, or complex reporting → new table.

---

### Data Patch vs Setup Script

Always use **Data Patches** (`Setup/Patch/Data/` implementing `DataPatchInterface`). Never use
`Setup/InstallData.php` or `Setup/UpgradeData.php`. Data patches are idempotent by default (Magento
tracks applied patches) and composable via `getDependencies()`.

---

## Frontend

### Block vs ViewModel

**Block (legacy):**
- Available for backwards compatibility only. Do not create new Block classes unless required by
  an existing layout that cannot be changed.

**ViewModel:**
- Use for all new frontend logic.
- Pro: testable without Magento layout; clean separation from template; constructor injection
- Con: requires layout XML wiring (`arguments` node)
- Rule: no ResourceModel access in a ViewModel; inject a repository or service instead.

---

## How to Document Tradeoffs in the Report

For each tradeoff that applies to the feature, use this format:

```
### {Tradeoff Title}

Chosen: {option selected}

Why: {one to three sentences explaining the constraint or preference that drove the choice}

Alternative considered: {the other option and why it was not chosen}

Risk: {what could go wrong with the chosen option and how it is mitigated}
```
