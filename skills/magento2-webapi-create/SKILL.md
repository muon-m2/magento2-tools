---
name: magento2-webapi-create
description:
    Contract-first generator for Magento 2 REST / Web-API surfaces. Use when the user wants to
    expose an existing entity over REST — add an endpoint, service contract, repository, or
    custom action. Generates webapi.xml routes, Api/ service-contract + Api/Data DTO interfaces,
    a full repository implementation, di.xml preferences, acl.xml, and Web-API functional tests.
    Goes beyond magento2-module-create's webapi stubs by handling SearchCriteria, per-route auth
    scopes, exception-to-HTTP mapping, extension attributes, and optional custom-action endpoints.
    Assumes the entity model already exists (created by magento2-module-create).
---

# Magento 2 Web API Create

Contract-first REST / Web-API generation for an **existing** entity. Produces:
- `etc/webapi.xml` with CRUD routes (+ optional custom-action routes), each with an auth scope
- `Api/{Entity}RepositoryInterface` service contract (CRUD + any custom-action methods)
- `Api/Data/{Entity}Interface` + `Api/Data/{Entity}SearchResultsInterface` DTOs
- `Model/{Entity}Repository` full implementation (`SearchCriteria` via `CollectionProcessor`)
- `etc/di.xml` preferences and `etc/acl.xml` resources
- A Web-API functional test (`WebapiAbstract`) covering the GET/POST/PUT/DELETE round-trip

## Core Rules

- **Contract-first.** Decide the endpoint surface, DTO shape, and auth scope before writing the
  implementation. The `Api/` interface is the contract; everything else implements it.
- **Assumes the entity exists.** This skill operates on the model / resource-model / `db_schema`
  produced by `magento2-module-create`. If the entity model is absent, stop and run
  `magento2-module-create` first — do **not** scaffold persistence here.
- **Auth on every route.** Each route declares a `<resources>` scope. ACL-protected is the
  default; `self` for customer-scoped data; `anonymous` requires explicit justification (it
  exposes the route publicly).
- **Throw framework exceptions.** Map failures to the right framework exception so the Web API
  returns the correct HTTP status (`NoSuchEntityException` → 404, `CouldNotSaveException` → 400,
  `LocalizedException` → 400). See `references/error-handling.md`.
- **Append, don't replace.** When `etc/webapi.xml`, `di.xml`, or `acl.xml` already exist (e.g.
  module-create stubs), append/extend rather than overwrite. Report what is reused.
- **Literal `entity_id` PK.** The module-create entity uses the literal `entity_id` primary key;
  this skill matches it (not the token `{entity}_id` used by the adminhtml form/listing pairing).
- **Coding style.** Generated PHP follows PER-CS 3.0 as the baseline, with the Magento 2 coding
  standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the gate. See
  `magento2-context/references/php-coding-style.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (vendor, runner, Magento root, version). Then detect the target entity:
- Locate `Model/{Entity}`, `Model/ResourceModel/{Entity}`, and any existing `Api/Data/{Entity}Interface`.
- If the entity **model is absent**, stop: instruct the user to run `magento2-module-create` first.
- Detect existing `etc/webapi.xml`, `etc/di.xml`, `etc/acl.xml`, `etc/extension_attributes.xml`,
  and any partial `Api/` surface — these are **reused/extended**, not overwritten.

### Phase 1 — Contract Plan

Ask the user:
- Entity: the existing model being exposed.
- CRUD surface: confirm the five baseline routes (always generated):
  `GET :id` → `getById`, `GET` → `getList`, `POST` → `save`, `PUT :id` → `save`,
  `DELETE :id` → `deleteById`.
- Custom actions (optional): for each — name, HTTP method, URL, service method, auth scope.
  e.g. `POST /V1/{route}/:entityId/activate → activate(int $entityId): {Entity}Interface`.
- Auth scope per route: `anonymous` | `self` | ACL-protected (default). See `references/auth-scopes.md`.

Produce the route table. See `references/service-contracts.md`.

### Phase 2 — DTO & Repository Plan

For the DTO and repository, decide:
- **Data interface** fields (constants + typed getters/setters) and extension-attribute accessors.
  See `references/extension-attributes.md`.
- **Search-results interface** — narrowed `getItems()` returning `{Entity}Interface[]`.
- **Repository wiring** — resource model, collection factory, `CollectionProcessorInterface`,
  `SearchResultsFactory`, entity factory. See `references/search-criteria.md`.
- **Custom-action bodies** — delegate non-trivial logic to a domain service; never bury business
  logic in the repository.

Present the plan. Wait for approval.

### Phase 3 — Generate

- `Api/{Entity}RepositoryInterface.php` (CRUD + custom-action signatures).
- `Api/Data/{Entity}Interface.php`, `Api/Data/{Entity}SearchResultsInterface.php`.
- `Model/{Entity}Repository.php` (full implementation).
- `etc/webapi.xml` (routes + per-route `<resources>`), appended if the file exists.
- `etc/di.xml` — three preferences: `{Entity}Interface` → model, `{Entity}RepositoryInterface`
  → repository, `{Entity}SearchResultsInterface` → `Magento\Framework\Api\SearchResults`.
- `etc/acl.xml` — the resource tree the routes reference.
- `Test/Api/{Entity}RepositoryTest.php` (`WebapiAbstract` functional test).

### Phase 4 — Verify

- `php -l` on each generated `.php`; `xmllint --noout` on each generated XML.
- Run `magento2-module-review --diff` on the module. **Gate: zero Critical/High.**
- Where a running Magento is available, suggest `setup:di:compile` as a smoke check (not required).

### Phase 5 — Report

Brief Markdown:
- Endpoints added (method, URL, service method, auth scope).
- Custom actions added.
- DTO fields + extension-attribute decisions.
- Test coverage delta and the run command.
- `magento2-module-review` verdict.

## Inputs

```
/magento2-webapi-create [--module=<Vendor>_<Module>] [--entity=<Entity>] [--auth=anonymous|self|acl]
```

Interactive flow drives the rest.

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/webapi.xml                       # created or appended
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/di.xml                           # created or merged
{ctx.magento_root}/app/code/{Vendor}/{Module}/etc/acl.xml                          # created or merged
{ctx.magento_root}/app/code/{Vendor}/{Module}/Api/{Entity}RepositoryInterface.php  # new
{ctx.magento_root}/app/code/{Vendor}/{Module}/Api/Data/{Entity}Interface.php       # new
{ctx.magento_root}/app/code/{Vendor}/{Module}/Api/Data/{Entity}SearchResultsInterface.php  # new
{ctx.magento_root}/app/code/{Vendor}/{Module}/Model/{Entity}Repository.php         # new
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Api/{Entity}RepositoryTest.php  # new
```

## Reference Files

- `references/service-contracts.md` — repository pattern, `@api`, why interfaces live in `Api/`.
- `references/search-criteria.md` — `CollectionProcessor`, filter/sort/pagination, `SearchResultsFactory`.
- `references/auth-scopes.md` — anonymous / self / ACL scopes, integration tokens, when anonymous is OK.
- `references/error-handling.md` — exception → HTTP-status mapping; throw the right framework exception.
- `references/extension-attributes.md` — `extension_attributes.xml` and the generated extension interface.
- `references/webapi-testing.md` — `WebapiAbstract`, REST vs SOAP adapters, asserting status codes.

## Templates

- `templates/service-contract-interface.php`
- `templates/data-interface.php`
- `templates/search-results-interface.php`
- `templates/repository.php`
- `templates/webapi.xml`
- `templates/di.xml`
- `templates/acl.xml`
- `templates/test-webapi-functional.php`

## Acceptance Criteria

- `webapi.xml` routes resolve to real service-contract methods; each route has a `<resources>` scope.
- The service contract is an `@api` interface under `Api/`; the DTO under `Api/Data/`.
- `getList` processes `SearchCriteria` through `CollectionProcessorInterface` (filters/sort/pagination).
- Failures throw the framework exception that maps to the correct HTTP status.
- Anonymous routes carry an explicit justification.
- The generated repository has at least one functional test (GET/POST/PUT/DELETE round-trip).

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (prerequisite) | `magento2-module-create` (entity + persistence) |
| (after Phase 3) | `magento2-module-review --diff` |
| (after Phase 3) | `magento2-test-generate --types=api` |
| (caller) | `magento2-feature-implement` Phase 5 (A* / API tasks) |
| (sibling) | `magento2-graphql-create` (GraphQL surface for the same entity) |
