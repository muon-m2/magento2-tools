# Schema Migration

Strategy for evolving a GraphQL schema without breaking clients.

## Non-Breaking Changes (Safe)

- Adding a new query, mutation, or type
- Adding a new optional argument to an existing operation
- Adding a new field to an existing type (existing queries continue to work without
  requesting the new field)
- Adding a new enum value (clients that don't recognize it get an error if they request
  it; clients that don't request it are unaffected)
- Adding a new union member

## Breaking Changes (Require BC Process)

- Removing a query, mutation, type, field, or enum value
- Renaming any of the above
- Changing a field's type
- Changing an optional argument to required
- Changing a list field to non-list (or vice versa)
- Removing a `@resolver` directive

## BC Process

For each breaking change:

1. **Deprecate first**:
   ```graphql
   field: String @deprecated(reason: "use newField instead — removed in 2.0")
   ```
2. **Wait** at least one minor version.
3. **Remove** in a major-version bump.

Magento's GraphQL framework respects `@deprecated`: clients querying the deprecated
field still get data; introspection shows the deprecation reason.

## UPGRADE.md

Every breaking change goes in `{ctx.magento_root}/app/code/{Vendor}/{Module}/UPGRADE.md` per the
`magento2-module-upgrade` BC-break-notification format.

## Schema Merge Conflict

If two modules add the same field to the same type:

```graphql
# Module A
type Customer { custom_field: String }
# Module B
type Customer { custom_field: Int }
```

The last-loaded module wins, but Magento's schema compiler emits a warning. Resolve by
renaming one of the fields.

## Adding to Magento Core Types

You may extend `Customer`, `Product`, `Cart`, etc. from your module:

```graphql
type Customer {
    {vendor_lower}_loyalty_points: Int @resolver(class: "\\{Vendor}\\Loyalty\\Model\\Resolver\\Points")
}
```

This is safe and the recommended pattern. Use a vendor prefix to avoid colliding with
other modules.

## Versioning Resolvers

If a resolver's behaviour changes (e.g. tax calculation method), and old clients depend
on the old behaviour:

1. Create a new field with the new behaviour: `total_v2: Float`.
2. Mark the old field deprecated.
3. Migrate clients.
4. Remove the old field after one minor version.

## Schema Introspection

In dev mode, clients can query `__schema` to discover types. Disable introspection in
production for security:

```php
// In a custom GraphQL middleware
// Reject queries containing __schema or __type when in production mode.
```

Magento doesn't disable introspection by default — consider adding a plugin to do so for
public deployments.

## Testing Schema Compatibility

Magento ships a schema diff tool (when available):

```
{ctx.magento_cli} dev:graphql:schema-diff before.graphqls after.graphqls
```

Run before any release to catch unintended breaking changes.
