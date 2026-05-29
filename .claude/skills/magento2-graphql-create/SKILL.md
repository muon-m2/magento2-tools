---
name: magento2-graphql-create
description:
    Schema-first generator for Magento 2 GraphQL surfaces. Use when the user wants to
    add a GraphQL query, mutation, type, or batch loader. Generates schema.graphqls,
    resolvers, batch resolvers, auth checks, and tests. Goes beyond magento2-module-create's
    graphql surface by handling batch loading patterns, auth/store-scope correctly, and
    schema migration.
---

# Magento 2 GraphQL Create

Schema-first GraphQL generation. Produces:
- `etc/schema.graphqls` with query/mutation/type definitions
- Resolver classes implementing `ResolverInterface`
- Batch loaders implementing `BatchResolverInterface` (to avoid N+1)
- Auth and store-scope checks
- Per-resolver unit tests via `magento2-test-generate`

## Core Rules

- **Schema-first.** Decide the schema before writing resolvers.
- **Batch over standard for list contexts.** Any resolver returning data per element of a
  parent list MUST use `BatchResolverInterface`. Standard resolvers in a list cause N+1.
- **Auth check on every mutation.** Anonymous mutations require explicit justification.
- **Store-scope aware.** Resolvers querying store-scoped data must respect the `Store`
  header via `ContextInterface`.
- **Append, don't replace.** When `etc/schema.graphqls` exists, append new types/fields
  rather than rewriting.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`.

### Phase 1 — Schema Plan

Ask the user:
- Operation: query | mutation
- Entity: what is being queried/mutated
- Return shape: single | list | paginated
- Auth: customer | admin | anonymous (with justification)
- Store scope: single | store-aware | global
- Inputs: which fields the operation accepts
- Backing service: existing service contract, or new

Produce the schema fragment. See `references/schema-patterns.md`.

### Phase 2 — Resolver Plan

For each operation, decide:
- **Standard resolver** — one entity at a time. Use when called once per request.
- **Batch resolver** — collects N IDs, returns N results. Use in list contexts to avoid
  N+1 (e.g. `products.reviews { ... }` returning reviews per product).
- **Paginated resolver** — `getList` with `SearchCriteria` + `currentPage`/`pageSize`.

Present the plan. Wait for approval.

### Phase 3 — Generate

- Append schema to existing `etc/schema.graphqls` (create file if absent).
- Generate resolver class(es) under `Model/Resolver/`.
- For batch: generate `BatchResolverInterface` implementation under `Model/Resolver/Batch/`.
- Wire DI in area-specific `etc/graphql/di.xml`.
- Generate `Test/Unit/Model/Resolver/{Name}Test.php` via `magento2-test-generate`.

### Phase 4 — Verify

- `xmllint --noout` on `etc/graphql/di.xml`.
- `php -l` on each resolver.
- Schema validity: parse via Magento's schema parser if CLI is available.

### Phase 5 — Report

Brief Markdown:
- Operations added
- Resolvers added (standard / batch / paginated)
- Auth/scope decisions
- Test coverage delta

## Inputs

```
/magento2-graphql-create [--module=<Vendor>_<Module>] [--operation=query|mutation] [--auth=customer|admin|anonymous]
```

Interactive flow drives the rest.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/schema.graphqls          # appended or created
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/graphql/di.xml           # created or merged
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/Resolver/...           # new files
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/Resolver/...       # new tests
```

## Reference Files

- `references/schema-patterns.md` — query, mutation, input, interface, union patterns.
- `references/resolver-patterns.md` — standard + batch + paginated resolver patterns.
- `references/auth-patterns.md` — @doc(category="store"), auth-check helpers.
- `references/store-scope.md` — per-store handling in resolvers.
- `references/schema-migration.md` — non-breaking vs breaking schema changes.
- `references/n-plus-one-prevention.md` — when to use batch resolver vs eager-load.

## Templates

- `templates/query-resolver.php`
- `templates/mutation-resolver.php`
- `templates/batch-resolver.php`
- `templates/paginated-resolver.php`
- `templates/schema-fragment.graphqls`

## Acceptance Criteria

- Schema parses (when Magento CLI is available).
- Resolvers implement the correct interface.
- Mutations include auth check; anonymous mutations require explicit justification.
- Batch resolvers process N inputs in O(1) DB roundtrips.
- Generated resolvers have at least one unit test (happy + auth-fail + input-error).

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (after Phase 3) | `magento2-module-review --diff` |
| (after Phase 3) | `magento2-test-generate --types=unit` |
| (caller) | `magento2-feature-implement` Phase 5 (G* tasks) |
