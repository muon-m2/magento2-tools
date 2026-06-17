# Skills reference

One compact section per skill: what it's for, how to invoke it, key flags, phases,
outputs, and related skills. For narrative flow descriptions see
[Flows and scenarios](flows-and-scenarios.md); for recipes see
[Daily workflows](daily-workflows.md).

All skills are invoked namespaced (`/magento2-tools:magento2-<skill>`) or by plain
language matching the skill's purpose. Every skill resolves project context through
`magento2-context` first (Phase 0) — that is omitted from the phase lists below.

---

## Foundation

### magento2-context

**Hub/library skill** — resolves vendor prefix, repo layout, edition, Magento/PHP
versions, runner (Docker vs bare PHP), Magento CLI and Composer commands, active theme,
and available quality tools into one JSON document. Consumed by every other skill;
rarely invoked directly.

- **Invocation:** automatic from other skills; directly: *"resolve the Magento context"*; `--no-cache` forces re-resolution.
- **Cache:** `.claude/.cache/magento2-context.json`, keyed by `composer.lock` +
  `composer.json` + `CLAUDE.md` hashes; default TTL 24h (`M2_CACHE_TTL`).
- **Honest gaps:** missing tools are `null`; `runner` is `""` for bare PHP,
  `runner_kind` is `null` only when no PHP environment exists at all.
- **Also owns the shared references:** naming conventions, severity scale, findings
  schema (JSON/SARIF), placeholder registry, skill version registry, and the shared
  **test-first (TDD) discipline** (`references/tdd-discipline.md` — the red → green →
  refactor loop and the behaviour/boilerplate line, consumed by bug-fix,
  feature-implement, data-migration, and eav-attribute).
- **Scripts:** `scripts/resolve-context.sh` (emit JSON without an LLM pass),
  `scripts/probe-tools.sh`.

---

## Build

### magento2-module-create

Scaffold a new module, surface-driven, with every generated file passing all 12 review
categories on creation. Works without a running Magento, Docker, or installed deps.

- **Invocation:** *"create a module OrderExport with persistence and a REST API"*;
  quick mode via `quick` / `minimal` / `skeleton`; `--mode=augment` to add to an
  existing module.
- **Surfaces:** `core` (always), `persistence`, `service_contracts`, `admin_config`,
  `admin_ui`, `frontend_ui`, `rest_api`, `graphql`, `cron`, `queue`, `extensions`.
- **Phases:** resolve identity/context → creation plan (confirm at ≥3 surfaces or ≥20
  files) → directory structure (`scripts/create-dirs.sh`) → generate from templates →
  verify (`php -l`, `xmllint`, `composer validate`, opportunistic phpcs/phpstan) →
  report + next steps.
- **Outputs:** module under `{magento_root}/app/code/{Vendor}/{ModuleName}`; creation
  checklist with per-category status.
- **Related:** reviewed by `magento2-module-review`; deployed by `magento2-deploy`;
  called by `magento2-feature-implement` (M* tasks).

### magento2-eav-attribute

Add a product / customer / customer-address / category attribute via an **idempotent**
data patch (guarded by `EavSetup::getAttribute()`); companion source/backend/frontend
models only when the input type requires them. Refuses legacy `InstallData.php`.

- **Invocation:** `--entity=product --code=acme_color --label="Acme Color"
  --type=select --module=Acme_Catalog`; missing inputs (scope, required,
  search/filter/grid flags, apply-to) asked in one batch.
- **Phases:** resolve inputs → plan (gate) → **test-first** (Phase 3A: a failing
  integration test asserts the attribute's scope/input-type/wiring *and* idempotency;
  behavioural source/backend models get a unit test) → generate (3B, minimal patch to
  green) → verify (`php -l`, deps exist, runs the test) → report.
- **Outputs:** `Setup/Patch/Data/Add{Code}Attribute.php` (+ companions,
  `Test/Integration/…`); `.docs/eav-attributes/{Module}-{code}-{date}.md`.
- **Related:** called by `magento2-feature-implement` (E* tasks); owns the canonical
  EAV patch templates (module-create's are the simpler variant).

### magento2-graphql-create

Schema-first GraphQL: schema fragment, resolvers (standard / **batch** / paginated),
auth + store-scope checks, DI wiring, unit tests. List-context resolvers are always
batch resolvers (N+1 prevention). Appends to existing `schema.graphqls`, never rewrites.

- **Invocation:** `--module=Acme_Reviews --operation=query|mutation
  --auth=customer|admin|anonymous` (anonymous mutations need justification).
- **Phases:** schema plan → resolver plan (gate) → generate → verify (`xmllint`,
  `php -l`, schema parse when CLI available) → report.
- **Outputs:** `etc/schema.graphqls`, `etc/graphql/di.xml`, `Model/Resolver/…`,
  resolver unit tests.
- **Related:** tests via `magento2-test-generate`; reviewed with
  `magento2-module-review --diff`; called by feature-implement (G* tasks).

### magento2-frontend-create

Theme-aware frontend scaffolding: theme, RequireJS module, Knockout component, Alpine
component (Hyva), transactional email template, or static asset — one operation per
invocation, always with the activating layout XML. Append-safe for
`requirejs-config.js` and `email_templates.xml`. Hyva projects get Alpine, not KO.

- **Invocation:** `/magento2-tools:magento2-frontend-create <operation>`.
- **Phases:** operation plan → generate → verify (`xmllint`, `node --check`, project
  linter if present) → report with activation commands.
- **Outputs:** files under the module's `view/frontend/…` or
  `app/design/frontend/{Vendor}/{Theme}/`.

### magento2-data-migration

Idempotent data work: fixed seeds (inline data patch), bulk imports (chunked importer
service + optional `--dry-run` CLI command), and transformations (transactional
SELECT→INSERT→DELETE, keyset-paginated). Destructive patches require
`--allow-destructive`.

- **Invocation:** `--type=seed|import|transform` + source flags.
- **Phases:** plan (migration class, source, idempotency strategy, rollback need) →
  **test-first** (Phase 2A: a failing integration test asserts post-migration state
  *and idempotency* — apply twice → identical; tiered unit fallback when no test DB) →
  generate (2B, minimal patch to green) → verify (runs the test) → report.
- **Outputs:** `Setup/Patch/Data/{Name}.php` (+ `Service/Importer/…`,
  `Console/Command/…`, `Test/Integration/…`); `.docs/migrations/{name}-{date}.md`.

---

## Quality

### magento2-module-review

Static-evidence review of a module (or a diff): architecture, security, persistence,
DI, frontend escaping, ACL/config, cron/queue, APIs, PHPDoc/SOLID/DRY, tests. No
environment assumptions; tools used opportunistically. Owns the shared JSON/SARIF
emitters.

- **Invocation:** *"review Acme_Checkout"*; `--diff [<ref>]` (default `origin/main`)
  for changed-files-only; "quick review" for a Tier-1 pass; `--format=json|sarif`;
  `--no-tier-3`.
- **Modes:** full (default for *audit*/*release-readiness*/*comprehensive*), quick
  (<20 PHP files, no API/route surfaces), diff, optional parallel (explicit
  authorization).
- **Phases:** scope identification (aborts if module identity unresolvable) →
  architecture map → optional tool passes → quality/architecture review → report →
  fixes only on request (severity order, re-checked per fix).
- **Severity:** Critical / High / Medium / Low / Info; every finding carries impact,
  evidence (`file:line`), recommendation, verification.
- **Outputs:** Markdown (or HTML); JSON
  `.docs/reviews/{Module}-review-{date}.json` + SARIF sibling.
- **Related:** called by create/feature/bug-fix/upgrade after every change.

### magento2-test-generate

Discovers coverage gaps and generates unit / integration / REST+GraphQL API / Jasmine /
MFTF tests with real assertions. Purely additive — never modifies source. It is the
**backfiller** for code that already exists (including modules with *no* tests); for
*new* behaviour the owning skill writes the test first (see `magento2-context`'s
`tdd-discipline.md`), and under feature-implement TDD mode this skill tops up coverage
on exempt/boilerplate classes rather than authoring the first behaviour test.

- **Invocation:** `[--types=unit,integration,api,js,mftf] [--target-coverage=80]
  [--missing-only] [--overwrite] <Vendor>_<Module>`.
- **Phases:** discovery (`scripts/coverage-gap.sh`) → test plan (gate) → generate from
  templates → verify (`php -l`, `node --check`, `xmllint`; unit tests *run* and fixed)
  → report.
- **Outputs:** tests under the module's `Test/` tree;
  `.docs/tests/{Module}-coverage-{date}.md`.
- **Related:** called by feature-implement (T*/6A), module-upgrade (Phase 5),
  graphql-create.

### magento2-security-audit

Site-wide/per-module security audit beyond module-review: dependency CVEs (`composer
audit`, cached Adobe bulletins, optional OSV.dev), secret scanning
(gitleaks/trufflehog/regex fallback), Magento static patterns, Magento coding standard,
cross-module collisions. Never asks for production secrets.

- **Invocation:** `[--scope=module|site|vendor] [--include-magento-core]
  [--format=markdown|json|sarif] [<modules>…]`.
- **Phases:** scope → dependency audit → secret scan → static pattern pass → coding
  standard → cross-module pass → report.
- **Severity:** shared scale, PCI/GDPR-calibrated (secret in code / RCE CVE =
  Critical).
- **Outputs:** `.docs/audits/security-{scope}-{date}.json` + `.sarif` (automated via
  `build-findings.sh`) + `.md` narrative.

### magento2-performance-audit

Static performance pass (N+1, full-collection loads, missing cache identities/
lifetimes, constructor work, hot-path `around` plugins, synchronous HTTP in storefront,
un-batched cron/consumers) with opt-in runtime checks and optional Blackfire parsing.

- **Invocation:** `[--runtime] [--scope=module|site] [--format=…] [<modules>…]`.
- **Phases:** scope → static pass (`scripts/static-perf.sh`) → runtime pass (opt-in;
  indexers, caches, queue backlog, slow log, Redis) → Blackfire (optional) → report.
- **Outputs:** `.docs/audits/perf-{scope}-{date}.json` + `.sarif` + `.md`.

### magento2-debug

Read-only diagnostics, mode-driven: `logs` (signature-grouped triage), `trace`
(observers per event / plugins per method / preference per class, with a Mermaid call
chain), `di` (graph for a type), `slow-queries` (pattern-grouped with index hints),
`snapshot` (one-page system state), `xdebug` (config check/toggle).

- **Invocation:** `/magento2-tools:magento2-debug <mode> [--since=…] [--module=…]
  [--format=…] [--save]`.
- **Outputs:** Markdown in conversation; `.docs/debug/{mode}-{date}.md` with `--save`.
- **Related:** routes follow-ups to bug-fix / performance-audit / security-audit; used
  by feature-implement smoke triage.

---

## Lifecycle

### magento2-feature-implement

End-to-end feature orchestrator: elicit → blueprint (gate) → module schema → task plan
(gate) → execute (create/modify/review/test/EAV/GraphQL/validate/deploy tasks) → test
(unit+coverage, then smoke battery with bounded fix loop) → final report. Modes:
`feature`, `hotfix`, `extend` (skip schema/plan phases), `spike` (reduced testing).
Resumable via `.docs/{FeatureName}/plan.md` checkboxes.

- **Invocation:** any "add/build/implement" request; resume with an explicit
  *"resume ./.docs/{FeatureName}"*.
- **Opt-ins:** per-task commits via `--per-task-commits`, a `CLAUDE.md` line, or
  `MAGENTO2_FI_PER_TASK_COMMITS=1`; **test-first (TDD) mode** via `--tdd`,
  `Feature implement: tdd = on`, or `MAGENTO2_FI_TDD=1` (default off, `spike` exempt) —
  behaviour-bearing `M*`/`X*` tasks are written test-first (Phase 4 acceptance criteria
  become the RED test list, `T*` becomes a coverage top-up); production smoke only with
  `Allow smoke on production: true` in `CLAUDE.md`.
- **Outputs:** `.docs/{FeatureName}/` — blueprint, plan, task records, smoke reports,
  final report, optional HTML guides.
- **Related:** delegates to nearly every other skill; smoke findings auto-route to
  bug-fix / debug / performance-audit / security-audit / frontend-create /
  data-migration.

### magento2-bug-fix

Defect remediation: collect → reproduce → RCA (gate) → TDD patch + regression test →
diff review → optional deploy → report. Minimal diff, no scope expansion, `vendor/`
never edited, per-phase `[bug-fix]` commits on a `bugfix/{slug}` branch, never pushes.

- **Invocation:** `"<bug description>"` + optional `--module=`, `--log=`, `--no-deploy`,
  `--severity=`.
- **Outputs:** `.docs/bug-fixes/{slug}/` — collect, reproduction, rca, report.
- **Redirects:** schema changes → feature-implement `extend` mode; data repairs →
  data-migration patch; investigation → debug.

### magento2-deploy

Safe deploy: pre-flight (gate on failure) → env-specific plan (approval gate) →
ordered execution with per-step capture → per-step rollback recipes → smoke tests →
Markdown+JSON report. Production: flag + interactive confirm + maintenance window +
di:compile/static-deploy; snapshot offered (use `--include-db` for non-lossy
`setup:upgrade` rollback).

- **Invocation:** `[--env=local|staging|production] [--strict] [--auto] [--snapshot]
  [--full] [--validate-only] [--i-know-what-im-doing] <modules>…`.
- **Outputs:** `.docs/deployments/{ts}-{env}.md|.json` (+ snapshot tarball).
- **Related:** called by feature-implement (D*), bug-fix (Phase 6), module-upgrade,
  release (`--validate-only --strict`).

### magento2-module-upgrade

Bring a module to a newer Magento/PHP target. Scanners (Adobe UCT, Rector,
PHPCS-Magento2, deprecation-map AST, composer constraints, PHPStan) derive the change
list; findings classified auto-fixable / manual-fixable / bc-break; plan approval gate;
per-change commits; BC breaks documented in `UPGRADE.md` rather than silently fixed.

- **Invocation:** `--to-magento=X.Y.Z --to-php=X.Y [--scan-only] [--auto-fix]
  [--include-bc-breaks] <modules>`.
- **Outputs:** `.docs/upgrades/{Module}-{from}-to-{to}-{date}.md|.json`; module
  `UPGRADE.md`.

### magento2-release

Cut a module release: version from conventional commits (path-filtered, downgrade
guard) → validation via `deploy --validate-only --strict` → composer/CHANGELOG bump →
module-prefixed tag → push gate (type `release`) → optional GitHub Release → publish
notes (Packagist/Satis/VCS/Marketplace; usually a no-op for internal modules).

- **Invocation:** `[--version=X.Y.Z] [--no-publish] [--no-github-release] [--dry-run]
  <Vendor>_<Module>`.
- **Outputs:** updated `composer.json`/`CHANGELOG.md`, tag
  `{Vendor}_{Module}-{Version}`, `.docs/releases/{Module}-{Version}.md`.

### magento2-i18n

Translation extraction and merge: collect phrases (Magento CLI or regex fallback),
merge into locale CSVs preserving existing translations byte-for-byte, move removed
phrases to `<locale>.obsolete.csv`, validate placeholders (`%1`/`%2` parity) and CSV
well-formedness. Optional machine translation.

- **Invocation:** `[--locales=en_US,de_DE,…] [--machine-translate]
  [--module=<Vendor>_<Module>]`.
- **Outputs:** updated `i18n/{locale}.csv` files; `.docs/i18n/{Module}-{date}.md`.

## Choosing between adjacent skills

Several skills have adjacent triggers. The `description` frontmatter encodes these boundaries so
Claude routes correctly; they are summarized here for contributors. When you add or reword a
description, keep its cross-references intact — `tests/test-routing-discriminators.sh` enforces the
key ones.

| If the request is… | Use | Not |
|---|---|---|
| A single admin edit form | `magento2-adminhtml-form` | `magento2-feature-implement` / `magento2-module-create` |
| A GraphQL query/mutation/type | `magento2-graphql-create` | `magento2-feature-implement` / `magento2-module-create` |
| A single product/customer/category attribute | `magento2-eav-attribute` | `magento2-module-create` / `magento2-data-migration` |
| Bulk/reference data seeding, M1 import, transforms | `magento2-data-migration` | `magento2-eav-attribute` |
| A new module/extension scaffold | `magento2-module-create` | `magento2-feature-implement` (unless multi-surface) |
| Multi-step / multi-surface / unclear-scope work | `magento2-feature-implement` | the single sub-skills above |
| Per-module architecture/quality review | `magento2-module-review` | `magento2-security-audit` / `magento2-performance-audit` |
| Security depth (CVEs, secrets, EQP, cross-module/repo) | `magento2-security-audit` | `magento2-module-review` |
| Performance depth (N+1, caching, ranked findings) | `magento2-performance-audit` | `magento2-debug` |
| Read-only log/DI/queue inspection, one session | `magento2-debug` | `magento2-performance-audit` |
