# Schema Patterns

Magento 2 GraphQL schema is declared in `etc/schema.graphqls` per module. The schema
declarations are merged across all modules at runtime.

## Query

```graphql
type Query {
    {operationName}(id: ID!): {ReturnType} @resolver(class: "\\{Vendor}\\{Module}\\Model\\Resolver\\{Name}") @doc(description: "Fetch a single {Entity} by ID")
}
```

## Mutation

```graphql
type Mutation {
    {operationName}(input: {InputType}!): {OutputType}! @resolver(class: "\\{Vendor}\\{Module}\\Model\\Resolver\\{Name}")
}
```

## Type Definition

```graphql
type {EntityName} {
    id: ID!
    name: String!
    status: {StatusEnum}!
    createdAt: String!
}
```

## Enum

```graphql
enum {StatusEnum} {
    PENDING
    APPROVED
    REJECTED
}
```

## Input Type

```graphql
input {InputName} {
    name: String!
    status: {StatusEnum}!
    metadata: String
}
```

## Interface

For shared fields across types:

```graphql
interface {InterfaceName} {
    id: ID!
    name: String!
}

type {Type1} implements {InterfaceName} {
    id: ID!
    name: String!
    extraField: String
}
```

## Union

For polymorphic results:

```graphql
union {UnionName} = {Type1} | {Type2}
```

Union resolvers must implement `TypeResolverInterface` to discriminate.

## Paginated List

Magento convention for pagination:

```graphql
type {EntityListing} {
    items: [{EntityName}]!
    page_info: SearchResultPageInfo!
    total_count: Int!
}

type Query {
    {entities}(filter: {FilterInput}, currentPage: Int = 1, pageSize: Int = 20): {EntityListing} @resolver(class: "...")
}
```

`SearchResultPageInfo` is provided by Magento core (`Magento\Search\Model\GraphQl\Type\Output\SearchResultPageInfo`).

## @resolver Directive

Always FQCN, double-backslashed:

```graphql
@resolver(class: "\\Magento\\Catalog\\Model\\Resolver\\Product")
```

## @doc Directive

For documentation visible in introspection:

```graphql
{operationName}(...) @doc(description: "Short description in plain English")
```

## Schema Compose / Merge

When multiple modules add to the same type:

```graphql
# Module A
type Customer {
    fieldA: String
}

# Module B
type Customer {
    fieldB: String
}
```

Magento merges them at runtime into a single `Customer` with both fields. No special
syntax needed.

## Versioning

Magento GraphQL has no formal versioning. Non-breaking changes (adding fields, adding
optional inputs) are always safe. Breaking changes (removing fields, changing required
inputs) require:
- Document in `UPGRADE.md`
- Mark deprecated fields with `@deprecated(reason: "use X instead")`
- Wait at least one minor version before removing

## Common Mistakes

- Single-backslash FQCN in `@resolver` — fails to load.
- Missing `!` on required fields — clients get `null` for unset values.
- Mutation without `@resolver` — Magento can't find the handler.
- Forgetting `pageSize` cap — clients can DoS by requesting huge pages.
