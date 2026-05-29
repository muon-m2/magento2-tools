# Performance Severity Calibration

Anchored to the shared scale (`magento2-context/references/severity.md`).

## By Impact at Scale

| Severity | Description | Examples |
|----------|-------------|----------|
| Critical | Will OOM / time-out in production with realistic data | Full product collection load on storefront; cron iterating > 100K rows in memory |
| High | 1+N queries on a high-traffic path; cache miss on critical content | Checkout total recalculation N+1; missing identity on category Block |
| Medium | 1+N on lower-traffic path; non-batched queue consumer | Admin grid N+1; queue consumer processing one msg at a time |
| Low | Plugin without sortOrder; ViewModel with light DI; unused index hint | Cosmetic / optional optimisations |
| Info | Acceptable behaviour worth noting | Indexer in update-on-save mode (acceptable but unusual) |

## Storefront vs Admin Bias

The same N+1 pattern is High in storefront and Medium in admin — storefront traffic is
N orders of magnitude higher, so the same per-request cost has different aggregate cost.

## Profile-Backed Findings

Findings derived from a Blackfire profile get a `profileUrl` field. Severity is set by
the % of request time consumed:

| % of request | Severity |
|--------------|---------|
| > 30% | Critical |
| 15–30% | High |
| 5–15% | Medium |
| < 5% | Low |

## False-Positive Bias

Static N+1 detection is noisy. When the loop body has obvious early-exit logic
(`if (already cached) continue;`), bump severity DOWN one step. The auditor's
recommendation should note "If the early-exit covers most iterations, this may be a
false positive — verify with profiling."

## Cumulative Severity

A single Critical finding outranks 10 Medium findings. Report sorts by:
1. Critical first
2. High next
3. Within a severity: by `category` then alphabetically by `title`

## Anchors From Practice

| Real-world finding | Severity |
|---------------------|---------|
| Cart drawer ViewModel fetching customer tier prices per item | Critical (drops to High if cached) |
| Catalog category description rendered with full CMS block stack | High |
| Admin order grid querying per-row payment method label | Medium |
| Cron exporting all orders without setPageSize | High (OOM at scale) |
| Custom indexer rebuilding from scratch on every change | High |
| GraphQL category resolver without batch | High |
| `setNoCache()` in PageBuilder header block | High |
| 50ms unused regex in helper called once per request | Low |
