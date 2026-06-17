---
name: magento2-performance-audit
description:
    Performance audit of Magento 2 modules or the overall site. Use when the user reports
    slowness, wants a pre-launch performance check, suspects N+1 queries, or wants to
    review caching/indexer/queue behaviour. Produces severity-ranked findings in Markdown,
    JSON, and SARIF. Combines static analysis with optional runtime checks; never assumes
    a running Magento instance. Produces actionable, severity-ranked findings — vs the lighter
    read-only slow-query inspection in magento2-debug.
---

# Magento 2 Performance Audit

Static analysis (N+1 patterns, missing cache identities, expensive plugins) with optional
runtime inspection (indexer status, cache hit rates, slow queries, queue backlog).

## Core Rules

- **Static-first.** Default pass uses only the source tree — no runtime, no Magento CLI
  required.
- **Runtime is opt-in.** Phase 3 runs only when the user passes `--runtime`.
- **Severity by impact at scale.** A 50ms ViewModel call in a non-storefront context is
  Low; an N+1 query in checkout is High.
- **Concrete recommendation.** Every finding includes the specific replacement pattern,
  not "improve performance."
- **JSON + SARIF.** Same shape as `magento2-module-review`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Note presence of Magento CLI, Redis CLI, DB CLI, Blackfire.

### Phase 1 — Scope

- Single module → static analysis only by default; runtime opt-in.
- Multiple modules → static analysis across all; runtime opt-in.
- Site-wide → static across all custom modules + runtime checks.

### Phase 2 — Static Pass

Per `references/perf-checklist.md`:

| Check | Pattern |
|-------|---------|
| N+1 in foreach | Repository / Factory call inside loop body |
| Full-collection load | `getCollection()` without `addFieldToFilter` / `setPageSize` |
| Expensive constructor work | DB / HTTP / external call in `__construct` |
| Missing cache identity | Block subclass without `getIdentities()` |
| Missing cache lifetime | Block subclass without `getCacheLifetime()` |
| `around` plugin on hot path | Catalog / Quote / Order method intercepted |
| Synchronous external HTTP in storefront | Curl / Client in Block, ViewModel, Resolver |
| Cron job without batch | `foreach ($collection as $item)` in cron with no `setPageSize` |
| Queue consumer without batch | Single-message processing pattern |
| Plugin without `sortOrder` | Order-sensitive plugin chain |

Run via `${CLAUDE_SKILL_DIR}/scripts/static-perf.sh <module-path>`.

### Phase 3 — Runtime Pass (Opt-in)

Only if user authorizes AND Magento CLI is present:

| Check | Command |
|-------|---------|
| Indexer status | `{magento_cli} indexer:status` |
| Indexer mode | `{magento_cli} indexer:show-mode` |
| Pending cron | DB query on `cron_schedule` |
| Queue backlog | `{magento_cli} queue:consumers:list` + RabbitMQ stats |
| Cache type status | `{magento_cli} cache:status` |
| Slow queries | MySQL slow log (path configurable in CLAUDE.md) |
| Redis hit rate | `redis-cli INFO stats` |
| Varnish status | Curl headers |

Run via `${CLAUDE_SKILL_DIR}/scripts/runtime-checks.sh`.

### Phase 4 — Optional: Blackfire / Tideways Integration

If `BLACKFIRE_*` env vars or `~/.blackfire.ini` present:
- Prompt user to run a profiled URL.
- Parse Blackfire profile JSON.
- Surface top 10 hotspots with file:line references.

### Phase 5 — Report

Two automation artifacts and one LLM deliverable:

1. **JSON + SARIF** (automated). `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` aggregates `static-perf.sh`
   (always) and `runtime-checks.sh` (when `INCLUDE_RUNTIME=1`), invokes the shared
   emitter with `OUTPUT_KIND=performance`, and writes both `.json` and `.sarif`.
2. **Markdown summary** (LLM deliverable, NOT automated). Written by the skill in the
   conversation, ranked by impact, with concrete recommendations. Sample:

   ```markdown
   ### High — Catalog\Block\Category::getProducts() N+1 on store frontend

   Impact: Each category page render triggers 1+N queries (N = product count).
   Evidence: src/app/code/Acme/Catalog/Block/Category.php:47
   Recommendation: Use addAttributeToSelect(['name','price']) before iteration; or use
   the CollectionProcessor pattern.
   Verification: Re-render the page with debug toolbar; query count should drop from
   1+N to 1.
   ```

Builder invocation (for reference; callers normally just run the skill):

```bash
TARGET_MODULE=<Vendor_Module|site> TARGET_PATH=<path> SCOPE=module \
SCAN_ROOT={ctx.magento_root}/app/code INCLUDE_RUNTIME=0 \
bash ${CLAUDE_SKILL_DIR}/scripts/build-findings.sh
```

## Inputs

```
/magento2-performance-audit [--runtime] [--scope=module|site] [<Vendor>_<Module>...]
```

Flags:
- `--runtime` — opt in to runtime checks (Phase 3, 4)
- `--scope=site` — audit all custom modules + runtime
- `--format=markdown|json|sarif` — output format

## Outputs

```
.docs/audits/perf-{scope}-{date}.json    # automation artifact (build-findings.sh)
.docs/audits/perf-{scope}-{date}.sarif   # automation artifact (build-findings.sh)
.docs/audits/perf-{scope}-{date}.md      # LLM deliverable, written in Phase 5
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under `{ctx.magento_root}`,
`app/code`, or a module dir. See the **Artifact location** rule in `magento2-context/SKILL.md`.

## Reference Files

- `references/perf-checklist.md` — full static-check catalogue.
- `references/n-plus-one-patterns.md` — known N+1 patterns + remediation.
- `references/caching-rules.md` — identity, lifetime, tag rules.
- `references/indexer-health.md` — indexer mode interpretation.
- `references/queue-health.md` — backlog thresholds, dead-letter handling.
- `references/blackfire-integration.md` — Blackfire profile parsing.
- `references/severity-perf.md` — severity calibration anchored to shared scale.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/static-perf.sh` — static pattern scan over module sources.
- `${CLAUDE_SKILL_DIR}/scripts/runtime-checks.sh` — bin/magento + redis-cli + mysql probes.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — aggregate scanner output; emit JSON + SARIF via the
  shared emitters. Structurally identical to `magento2-security-audit/scripts/build-findings.sh`.

## Severity

Uses shared scale. Calibration anchors:

| Severity | Example |
|----------|---------|
| Critical | Storefront critical path loads full product collection (memory exhaustion at scale) |
| High | N+1 in checkout totals; missing cache identity on category Block (FPC bypass) |
| Medium | N+1 in admin grid; non-batched cron iterating > 1000 records |
| Low | Plugin without explicit sortOrder; ViewModel with light DI |
| Info | Indexer in update-on-save mode (acceptable but unusual for production) |

## Acceptance Criteria

- Runs without Magento CLI; produces static report only.
- Runtime checks gracefully degrade when tools are missing.
- Top-10 findings are actionable with `file:line` + recommendation.
- JSON output usable in CI for trend detection.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (none for findings — output is the deliverable) | |
