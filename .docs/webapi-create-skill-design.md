# magento2-webapi-create — Skill Design

**Status:** Approved scope (CRUD + optional custom actions). Working artifact — not shipped.
**Date:** 2026-06-17
**Type:** New skill (the 20th), dedicated REST / Web API generator. Sibling to `magento2-graphql-create`.

---

## 1. Purpose & boundary

A dedicated REST / Web-API generator. Where `magento2-module-create` emits minimal webapi
*stubs* (a bare `webapi.xml` plus skeletal `Api/` interfaces), this skill owns the **full
service-contract surface** for an entity and gets the hard parts right:

- `SearchCriteria` handling on `getList` (filters / sort / pagination via `CollectionProcessor`).
- Auth scopes per route (anonymous / self / ACL-protected).
- Exception → HTTP-status mapping (`NoSuchEntity` → 404, `CouldNotSave` → 400, etc.).
- Extension attributes wiring.
- Web-API **functional** tests (`WebapiAbstract`) plus a repository **integration** test.
- **Optional custom-action endpoints** beyond CRUD (e.g. `POST /V1/{route}/:id/activate`),
  wired to bespoke service-contract methods.

**Boundary (mirrors `graphql-create`):** the skill **assumes the entity model, resource model,
and `db_schema` already exist** (produced by `magento2-module-create`). It generates only the
API / service-contract layer. Phase 0 detects a missing model and points the user back to
`magento2-module-create` rather than scaffolding persistence itself.

**PK convention:** operates on the `module-create` entity, which uses the literal `entity_id`
primary key (see `module-create/templates/dto-interface.php`, `api-interface.php`,
`resource-model.php`). This skill therefore uses **literal `entity_id`** — *not* the token-based
`{entity}_id` used by the adminhtml form/listing pairing. webapi-create is downstream of
module-create (same as graphql-create), so it inherits module-create's PK.

## 2. Relationship to existing skills

| Skill | Relationship |
|-------|--------------|
| `magento2-module-create` | Upstream. Produces the entity + persistence + **stub** webapi files this skill supersedes. webapi-create reuses/upgrades its `webapi.xml`, `api-interface.php`, `dto-interface.php`, `search-results-interface.php`, `repository.php` templates. |
| `magento2-graphql-create` | **Structural sibling** — same Phase 0–5 shape, same `references/` + `templates/` layout, same dependency edges. The model to mirror. |
| `magento2-module-review` | Phase 4 verification gate (zero Critical/High). |
| `magento2-test-generate` | Delegated to for richer test scaffolds; webapi-create ships its own functional-test template. |
| `magento2-context` | Phase 0 environment + entity detection. |

**Dependency graph edge (identical to graphql-create):**
`magento2-webapi-create ──► context, module-create, module-review, test-generate`

## 3. Phased workflow (mirrors graphql-create Phase 0–5)

### Phase 0 — Context Resolution
- Delegate to `magento2-context` (vendor, runner, Magento root, version).
- Detect the target entity: model + resource model + `Api/Data/{Entity}Interface` (if present).
  - If the entity model is **absent**, stop and instruct: run `magento2-module-create` first.
  - If a partial API surface exists (e.g. module-create stubs), detect and **extend** it rather
    than overwrite — report what is reused.
- Detect existing `extension_attributes.xml`, `acl.xml`, `di.xml`, `webapi.xml`.

### Phase 1 — Contract Plan
- Enumerate endpoints. CRUD baseline (always):
  - `GET    /V1/{route}/:entityId`  → `getById`
  - `GET    /V1/{route}`            → `getList` (SearchCriteria)
  - `POST   /V1/{route}`            → `save`
  - `PUT    /V1/{route}/:entityId`  → `save`
  - `DELETE /V1/{route}/:entityId`  → `deleteById`
- Optional custom actions (opt-in per run): name, HTTP method, URL, service method, auth scope.
  e.g. `POST /V1/{route}/:entityId/activate → activate(int $entityId): {Entity}Interface`.
- Per-route auth scope decision (see §5).

### Phase 2 — DTO & Repository Plan
- Data interface fields (constants + typed getters/setters), extension-attribute accessors.
- Search-results interface (narrowed `getItems()`).
- Repository impl wiring: resource model, collection factory, `CollectionProcessorInterface`,
  `SearchResultsFactory`, entity factory. Custom-action method bodies (delegate to a domain
  service where the action is non-trivial; never bury business logic in the repository).

### Phase 3 — Generate
Write from templates (tokens resolved):
- `Api/{Entity}RepositoryInterface.php` (CRUD + any custom-action method signatures).
- `Api/Data/{Entity}Interface.php`, `Api/Data/{Entity}SearchResultsInterface.php`.
- `Model/{Entity}Repository.php` (full impl).
- `etc/webapi.xml` (routes + per-route `<resources>`).
- `etc/di.xml` (three preferences: `{Entity}Interface`→model, `{Entity}RepositoryInterface`→repo,
  `{Entity}SearchResultsInterface`→`Magento\Framework\Api\SearchResults`).
- `etc/acl.xml` (resource tree the routes reference).
- `Test/Api/{Entity}RepositoryTest.php` (`WebapiAbstract` functional test).

### Phase 4 — Verify
- `php -l` every generated `.php`; `xmllint --noout` every generated XML.
- Run `magento2-module-review` on the module. **Gate: zero Critical/High.**
- Where a running Magento is available, suggest `setup:di:compile` as a smoke check (not required).

### Phase 5 — Report
- Files created/modified, endpoints + auth scopes table, custom actions, test command, and the
  review verdict. Approval gate before any write (consistent with other code-writing skills).

## 4. Templates (skill `templates/`)

| Template | Built on | Notes |
|----------|----------|-------|
| `service-contract-interface.php` | module-create `api-interface.php` | + custom-action signatures placeholder block. |
| `data-interface.php` | module-create `dto-interface.php` | reused as-is (constants, getters/setters, extension attrs). |
| `search-results-interface.php` | module-create `search-results-interface.php` | reused as-is. |
| `repository.php` | module-create `repository.php` | full impl: `save`/`getById`/`getList`-via-`CollectionProcessor`/`delete`/`deleteById` + custom-action stub. |
| `webapi.xml` | module-create `webapi.xml` | per-route auth + optional custom-action route block. |
| `di.xml` | new | the three preferences + `CollectionProcessor` virtual-type wiring note. |
| `acl.xml` | new | `view` / `manage` resource tree the routes reference. |
| `test-webapi-functional.php` | new | `Magento\TestFramework\TestCase\WebapiAbstract`; covers GET/POST/PUT/DELETE round-trip. |

## 5. Auth scopes (`references/auth-scopes.md`)

Three modes, chosen per route in Phase 1:
- **Anonymous** — `<resources><resource ref="anonymous"/></resources>`. Public read endpoints only;
  the skill warns and requires explicit confirmation (security-sensitive).
- **Self** — `<resource ref="self"/>` for customer-scoped data (`:id` resolved from the token).
- **ACL-protected** (default) — `<resource ref="{Vendor}_{ModuleName}::view"/>` (reads) /
  `::manage` (writes), backed by `acl.xml`. The default for admin/integration token access.

## 6. References (skill `references/`)

- `service-contracts.md` — repository pattern, `@api`, DTO conventions, why interfaces live in `Api/`.
- `search-criteria.md` — `CollectionProcessor`, filter/sort/pagination, `SearchResultsFactory`.
- `auth-scopes.md` — the three scopes (§5), integration tokens, when anonymous is acceptable.
- `error-handling.md` — exception → HTTP-status mapping table; throw the right framework exception.
- `extension-attributes.md` — `extension_attributes.xml`, the generated `{Entity}ExtensionInterface`.
- `webapi-testing.md` — `WebapiAbstract`, REST vs SOAP adapters, fixtures, asserting status codes.

## 7. SKILL.md frontmatter

`name: magento2-webapi-create`. Description (folded, ≤ 1024 chars) following the graphql-create
voice: schema-/contract-first REST Web-API generator; use when adding REST endpoints / service
contracts / repositories for an existing entity; goes beyond module-create by handling
SearchCriteria, auth scopes, exception mapping, extension attributes, custom actions, and tests.

## 8. Registration (the 20th skill) — contract-test obligations

Every one of these must land or contract tests fail:

1. `skills/magento2-context/references/skill-versioning.md` — add a `magento2-webapi-create` row
   (version-registry-consistency test requires a row per skill dir).
2. `README.md` — bump **19 → 20** in *all* prose ("19 skills", "skills/ # 19 …", Layout block),
   add the Skills-table row, and add the dependency-graph edge. (skill-count-consistency test
   asserts every "N skills" equals `ls -d skills/*/ | wc -l`.)
3. `docs/skills-reference.md` — per-skill quick-reference entry.
4. `CHANGELOG.md` — `[Unreleased]` → Added bullet.
5. Placeholder tokens: all needed tokens (`{Vendor}`, `{ModuleName}`, `{EntityName}`, `{entity}`,
   `{entities}`, `{vendor_lower}`, `{module_lower}`, `{route}`) are **already registered** in
   `placeholder-schema.md` — verified. No new token needed.
6. Templates must pass `php -l` / `xmllint` template-lint and bash-syntax (no scripts here).

## 9. Acceptance criteria

- `bash tests/run-all.sh` is green (skill-count, version-registry, placeholder-token,
  frontmatter, reference-integrity, template-lint all pass).
- New skill mirrors graphql-create's structure (SKILL.md Phase 0–5, `references/`, `templates/`).
- Generated module (rendered from templates with a sample vendor/entity) passes `php -l` +
  `xmllint` and would pass `magento2-module-review` with zero Critical/High.
- CRUD + optional custom-action surface as specified; auth scopes documented and defaulted to ACL.

## 10. Out of scope (YAGNI)

- Scaffolding the entity / persistence (that is `module-create`'s job).
- SOAP-specific tooling beyond what `webapi.xml` already yields for free.
- Async/bulk Web API (`/async`, `/bulk`) — note as a future extension, do not build.
- GraphQL (covered by `graphql-create`).
