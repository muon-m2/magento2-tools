# Skill Versioning

Single source of truth for skill versions and the rules for bumping them. Every saved
artefact (review report, blueprint, plan, task file, deploy report, audit report) must
record the contributing skill versions so older artefacts remain re-interpretable when
skills evolve.

## Current Versions

| Skill                      | Version | Bumped when                                                         |
|----------------------------|---------|---------------------------------------------------------------------|
| magento2-context           | 1.7.0   | JSON schema changes, new resolution rules, new tool probes          |
| magento2-module-create     | 1.8.0   | New template added, surface added, naming rule changed              |
| magento2-module-review     | 2.3.1   | New checklist category, severity calibration change, new JSON field, fix-routing change |
| magento2-feature-implement | 2.10.1  | New phase, new approval gate, mode added, new task types (I/C/L/Q), template structure change, delegation/fallback discipline |
| magento2-bug-fix           | 1.0.2   | Workflow phase change, RCA format change                            |
| magento2-deploy            | 1.2.1   | Deploy plan template change, rollback recipe change                 |
| magento2-test-generate     | 1.1.2   | Generator pattern change, new test type added                       |
| magento2-module-upgrade    | 1.1.0   | New deprecation map, BC-break detection rules                       |
| magento2-security-audit    | 1.2.1   | New CVE source, new pattern, severity calibration change            |
| magento2-performance-audit | 1.1.1   | New pattern, new runtime check, severity calibration change         |
| magento2-debug             | 1.2.0   | New mode added, output format change                                |
| magento2-eav-attribute     | 1.2.1   | New entity type supported, new input type, template change          |
| magento2-graphql-create    | 1.0.3   | New resolver pattern, schema-migration rule change                  |
| magento2-frontend-create   | 1.0.1   | New theme detection rule, new component pattern                     |
| magento2-data-migration    | 1.2.0   | New idempotency strategy, new importer pattern                      |
| magento2-release           | 1.1.1   | New tag convention, new publish target                              |
| magento2-i18n              | 1.2.0   | New extraction pattern, new placeholder rule                        |
| magento2-adminhtml-form    | 1.0.0   | New template/surface added, field-type pattern, controller change   |
| magento2-adminhtml-listing | 1.0.1   | New template/column type, mass-action change, wiring change         |
| magento2-webapi-create     | 1.0.0   | New template/route/auth-scope, service-contract change, custom-action pattern |
| magento2-extension-point   | 1.0.0   | New mode/template added, interception pattern change                          |
| magento2-system-config     | 1.0.0   | New field type/template, config-reader pattern change                         |
| magento2-cli-command       | 1.0.0   | New mode/template, command or cron pattern change                             |
| magento2-message-queue     | 1.0.0   | New connection type/template, topic or consumer pattern change                |
| magento2-static-analysis   | 1.0.0   | New tool/rule, autofix-safety calibration change                              |
| magento2-docs-generate     | 1.0.0   | New surface extractor, doc-structure change                                   |
| magento2-indexer           | 1.0.0   | New indexer/mview pattern, dimension support                                  |
| magento2-marketplace-prep  | 1.0.0   | New EQP check, readiness-scoring calibration                                  |
| magento2-accessibility-audit | 1.0.0 | New WCAG rule, runtime pass change                                            |
| magento2-breeze-child-theme | 1.0.0 | New template/parent variant, theme-layout change                              |
| magento2-breeze-module-adapt | 1.0.0 | New template/surface, widget-conversion or sequence rule change               |
| magento2-breeze-compat-audit | 1.0.0 | New check/pattern, severity calibration change                                |

## Changelog (last update: 2026-06-19)

- **Plugin 1.13.0 — Breeze (Swissup Breezefront) support — three new skills + context detection.**
  Adds first-class Breeze theme support to the suite.
  - `magento2-context 1.6.1 → 1.7.0` — new `theme.breeze` JSON object
    (`installed`/`active`/`parent`/`packages`/`source`): `installed` keys off any
    `swissup/breeze-*` / `swissup/module-breeze` composer package; `active` walks the active
    frontend theme's `app/design` `<parent>` chain for a Breeze ancestor. New detection rules
    in `references/theme-detection.md`; `resolve-context.sh` emits the object. Minor (new
    schema field + resolution rule).
  - **New skill `magento2-breeze-child-theme` 1.0.0** — scaffolds a Breeze child theme
    (`theme.xml` `<parent>Swissup/breeze-*`, `registration.php`, `composer.json`,
    `web/css/breeze/_default.less` with `@critical` guards). Sibling to
    `magento2-frontend-create` (generic/Hyva/Luma themes); this one is Breeze-specific.
  - **New skill `magento2-breeze-module-adapt` 1.0.0** — generates a companion
    `{Vendor}_{Module}Breeze` integration module (sequenced after the target + `Swissup_Breeze`)
    holding the Breeze adapter layer: `breeze_default.xml` JS registration, `breeze/_default.less`,
    and Cash `$.widget` stubs converted from the target's RequireJS/Knockout/jQuery widgets.
    Never edits the target module (works on read-only `vendor/` modules).
  - **New skill `magento2-breeze-compat-audit` 1.0.0** — read-only static auditor; scans a
    module for RequireJS/Knockout/jQuery-widget/mixin usage and emits ranked findings
    (Markdown + JSON `outputKind=compatibility` + SARIF) via the shared emit-json.sh /
    emit-sarif.sh emitters, plus a verdict (compatible / needs Better Compatibility / needs
    manual adapter) pointing at `magento2-breeze-module-adapt`.
  - Bundled in plugin **1.13.0**.

- **`magento2-feature-implement` 2.10.0 → 2.10.1 — delegation discipline (unreleased).** Fixes the
  failure mode where the orchestrator skipped sub-skill delegation on an unverified "not
  Skill-invocable here" assumption and relabelled typed tasks (e.g. a `C` admin-config task built
  inline as `X`). Adds a **Delegate by probing, never by assumption** Core Rule (attempt the
  `Skill` call; fall back only on a real failure; record the concrete reason — never skip from
  memory or a project note), a Phase 5 **Fallback discipline** subsection (keep the task's type
  prefix on fallback; author the same output inline from the skill's references; `D*` never runs
  `bin/magento` inline), a "type by work, not tool availability" note in
  `references/task-breakdown-guide.md`, and `Skill:`-field + `D1` deploy guidance in
  `templates/task-record.md`. No new phase/gate/mode/task-type. Pinned `@version` tokens updated.

- **Plugin 1.12.1 — required documentation step before the final step.** Both creation skills now
  produce documentation as a mandatory step before their final step, instead of an optional
  after-thought. Bumps:
  - `magento2-feature-implement 2.9.0 → 2.10.0` — Phase 7 split into **7A** (documentation, required)
    + **7B** (final report). 7A (re)generates per-module docs via `magento2-docs-generate`, a
    cross-module `spec.md`, developer/user HTML guides with screenshots (reusing Phase 6B captures),
    REST/GraphQL request/response payload examples when an API surface exists, and helpful artifacts;
    refresh-not-stale on resume/extend. New `references/documentation-guide.md`; per-mode scope wired
    into `modes.md`; the report links the doc set.
  - `magento2-module-create 1.7.1 → 1.8.0` — new **Step 6** (documentation, required) before the
    report (now Step 7). Code-derived/static set under `{module}/docs/` (Markdown): technical
    reference via `magento2-docs-generate`, developer/user guides, screenshot placeholders when no
    running instance, contract-derived API examples, and artifacts. Reduced in Quick Create;
    refresh-only in `--mode=augment`. New `references/documentation-guide.md`.

- **New skill `magento2-static-analysis` 1.0.0 (unreleased)** — action skill that runs
  the static-analysis gate (phpcs Magento2, phpstan, phpmd, php-cs-fixer, rector) over a
  module or diff, applies safe auto-fixes (phpcbf, php-cs-fixer, safe rector sets) after
  a mandatory Phase-2 approval gate, and emits residual violations as ranked findings
  (Markdown + JSON `outputKind=quality` + SARIF) via the shared emit-json.sh / emit-sarif.sh
  emitters. References: `tool-matrix.md`, `autofix-safety.md`, `ci-integration.md`.
  Scripts: `run-analysis.sh`, `apply-fixes.sh`, `build-findings.sh`. No templates.

- **New skill `magento2-message-queue` 1.0.0 (unreleased)** — generator for a full async
  message-queue surface on an **existing** module: a `communication.xml` topic (typed
  `request` DTO), the `queue_topology.xml` / `queue_publisher.xml` / `queue_consumer.xml`
  bindings, a `di.xml` DTO `<preference>`, a typed message interface + model, a
  `PublisherInterface`-backed publisher (topic in a single `TOPIC` const), and an idempotent
  consumer that decodes the typed message and delegates to a domain handler (poison-message
  log-and-drop). 10 templates, 4 references. Goes beyond `magento2-module-create`'s queue
  stub by wiring all five XML files so the topic ↔ topology ↔ publisher ↔ consumer ↔ queue
  chain resolves, and baking in the cross-file name-consistency contract (the #1 MQ bug),
  idempotency, and `db`-default connection. New tokens `{TopicName}` / `{QueueName}` /
  `{ExchangeName}` / `{ConnectionName}` / `{PublisherName}` registered in
  `placeholder-schema.md` (reusing existing `{ConsumerName}` / `{EntityName}`). Built
  test-first (consumer unit test RED on missing class → GREEN against the templates). Not
  yet bundled in a plugin release (`plugin.json` unchanged).

- **Plugin 1.10.1 — audit-remediation patch bumps.** A correctness pass (bug fixes + drift
  cleanup + regression tests) patch-bumped every skill whose scripts/templates actually changed;
  doc-only changes (e.g. `magento2-i18n`, `magento2-debug`, `magento2-performance-audit`,
  `magento2-feature-implement`) did **not** bump, per the one-line-pointer precedent. Bumps:
  - `magento2-context 1.6.0 → 1.6.1` — `resolve-context.sh` gained the documented composer.json
    `require` vendor fallback (letters-only, most-frequent `{name}/module-*` prefix); SKILL.md
    cache-key and tools-schema docs reconciled with the resolver.
  - `magento2-module-create 1.7.0 → 1.7.1` — admin Save controller loads-by-id on edit (was a
    duplicate-on-edit); admin form/listing layouts match the specialist skills.
  - `magento2-module-review 2.3.0 → 2.3.1` — `emit-json.sh` emits the schema-required
    `scanner_errors`; the grep evidence fallback also scans `.phtml`.
  - `magento2-deploy 1.2.0 → 1.2.1` — `smoke.sh` checks `module:status --enabled` per module;
    `preflight.sh` enforces the production branch-match guardrail.
  - `magento2-security-audit 1.2.0 → 1.2.1` — CVE range covers `-pN` patch builds; emitted
    `category` values use the schema vocabulary; secret scan covers `app/etc/env.php`.
  - `magento2-test-generate 1.1.1 → 1.1.2` — REST test service name uses PascalCase `{Vendor}`;
    `coverage-gap.sh` no longer double-counts nested type dirs.
  - `magento2-eav-attribute 1.2.0 → 1.2.1` — category/customer-address patch class names match
    the output filename (PSR-4 fix).
  - `magento2-graphql-create 1.0.2 → 1.0.3` — schema fragment no longer declares non-null fields
    no resolver returns.
  - `magento2-release 1.1.0 → 1.1.1` — workflow renders the release-notes file before Phase 6
    consumes it.
  - `magento2-adminhtml-listing 1.0.0 → 1.0.1` — listing layout drops the storefront-only
    `<update handle="styles"/>`; SKILL.md makes the form-reuse route/ACL contract explicit.

- **New skill `magento2-webapi-create` 1.0.0 (unreleased)** — contract-first generator for REST /
  Web-API surfaces over an **existing** entity (sibling to `magento2-graphql-create`). Generates
  `webapi.xml` CRUD routes + optional custom-action routes, the `Api/{Entity}RepositoryInterface`
  service contract + `Api/Data` DTO/search-results interfaces, a full `{Entity}Repository`
  (`SearchCriteria` via `CollectionProcessor`), `di.xml` preferences, `acl.xml`, and a
  `WebapiAbstract` functional test. 8 templates, 6 references. Goes beyond `module-create`'s webapi
  stubs by handling per-route auth scopes (anonymous/self/ACL), exception→HTTP mapping, extension
  attributes, and SearchCriteria pagination. Assumes the entity model exists (`module-create`'s job);
  uses the literal `entity_id` PK. Not yet bundled in a plugin release (`plugin.json` unchanged).

- **New skill `magento2-adminhtml-listing` 1.0.0 (unreleased)** — generator for adminhtml
  UI-component grids/listings: declarative `{entity}_listing.xml` + DataProvider
  (`AbstractDataProvider` default; optional SearchResult path for joins) + actions column +
  mass-action controllers + wired `Index` controller. 12 templates, 9 references,
  `scripts/verify-listing.sh`. Bakes in the 5-place listing naming contract (the empty-grid
  pitfall). Sibling to `magento2-adminhtml-form`; reuses existing routes/ACL/menu when the
  form skill already created them. Not yet bundled in a plugin release (`plugin.json` stays at
  current version).

- **New skill `magento2-adminhtml-form` 1.0.0 (unreleased)** — generator for adminhtml
  UI-component edit forms: declarative `{entity}_form.xml` + `DataProvider`
  (`AbstractDataProvider` + `DataPersistorInterface`) + New/Edit/Save/Delete controllers +
  required button blocks, wired to an existing listing. 17 templates, 10 references,
  `scripts/verify-form.sh`. Built test-first (RED baseline of unaided gaps → templates → GREEN via
  the repo template-lint harness). Bakes in the five-name **blank-form naming contract**, flat-post
  Save (empty id → `null`), `acl.xml` **without** the invalid `translate` attribute, canonical
  WYSIWYG/toggle fields, and Open-Source-vs-Adobe-Commerce gating (staging/B2B/Page Builder). Fills
  the adminhtml gap between `magento2-module-create` (basic admin stub) and
  `magento2-frontend-create` (storefront-only). Not yet bundled in a plugin release
  (`plugin.json` stays 1.6.0).

- **`plan.md` / task-record de-duplication (`magento2-feature-implement` 2.7.0 → 2.8.0)** —
  detailed task records no longer appear in both `plan.md` and the task files. `plan.md` is now
  strictly the resumable **index** (Mermaid diagrams + `## Current State` checklist + Smoke
  Iterations + summary); the **detailed records** (type, target, deps, included changes, risks,
  acceptance criteria) live only in `tasks.md` (≤ 5 tasks) / `tasks/` (> 5 tasks). The
  `task-list.md` template was renamed to `templates/plan.md` (index only) and a new
  `templates/task-record.md` holds the detailed records. Records are now written **before** the
  Phase 4 approval gate, alongside `plan.md`, so the user reviews full task detail before
  approving — the old "records written only after approval" carve-out is removed and everything
  follows one save-before-present rule. New placeholder tokens `{ID}` / `{NNN}` / `{kebab-title}`
  registered in `placeholder-schema.md`. Version bumped in the three emitting templates
  (`feature-blueprint.md`, `plan.md`, `final-report.md`).

- **Test-first discipline rolled out (move 1 + move 2 data/EAV)** — new shared reference
  `magento2-context/references/tdd-discipline.md` defines the red → green → refactor loop and the
  behaviour/boilerplate line once; `magento2-bug-fix` now points at it (one-line pointer, no
  bump). `magento2-context` itself is **not** bumped — adding a cross-cutting reference doc does
  not change its resolved JSON/schema/probes (the bump triggers in its row), and a context bump
  would force-touch the many files that pin the `magento2-context` version for no behavioural reason.
  - **magento2-feature-implement 2.6.0 → 2.7.0** — opt-in **TDD mode** (`--tdd` /
    `Feature implement: tdd = on` / `MAGENTO2_FI_TDD=1`, default off; `spike` exempt). New
    `references/tdd-mode.md`; Phase 5 `M*`/`X*` behaviour is written test-first (signature →
    failing test → minimal body), Phase 4 acceptance criteria become the RED test list, and `T*`
    becomes a coverage top-up instead of the first author. Version bumped in the three emitting
    templates (`feature-blueprint.md`, `final-report.md`, `task-list.md`).
  - **magento2-data-migration 1.1.1 → 1.2.0** — Phase 2 is now **Test First, then Generate**: a
    failing integration test asserts post-migration state **and idempotency** (apply twice →
    identical) before the patch body; tiered unit fallback when no test DB; Phase 3 runs the test;
    new acceptance criterion + test path in outputs/report.
  - **magento2-eav-attribute 1.1.2 → 1.2.0** — Phase 3 is now **Test First, then Generate**: a
    failing integration test asserts the attribute's scope/input-type/wiring **and** idempotency
    before the patch; behavioural source/backend models get a test-first unit test; tiered
    fallback; new acceptance criterion + test path in outputs/report.
  - Untouched by design: `magento2-test-generate` positioning (still the correct backfiller for
    test-less modules) and `magento2-module-review` (no test-first gate — it must stay usable on
    modules that legitimately have no tests).
- **magento2-feature-implement 2.5.0 → 2.6.0** — Phase-5 Current-State maintenance fix. The
  "mark the task `[x]` in `plan.md`" instruction is now a **Per-task completion protocol** woven
  into the per-task execution loop (a closing step on every task type — M/X/R/T/E/G/V/D), framed
  as a gate: do not start the next task until the checkbox is flipped and saved. Previously the
  rule lived only in the Folder-Structure preamble and the resume paragraph, so a normal (and
  especially an `extend`-mode) run dropped the update and `## Current State` never advanced.
  Also: the `extend`/Phase-4 contradiction is resolved — `extend` skips Phase 3 only and keeps a
  minimal Phase 4 that writes `plan.md` with a `## Current State` checklist (SKILL.md previously
  said `extend` skipped Phases 3-4, leaving nothing to maintain); `modes.md` extend/hotfix
  pipelines now name the protocol; Phase 6 start gains a Current-State reconciliation safety net.
- **magento2-module-review 2.2.3 → 2.3.0** — new **Fix Routing** table: when the user asks to act
  on findings or report recommendations, each item routes deterministically to the owning skill
  (`magento2-bug-fix` for defects, `magento2-feature-implement --mode=extend` for behaviour/schema
  changes, `magento2-test-generate` for coverage gaps, audit/builder skills for the rest); step 6
  fixes inline only style/PHPDoc-class items and now covers Low severity explicitly. Both report
  templates require each Recommended Next Step to name its executing skill. Diff-mode reviews
  invoked from another skill return findings to the caller (no routing recursion).
- **PHP template PER-CS / Magento-2 compliance pass** — audited all 64 PHP templates with the
  authoritative `Magento2` PHPCS standard + PSR-12 (PER-CS proxy). Result: **0 Magento2 errors**
  (was 19+`final`), category-C annotation/commenting warnings cut 137 → 10 (the residual 10 are
  intersection-typed mock properties — a `Magento2.Commenting.ClassPropertyPHPDocFormatting` sniff
  limitation, deliberately left). Changes:
  - Real formatting fixes: multiple-`use`-on-one-line split, `private`-keyword-split joined, broken
    method-body indentation corrected (`magento2-module-create`, `magento2-data-migration`,
    `magento2-test-generate`).
  - PHPDoc added/repaired across templates: multi-line method docblocks, short descriptions +
    blank-line-before-tags, missing `@param`, `@var` on plain-typed test properties; complex
    array-shape `@param` types simplified to sniff-parseable `array` + description.
  - **`final` removed** from all 19 template classes (`Magento2.PHP.FinalImplementation` is an
    error — Magento prohibits `final` for extensibility).
  - `php-coding-style.md` gains a `final`/`_construct`/static precedence rows + a *Known Sniff
    Limitations* section; `magento2-module-create/references/phpdoc-rules.md` reconciled (test
    methods get brief docblocks; plain-typed test props get `@var`; intersection-typed left).
  - `magento2-bug-fix 1.0.1 → 1.0.2`, `magento2-data-migration 1.1.0 → 1.1.1`,
    `magento2-eav-attribute 1.1.1 → 1.1.2`, `magento2-graphql-create 1.0.1 → 1.0.2`,
    `magento2-test-generate 1.1.0 → 1.1.1`; folded into the unreleased `magento2-context 1.6.0`
    and `magento2-module-create 1.7.0`.
- **magento2-context 1.5.0 → 1.6.0** — new shared reference `references/php-coding-style.md`:
  PER-CS 3.0 is the baseline coding style for all generated/modified PHP, with the Magento 2
  coding standard taking precedence on any conflict; `--standard=Magento2` PHPCS stays the single
  enforcement gate (guidance-only — no second ruleset). Listed in the context Reference Files and
  consumed by every builder skill and by `magento2-module-review`.
- **magento2-module-create 1.6.0 → 1.7.0** — Step 4 generation rules now state the PER-CS-3.0
  baseline + Magento-2-precedence coding style for every generated PHP file, pointing at the
  shared `php-coding-style.md`.
- **magento2-module-review 2.2.2 → 2.2.3** — code-style review lens updated: PER-CS 3.0 baseline
  with Magento-2 precedence (`phpdoc-code-style.md`); a PER-CS deviation the Magento 2 standard
  requires is no longer a finding.
  (Builder skills `magento2-graphql-create`, `magento2-eav-attribute`, `magento2-data-migration`,
  `magento2-bug-fix`, `magento2-frontend-create` gained a one-line pointer to the shared rule
  without a version bump — same pattern as the `.docs` anchoring pointers.)
- **magento2-context 1.4.0 → 1.5.0** — artifact-location anchoring. New `project_root` and
  `docs_root` JSON fields plus an **Artifact location** Core Rule: every `.docs/` artifact is
  written under `{project_root}/.docs`, never under `{magento_root}`/`app/code`, even if a step
  changes the shell cwd. `resolve-context.sh` now emits the two fields; `findings-schema.md`
  states the same anchor for the finding-producers.
- **magento2-feature-implement 2.4.0 → 2.5.0** — save-before-present + plan/task gating.
  `blueprint.md` (Phase 2) and `plan.md` (Phase 4) are now written to disk and confirmed to
  exist *before* they are presented for review and before the approval gate — the user reviews
  the file, not just the chat. Detailed task records (`tasks.md` / `tasks/`) are written only
  *after* the plan is approved (Phase 4 step 9). `.docs/` is anchored at the project root per
  magento2-context, never inside the Magento tree. Phase 5 flips the status line in both
  `blueprint.md` and `plan.md`; `task-breakdown-guide.md` corrected to match the new ordering.
  Per-task files renamed `{ID}-{kebab-title}.md` → `{NNN}-{ID}-{kebab-title}.md`, where `{NNN}`
  is a zero-padded execution-order index (parallel-wave tasks share the same `{NNN}`).
- **magento2-module-review 2.2.1 → 2.2.2** — `emit-json.sh` honours a `DOCS_ROOT` env var
  (default `.docs`) so findings always land under the project-root `.docs/`, never under an
  in-`src/` cwd inside the Magento tree. Default behaviour is unchanged.
- **magento2-performance-audit 1.1.0 → 1.1.1** — `build-findings.sh` honours the same
  `DOCS_ROOT` anchor as `emit-json.sh`.
- **magento2-context 1.3.0 → 1.4.0** — hub runner contract fix plus a portability and
  layout-awareness pass:
  - CTX-1: in bare-PHP mode `runner` now serialises as the empty string `""` instead of JSON
    `null`, which had produced the literal command `null php -r ...` (exit 127) on every
    bare-PHP project. JSON `null` is reserved for the no-environment case.
  - CTX-4: macOS/BSD portability — SHA-256 falls back `sha256sum`→`shasum`→`openssl`;
    first-letter uppercasing uses awk (not GNU `sed \U`); tab escaping uses a literal tab.
  - CTX-5/CTX-6: the Magento-root layout is detected BEFORE vendor resolution (repo-root
    projects now resolve a vendor), and the bare-mode `magento_cli` is layout-aware.
  - CTX-7: edition detection adds Commerce Cloud and Mage-OS.
  - CTX-8: the compose probe matches `php`/`phpfpm`/`php-fpm`/`fpm`/`web` service names.
  - CTX-3: a cache TTL (default 24h, `M2_CACHE_TTL`) re-resolves stale runner state; the cache
    is written atomically.
  Guarded by `tests/test-context-resolver.sh` and `tests/test-context-layout-override.sh`.
- **magento2-eav-attribute 1.1.0 → 1.1.1** — frontmatter fix (EAV-1): removed 4 leading
  spaces before the opening `---` that prevented the skill from registering. Guarded by
  `tests/test-skill-frontmatter.sh`.
- **magento2-feature-implement 2.3.1 → 2.4.0** — Phase-6 overhaul: the smoke-browser raw-CDP
  fallback no longer fake-passes (exits 78 — FI-2); the S8 pass rule is "no new/unresolved
  exception groups" instead of the unsatisfiable "diff is empty" (FI-1); the skill invokes
  `magento2-context` instead of hand-rolling a probe (FI-3); `admin-login` saves cookies and
  S4–S6 re-load them, `require("fs")` → ESM import, a Puppeteer→Playwright adapter, and a
  configurable `--admin-path` (FI-7/8/9); S4/S5/S9 acceptance text downgraded to what the
  script does (FI-10); the duplicated/drifted Phase-6B suite tables collapsed to reference
  pointers; vendor-name leaks and the CLAUDE.md-as-password concern fixed.
- **magento2-feature-implement 2.3.0 → 2.3.1** — trimmed the frontmatter `description` from
  ~1256 to ≤1024 chars (FI-4) so the resume-trigger sentence survives registry truncation.
- **magento2-debug 1.1.0 → 1.2.0** — added `scripts/snapshot.sh` (read-only, context-aware) so
  the documented `snapshot` mode has an implementation; root-aware DI/plugin walks and the
  Monolog-2 timestamp fix from the same pass.
- **magento2-context 1.2.0 → 1.3.0** — tool probe is now layout- and runner-aware.
  Project-local `vendor/bin/*` tools (phpcs, phpstan, phpunit, phpmd, rector, psalm,
  php-cs-fixer) resolve via the host path at the Magento root (so a `src/` layout finds
  `src/vendor/bin/*`) and, when absent from the host mount, via a runner probe
  (`{runner} test -x vendor/bin/<tool>`, guarded on `composer.lock` presence so the
  hermetic contract test never shells into a container). Resolved value is the bare
  runner-relative `vendor/bin/<tool>` for runner-backed modes (consumers prefix `{runner}`
  themselves). Previously these resolved to `null` in `src/` layouts; repo-root (`.`)
  layouts are byte-identical to before.
- **magento2-context 1.1.0 → 1.2.0** — portability: removed hardcoded project container
  name from runner detection. Container now resolves via `M2_PHP_CONTAINER` env >
  `.claude/m2.json` `php_container` > generic name patterns (configured-but-not-running
  falls through). Magento root now detects `.`-vs-`src` layout (was hardcoded `src`
  default), overridable via `M2_MAGENTO_ROOT` / `.claude/m2.json` `magento_root`. Cache
  key now folds in the `.claude/m2.json` hash and the `M2_*` env overrides so changing an
  override busts the cache.
- **magento2-context 1.0.0 → 1.1.0** — new fields: `runner_kind`,
  `theme.frontend_source`, `theme.adminhtml_source`, `composer_source`,
  `php_version_source`. Cache key now includes `composer.json` and `CLAUDE.md` hashes.
  Theme no longer defaults to `custom` without probe evidence.
- **magento2-module-review 2.1.0 → 2.2.0** — `emit-json.sh` now reads `SKILL_NAME`,
  `SKILL_VERSION`, `SKILL_VERSIONS_JSON`, `OUTPUT_KIND`, `OUTPUT_BASENAME` from the
  environment and emits an `outputKind` top-level field.
- **magento2-deploy 1.0.0 → 1.1.0** — `--validate-only` flag added; preflight now
  runs PHPUnit, `setup:db:status`, dependency-graph cycle detection, composer
  install dry-run (production), and maintenance-mode writeable probe (production).
  `record()` treats required-skipped as failure.
- **magento2-security-audit 1.0.0 → 1.1.0** — `build-findings.sh` aggregator added.
  CVE data moved to `magento-cve-data.yaml` with a `status: live|illustrative`
  marker; scanner refuses `confidence: confirmed` unless `status: live`.
- **magento2-eav-attribute 1.0.0 → 1.1.0** — product, customer, category templates
  now include `getAttribute()` idempotency guards.
- **magento2-i18n 1.0.0 → 1.1.0** — `merge-csv.sh` added; obsolete phrases now go
  to `<locale>.obsolete.csv` instead of inline comments.
- **magento2-module-create 1.5.0 → 1.5.1** — `create-dirs.sh` accepts `MODULE_DIR`
  env override; `verify-created.sh` arithmetic bug fixed.
- **magento2-performance-audit 1.0.0 → 1.0.1** — `emit-json.sh` invocation contract
  documented via env vars (`SKILL_NAME=magento2-performance-audit`,
  `OUTPUT_KIND=performance`).
- **magento2-release 1.0.0 → 1.0.1** — Phase 2 now calls
  `magento2-deploy --validate-only`.

## Header Format

Single-skill artefact:

```
Skill version: {Skill}@{Version}
```

Multi-skill artefact (preferred — explicit about every contributor):

```
Skill versions:
  - {LeadSkill}@{Version}
  - {ContributingSkillA}@{Version}
  - {ContributingSkillB}@{Version}
  - magento2-context@{Version}
```

Substitute concrete values from the table above when writing an artefact. The
registry-consistency test recognises these tokens as placeholders and does not
flag them as drift.

## Semver Rules

| Bump  | Trigger                                                                                             |
|-------|-----------------------------------------------------------------------------------------------------|
| Major | Removed checklist categories, changed JSON schema in a backward-incompatible way, removed CLI flags |
| Minor | New checklist category, new mode, new template, new optional flag                                   |
| Patch | Bugfix only — no behaviour change to outputs                                                        |

Bumping a skill means editing this file AND updating any template strings that emit the
version (`templates/feature-blueprint.md`, `templates/final-report.md`,
`templates/plan.md`, `references/report-template.md`, `templates/report.html`).

## Why This Matters

Saved reports include the skill version that produced them. Future re-reads can detect
mismatch and either re-run with current skills or explicitly preserve historical
interpretation. The version is the contract for "this report's findings mean what those
rules meant at that time."
