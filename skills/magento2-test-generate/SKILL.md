---
name: magento2-test-generate
description:
  Generate tests for an existing Magento 2 module — unit, integration, REST/GraphQL API,
  JavaScript (Jasmine), or MFTF. Use when a module lacks coverage in any test type, when
  coverage falls below a target percentage, or when invoked from magento2-feature-implement
  Phase 6. Discovers what tests are missing, asks before generating, then writes tests
  that pass static checks and contain real assertions.
---

# Magento 2 Test Generate

Fill the test gap for an existing module. Five test types covered:

| Test type          | When generated                                                                    |
|--------------------|-----------------------------------------------------------------------------------|
| Unit               | For every `Api/`, `Service/`, `Model/`, `Plugin/`, `Observer/`, `Resolver/` class |
| Integration        | For `persistence` modules (schema, repository, data patch round-trips)            |
| API (REST/GraphQL) | For modules declaring `webapi.xml` or `schema.graphqls`                           |
| JS (Jasmine)       | For modules with KO components or RequireJS modules                               |
| MFTF               | For admin UI flows (grid + form CRUD)                                             |

## Core Rules

- **Discovery first.** Before generating, scan the module to know exactly what's missing.
  Do not overwrite existing tests unless `--overwrite` is set.
- **Real assertions only.** Every generated test must contain at least one real assertion.
  Empty stubs and `markTestIncomplete()` calls are forbidden.
- **Static-check every file.** Run `php -l` on every PHP test file, `xmllint` on every
  MFTF file, `node --check` on every JS test before reporting done.
- **No source modification.** This skill is purely additive. If a source class is
  genuinely untestable as written, surface it as a finding and recommend
  `magento2-bug-fix` or a refactor task — do not refactor source.
- **Type-safe mocks.** Use `MockObject&InterfaceName` typing on every mock property.
- **Source of truth.** Derive output only from the target module's own code plus templates, shared
  references, and baked-in Magento 2 knowledge (official Magento/Adobe docs live-fetched only when
  uncertain). Do NOT read or "study" *other* modules under `app/code`/`vendor/*`/Magento core to
  infer conventions. See `magento2-context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture vendor, runner, tools (phpunit, node, mftf).

### Phase 1 — Discovery

Per module, run `${CLAUDE_SKILL_DIR}/scripts/coverage-gap.sh <module-path>` to identify:

- Source classes lacking tests (Service, Plugin, Observer, Resolver, Controller, Cron,
  Consumer)
- Coverage gap from latest Clover/JUnit reports (if present in `var/log/`)
- Surfaces warranting non-unit tests (persistence → integration, rest_api/graphql → API,
  frontend_ui with JS → Jasmine, admin_ui → MFTF)

Produce a **test plan**: each missing test by type with the source it targets.

### Phase 2 — Approval (APPROVAL GATE)

Present the test plan. Wait for "proceed". The user can restrict via `--types=unit,api`.

### Phase 3 — Generate

For each missing test, use the matching template from `templates/`. See
`references/unit-test-patterns.md`, `references/integration-patterns.md`,
`references/api-test-patterns.md`, `references/js-test-patterns.md`,
`references/mftf-patterns.md`.

Generation rules per test type:

#### Unit

- Mock all constructor dependencies with `createMock()` + `MockObject&Interface`.
- For each public method: at least one happy-path test + one error-path test.
- For methods with significant branches: one test per branch.

#### Integration

- Schema test: tables exist, columns match.
- Repository test: save → get → list → delete round-trip.
- Data patch test: run patch in isolated DB; assert seeded rows.

#### REST API

- Per route in `webapi.xml`: 200 (auth'd happy path) + 401 (unauth) + 400 (bad input).

#### GraphQL

- Per query/mutation: positive shape + auth fail + input error.

#### Jasmine

- For each KO component / RequireJS module: instantiation test + at least one public-API
  test.

#### MFTF

- For each admin grid: list-render + add-new + edit + delete flows.

### Phase 4 — Verify

- `php -l` on every PHP test file.
- `node --check` on every JS test file.
- `xmllint --noout` on every MFTF XML file.
- Run unit tests via `{ctx.runner} vendor/bin/phpunit {paths}`. Fix failures.
- Run integration tests if Magento install available.
- **Apply the shared module-hygiene baseline (required).** After generating the test PHP
  files, run
  `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
  to stamp the standard copyright header onto every new `.php` — Magento test files carry
  it too (idempotent — it skips files that already carry it). See
  `magento2-context/references/module-hygiene.md`.

### Phase 5 — Report

Write to `{output_root}/tests/{Vendor}_{Module}-coverage-{date}.md`:

- Tests generated (count per type)
- Source classes now covered
- Source classes still uncovered (with reason)
- Updated coverage % (if measurable)
- Skill versions

## Inputs

```
/magento2-test-generate [--types=unit,integration,api,js,mftf] [--target-coverage=80] [--docs-root=<path>] <Vendor>_<Module>
```

| Flag                | Default        | Meaning                                     |
|---------------------|----------------|---------------------------------------------|
| `--types`           | all applicable | Restrict to specific test types             |
| `--target-coverage` | 80             | Abort if generated tests can't reach target |
| `--missing-only`    | on             | Generate only for classes without any test  |
| `--overwrite`       | off            | Re-generate even where tests exist          |
| `--docs-root`       | unset          | Output-root override; see "Output root" below |

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/...
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration/...
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Api/...
{ctx.magento_root}/app/code/{Vendor}/{Module}/view/.../web/js/test/...
{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Mftf/...

{output_root}/tests/{Vendor}_{Module}-coverage-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/tests/`; otherwise default to
`{ctx.docs_root}/tests/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `references/test-types.md` — when each type is required.
- `references/unit-test-patterns.md` — per source-class-type unit test template.
- `references/integration-patterns.md` — DB fixtures, isolation, annotations.
- `references/api-test-patterns.md` — REST + GraphQL fixtures.
- `references/js-test-patterns.md` — Jasmine + RequireJS + KO patterns.
- `references/mftf-patterns.md` — MFTF section/page/test structure.
- `references/coverage-rules.md` — 80% target, exceptions, exemptions.
- `magento2-context/references/source-of-truth.md`: source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Templates

Templates reuse the test skeletons created in `magento2-module-create/templates/`
(test-controller.php, test-observer.php, test-plugin.php, test-resolver.php,
test-repository.php). Plus this skill's additions:

- `templates/test-service.php`
- `templates/test-integration-schema.php`
- `templates/test-integration-repository.php` (legacy `@magento*` annotations; for Magento < 2.4.5)
- `templates/test-integration-repository-attributes.php` (attribute-first `#[DataFixture]` / `#[DbIsolation]` /
  `#[AppArea]`; preferred on Magento 2.4.5+)
- `templates/test-integration-data-patch.php`
- `templates/test-api-rest.php`
- `templates/test-api-graphql.php`
- `templates/test-js-ko.js`
- `templates/test-mftf-listing.xml`
- `templates/test-mftf-form.xml`

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/coverage-gap.sh` — find untested source classes and surface them by type.

## Acceptance Criteria

- Every generated test contains at least one real assertion.
- Every PHP test passes `php -l`; JS passes `node --check`; XML passes `xmllint`.
- Unit tests pass when run against the current module code.
- Tests are placed at the correct path mirroring source.

## Related Skills

| Phase    | Skill                                                                                               |
|----------|-----------------------------------------------------------------------------------------------------|
| 0        | `magento2-context`                                                                                  |
| (caller) | `magento2-feature-implement` Phase 6, `magento2-bug-fix` Phase 4, `magento2-module-upgrade` Phase 5 |
