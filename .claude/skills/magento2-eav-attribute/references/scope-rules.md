# Scope Rules

EAV attributes have scope: global, website, or store. The chosen scope determines where
the attribute's value lives in the schema.

## Scope Values

| Scope code | Constant | Storage |
|-----------|----------|---------|
| `global` (1) | `ScopedAttributeInterface::SCOPE_GLOBAL` | Single value across all stores |
| `website` (2) | `ScopedAttributeInterface::SCOPE_WEBSITE` | Per-website value |
| `store` (0) | `ScopedAttributeInterface::SCOPE_STORE` | Per-store-view value |

## Per-Entity Defaults

| Entity | Default scope | Allowed scopes |
|--------|--------------|----------------|
| Product | `store` | global, website, store |
| Customer | `global` | global only |
| Customer Address | `global` | global only |
| Category | `store` | global, store |

## Choosing the Right Scope

| Use case | Scope |
|----------|-------|
| Internal product flag (SKU normalization, vendor ID) | global |
| Pricing or tax data that varies by region | website |
| Customer-facing label (product name, description) | store |
| Customer profile (date of birth, gender) | global |
| Multi-language product fields | store |

## Schema Impact

- `global`: value stored once in `catalog_product_entity_{type}` with `store_id = 0`.
- `website`: value stored per website ID, plus a default row for `store_id = 0`.
- `store`: value stored per store view ID, falling back to default.

Magento's EAV layer handles the fallback automatically: when querying for store ID 1, if
no row exists for that store, the default row is returned.

## API Behaviour

REST and GraphQL queries that don't specify a `Store` header return the store's resolved
value. The `default` store returns the `store_id = 0` row.

## Common Mistake

Setting `is_global` to `0` (store-scoped) when the data should be global causes:
- Inconsistent values across stores
- Cache mishit
- Confused admin users editing "the same" attribute on different stores

When in doubt, default to **store** for catalog/display data and **global** for
operational data.

## Changing Scope Post-Install

Changing an attribute's scope after data exists is risky:
- `global → store`: existing global row becomes the store-0 default; per-store rows are
  empty.
- `store → global`: keeps the store-0 default; per-store rows become orphaned.

If a scope change is needed, do it in a separate `Setup/Patch/Data` patch with explicit
data migration logic; don't just change the attribute config.
