# Caching Rules

## Block-Level FPC

Every Block that renders cacheable content must declare:

| Method | Returns |
|--------|---------|
| `getIdentities()` | Array of cache tags this block depends on |
| `getCacheKeyInfo()` | Array of key parts that uniquely identify the rendered output |
| `getCacheLifetime()` | Lifetime in seconds (default: 86400; `null` for forever) |

### Identities

```php
public function getIdentities(): array
{
    return [
        Product::CACHE_TAG . '_' . $product->getId(),
        Category::CACHE_TAG . '_' . $this->getCategoryId(),
    ];
}
```

When any tag is invalidated (e.g. product save), the FPC entry is purged.

### Cache Key Info

```php
public function getCacheKeyInfo(): array
{
    return array_merge(
        parent::getCacheKeyInfo(),
        [
            'store' => $this->_storeManager->getStore()->getId(),
            'customer_group' => $this->customerSession->getCustomerGroupId(),
            'currency' => $this->_storeManager->getStore()->getCurrentCurrencyCode(),
        ]
    );
}
```

Missing key parts → cached entry is wrong for some users (e.g. wrong currency).

### Lifetime

| Block type | Recommended lifetime |
|------------|---------------------|
| Catalog product page | 7200 (2 hours) |
| Static content (CMS) | 86400 (1 day) |
| User-specific cart/wishlist | 0 (never cache server-side; cache fragment via private content) |

## Private Content (Customer-Specific)

For per-customer fragments inside a cached page, use **Magento_PageCache** sections:

```xml
<!-- view/frontend/sections.xml -->
<config>
    <action name="customer/account/createPost">
        <section name="customer" />
    </action>
</config>
```

The JS layer fetches private sections via `/customer/section/load` after the page is
served — keeping the page itself cacheable.

## Layered Cache Hierarchy

```
Varnish → Magento FPC → ORM cache → DB
```

Each layer has a different invalidation domain. A finding mentions which layer is
mishit:

- "FPC bypass" — `setNoCache()` is called or `getCacheLifetime()` returns 0
- "FPC stale" — `getIdentities()` is missing tags
- "Varnish bypass" — `Cache-Control: no-store` header set explicitly

## Common Mistakes

| Mistake | Symptom | Severity |
|---------|---------|---------|
| `getCacheKeyInfo()` doesn't include store/currency | Wrong rendered output for some users | High |
| `setData('cache_lifetime', 0)` | FPC never caches this block | Medium |
| Block calling `setNoCache()` unconditionally | FPC bypass | High |
| Missing tag on category change | Stale category listing | High |

## Tag Audit Pattern

```bash
grep -rE 'getIdentities|CACHE_TAG' {ctx.magento_root}/app/code/{Vendor}/{Module}/Block
```

Cross-reference with Magento core tags from `vendor/magento/module-*/Model/*::CACHE_TAG`.
