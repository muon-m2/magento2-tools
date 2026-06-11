# Store Scope in Resolvers

Most catalog and customer data is store-scoped. A resolver that ignores store scope
returns wrong data on multi-store installs.

## Read Current Store

```php
$store = $context->getExtensionAttributes()->getStore();
$storeId = (int) $store->getId();
$storeCode = $store->getCode();
```

The `Store` HTTP header in the request resolves to this; defaults to the default store.

## Apply Store Filter

```php
$criteria = $this->searchCriteriaBuilder
    ->addFilter('store_id', $storeId, 'eq')
    ->create();
```

For EAV attributes that are store-scoped, Magento's EAV layer handles the lookup
automatically when you pass the store ID through the query.

## Multi-Store Aware Repository Methods

Magento's `ProductRepository`, `CategoryRepository`, etc. accept an optional `$storeId`:

```php
$product = $this->productRepository->getById($id, false, $storeId);
```

If you write a custom repository for GraphQL, mirror this signature.

## Currency

```php
$currency = $store->getCurrentCurrencyCode();
$baseCurrency = $store->getBaseCurrencyCode();
```

Prices in the response should be in the store's display currency unless the schema says
otherwise.

## Customer Group

```php
$groupId = (int) $context->getExtensionAttributes()->getCustomerGroupId();
```

Catalog rule prices and tier prices may vary by group. A resolver returning prices
without the group context returns the default group's prices for everyone.

## Common Mistake

Hardcoding `store_id = 0` to "match all stores" — that filter returns the default-scoped
row, NOT all stores. For "any store" semantics, omit the filter entirely.

## When Store Scope Doesn't Apply

- Customer profile fields (global)
- Admin-area queries (use admin store ID 0)
- Order data (uses the store the order was placed in, not the request's store)

## Per-Store Cache Key

If the resolver's output depends on store, the response cache must vary by store. For
GraphQL this happens through the `Magento_GraphQlCache` module: the cache identifier is
derived from request context (including the `Store` header), so store-scoped responses are
cached separately. Custom or non-store context that affects output may still need explicit
cache-tag/identity configuration on the resolver.
