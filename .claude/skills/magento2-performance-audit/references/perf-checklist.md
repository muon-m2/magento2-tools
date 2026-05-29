# Performance Checklist

Static-pattern catalogue for Phase 2.

## N+1 Queries (`n_plus_one`)

| Pattern | Detection | Severity |
|---------|-----------|---------|
| Repository call inside `foreach` | grep `foreach.*\{[^}]*Repository->get` | High (storefront) / Medium (admin) |
| Factory create + load inside loop | grep `Factory->create.*->load` inside loop | High |
| Per-product attribute load | `getResource()->getAttribute(...)` inside iteration | High |

## Collection Loading (`cache`)

| Pattern | Detection |
|---------|-----------|
| `getCollection()` without filters | Bare `getCollection()->getItems()` |
| Collection without `setPageSize` | Iteration over a collection with no page bounds |
| Full attribute select | `addAttributeToSelect('*')` |

## Constructor Work (`constructor-work`)

| Pattern | Detection |
|---------|-----------|
| DB call in `__construct` | `$resource->getConnection()->fetch*` in constructor body |
| HTTP call in `__construct` | `Curl::post`, `Client::request` in constructor |
| File system scan in `__construct` | `scandir`, `glob` in constructor |
| Logger writes in `__construct` | `$logger->log*` in constructor (acceptable rarely; flag for review) |

## Cache Identity / Lifetime (`cache-identity`, `cache-lifetime`)

| Pattern | Detection |
|---------|-----------|
| Block without `getIdentities` | Class extending `AbstractBlock` without `getIdentities()` override |
| Block returning empty identities | `getIdentities()` returns `[]` |
| Block without `getCacheLifetime` | Heavy block (10+ DB calls) without explicit lifetime |
| FPC bypass | `setNoCache()` call in storefront block |

## Plugin Hot Path (`plugin-hotpath`)

| Pattern | Detection |
|---------|-----------|
| `around` plugin on `Catalog\Model\Product::load` | grep di.xml |
| `around` plugin on `Quote\Model\Quote::collectTotals` | grep di.xml |
| `before` plugin on `Catalog\Block\Category\View::_prepareLayout` | grep di.xml |
| Plugin without `sortOrder` on a method with > 1 plugin | DI graph walk |

## Storefront HTTP (`storefront-http`)

| Pattern | Detection |
|---------|-----------|
| Curl/Client in Block | grep `extends.*Block.*Curl|HTTP` |
| Curl in ViewModel | grep ViewModel constructor for HTTP client |
| Curl in GraphQL resolver | grep resolver `resolve()` body |

## Cron / Queue Batching (`cron-batch`)

| Pattern | Detection |
|---------|-----------|
| Cron without setPageSize | Cron `execute()` iterating a collection without `setPageSize` |
| Queue consumer single-message | Consumer `process()` taking one message at a time when batching is feasible |

## Other (`other`)

| Pattern | Detection |
|---------|-----------|
| Heavy GraphQL resolver without batch | Resolver not implementing `BatchResolverInterface` for list contexts |
| `usort` in render loop | `usort` called inside `getList`/`getProducts` |
| Image processing in render path | `imagecreatefrom*` in Block / ViewModel |
| Synchronous email send in storefront | `transportBuilder->getTransport()->sendMessage()` in storefront flow |

## False-Positive Suppression

A finding can be suppressed with an inline comment:

```php
// @perf-audit-ignore reason="Acceptable because it runs once per request"
```

The skill scans for the comment and skips. Require the `reason="..."` text.

## Building the Finding

```json
{
  "id": "perf-audit-2026-05-24-001",
  "severity": "high",
  "category": "n_plus_one",
  "title": "Repository->get called inside foreach (1+N queries)",
  "evidence": [
    { "file": "Block/Category.php", "line": 47, "snippet": "$product = $this->repo->get($id);" }
  ],
  "recommendation": "Pre-fetch products via $this->repo->getList(addFieldToFilter('entity_id', ['in' => $ids])) before the loop.",
  "verification": "Re-render the page; query count should drop from 1+N to 1. Use Magento's debug toolbar or query log."
}
```
