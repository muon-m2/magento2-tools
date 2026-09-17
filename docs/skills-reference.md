# Skills reference

One compact section per skill: what it's for, how to invoke it, key flags, phases,
outputs, and related skills. For narrative flow descriptions see
[Flows and scenarios](flows-and-scenarios.md); for recipes see
[Daily workflows](daily-workflows.md).

All skills are invoked namespaced (`magento2-tools:<skill>`) or by plain
language matching the skill's purpose. Sixteen of them also have a shorter slash-command
alias — see the command table in the [repository README](../README.md#commands) (the
names differ for a few: `/magento2-tools:bugfix` → `fix`, `/magento2-tools:snapshot` →
`debug`, `/magento2-tools:perf` → `perf-audit`, `/magento2-tools:test` →
`test-generate`, `/magento2-tools:scaffold` → `module-create`).

Every skill resolves project context through `context` first (Phase 0) — that is omitted
from the phase lists below.

**Execution mode.** The findings/RCA family — `audit`, `review`, `security`,
`perf-audit`, `a11y-audit`, `marketplace`, and `fix` — accepts `--agents` or `--inline`
on any invocation, with a per-project default from `"execution_mode"` in
`.claude/m2.json`. See [Configuration](configuration.md#execution-modes-agents-vs-inline).

**Output root.** Every artifact-producing skill accepts `--docs-root={path}` to relocate
its output from `.docs/` (see [Configuration](configuration.md#output-conventions)).

---

## Foundation

### context

**Hub/library skill** — resolves vendor prefix, repo layout, edition, Magento/PHP
versions, runner (Docker vs bare PHP), Magento CLI and Composer commands, active theme,
and available quality tools into one JSON document. Consumed by every other skill;
rarely invoked directly.

- **Invocation:** automatic from other skills; directly: *"resolve the Magento context"*; `--no-cache` forces re-resolution.
- **Cache:** `.claude/.cache/context.json`, keyed by the `composer.lock`,
  `composer.json`, `CLAUDE.md`, and `.claude/m2.json` hashes plus the `M2_*` env
  overrides — so changing any override busts it; default TTL 24h (`M2_CACHE_TTL`).
- **Honest gaps:** missing tools are `null`; `runner` is `""` for bare PHP,
  `runner_kind` is `null` only when no PHP environment exists at all; an unrecognised
  `execution_mode` is `null` with the reason in `resolution_source`.
- **Also owns the shared references:** naming conventions, severity scale, findings
  schema (JSON/SARIF), placeholder registry, skill version registry, and the shared
  **test-first (TDD) discipline** (`references/tdd-discipline.md` — the red → green →
  refactor loop and the behaviour/boilerplate line, consumed by `fix`,
  `feature`, `data-migration`, and `eav-attribute`).
- **Scripts:** `scripts/resolve-context.sh` (emit JSON without an LLM pass),
  `scripts/probe-tools.sh`.

---

## Build

### module-create

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
- **Related:** reviewed by `review`; deployed by `deploy`;
  called by `feature` (M* tasks).

### eav-attribute

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
- **Related:** called by `feature` (E* tasks); owns the canonical
  EAV patch templates (module-create's are the simpler variant).

### graphql

Schema-first GraphQL: schema fragment, resolvers (standard / **batch** / paginated),
auth + store-scope checks, DI wiring, unit tests. List-context resolvers are always
batch resolvers (N+1 prevention). Appends to existing `schema.graphqls`, never rewrites.

- **Invocation:** `--module=Acme_Reviews --operation=query|mutation
  --auth=customer|admin|anonymous` (anonymous mutations need justification).
- **Phases:** schema plan → resolver plan (gate) → generate → verify (`xmllint`,
  `php -l`, schema parse when CLI available) → report.
- **Outputs:** `etc/schema.graphqls`, `etc/graphql/di.xml`, `Model/Resolver/…`,
  resolver unit tests.
- **Related:** tests via `test-generate`; reviewed with
  `review --diff`; called by `feature` (G* tasks).

### webapi

Contract-first REST / Web API for an **existing** entity (sibling to graphql):
`webapi.xml` CRUD routes + optional custom-action routes, `Api/{Entity}RepositoryInterface`
service contract, `Api/Data` DTO + search-results interfaces, a full `{Entity}Repository`
(`SearchCriteria` via `CollectionProcessor`), `di.xml` preferences, `acl.xml`, and a
`WebapiAbstract` functional test. Per-route auth scopes (anonymous/self/ACL), exception→HTTP
mapping, extension attributes. Assumes the entity model exists (run `module-create`
first); appends to existing `webapi.xml`/`di.xml`/`acl.xml` rather than overwriting.

- **Invocation:** `--module=Acme_Catalog --entity=Brand --auth=anonymous|self|acl`
  (anonymous routes need justification).
- **Phases:** contract plan → DTO & repository plan (gate) → generate → verify (`xmllint`,
  `php -l`, `review --diff`) → report.
- **Outputs:** `etc/webapi.xml`, `etc/di.xml`, `etc/acl.xml`, `Api/…`, `Model/{Entity}Repository.php`,
  `Test/Api/…`.
- **Related:** tests via `test-generate --types=api`; reviewed with
  `review --diff`; called by `feature` (API tasks).

### frontend

Theme-aware frontend scaffolding: theme, RequireJS module, Knockout component, Alpine
component (Hyva), transactional email template, or static asset — one operation per
invocation, always with the activating layout XML. Append-safe for
`requirejs-config.js` and `email_templates.xml`. Hyva projects get Alpine, not KO.

- **Invocation:** `/magento2-tools:frontend <operation>`.
- **Phases:** operation plan → generate → verify (`xmllint`, `node --check`, project
  linter if present) → report with activation commands.
- **Outputs:** files under the module's `view/frontend/…` or
  `app/design/frontend/{Vendor}/{Theme}/`.

### data-migration

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

### audit

Read-only **release-readiness orchestrator** — the umbrella over this whole group. Runs every
findings dimension (architecture/quality/security review via the `reviewer` agent, plus
the scripted `security`, `perf-audit`, `lint`,
and — where the surface warrants — `a11y-audit`, `marketplace`,
`breeze-compat`), fans them out in parallel, then **consolidates** them into ONE
deduplicated, severity-ranked report + one merged SARIF. The *inspect* counterpart to
`feature`. For a single dimension, invoke that dimension's skill directly.

- **Invocation:** `[--scope=module|site] [--include=<dim,dim>] [--exclude=<dim,dim>]
  [--release-readiness] <Vendor>_<Module>`.
- **Phases:** context → dimension selection (surface-adaptive) → parallel fan-out (reviewer
  subagents + scripted `build-findings.sh` scanners) → consolidate (`scripts/consolidate.sh`:
  dedup by `file:line`+category+title, severity-rank, verdict/score) → consolidated report.
- **Consolidation:** duplicates across dimensions collapse to one finding tagged with every
  dimension that raised it, keeping the highest severity; overall `PASS`/`CONDITIONAL`/`FAIL`
  verdict + score.
- **Outputs:** `.docs/audits/{Vendor}_{Module}-audit-{date}.md|.json|.sarif` (`outputKind=audit`);
  per-dimension artifacts remain under their own category dirs.
- **Related:** dispatches `review` + every specialist audit; `triage` turns its
  document into an ordered remediation plan.

---

### triage

Read-only **consume half** of the findings cycle — it takes the document `audit` (or any
findings skill) produced and turns it into an ordered, approvable remediation plan. It never
re-scans and never edits code. *audit finds; triage decides who fixes.*

- **Invocation:** `[--from=<report.json|dir>] [--waivers=<path>] [--severity=<min>]
  [--include=<owner,…>] [--exclude=<owner,…>] [--docs-root=<path>] [<Vendor>_<Module>]`.
  `--from` defaults to the newest `.docs/audits/*-audit-*.json`.
- **Phases:** context → ingest (JSON only; major `schemaVersion` mismatch is a hard error)
  → fingerprint + dedupe across dimensions → waivers → confidence gate → route
  (`scripts/build-plan.sh` calls `context/scripts/route-finding.sh` per finding)
  → batch → emit + present for approval.
- **Buckets:** `batches[]` (the execution order), `waived[]` (unexpired waivers, with reason
  and author — reported, never counted closed), `verify_first[]` (`confidence != confirmed`,
  or an **expired** waiver, which resurfaces the finding), `unrouted[]` (no matrix row — never
  silently defaulted to `fix`), plus `stale_waivers[]` and `inputs[]`.
- **Batch order** is a dependency order, not a priority order: `upgrade` → `fix` →
  structural owners → `frontend` → `i18n` → `test-generate` → `lint` → `docs`. `lint` runs
  last so it formats what the run produced; a Critical `lint` finding still runs last.
- **Waivers:** `.docs/findings/waivers.yml`, keyed on each finding's `fingerprint` (a hash of
  producer/category/title/file/snippet — *not* the line number, so it survives the patch).
  A gitignored or untracked waivers file warns that the suppressions will reset.
- **Outputs:** `.docs/remediation/{Vendor}_{Module}-plan-{date}.md|.json|.sarif`
  (`outputKind=remediation`).
- **Related:** `audit` (produces the input); `remediate` (executes the plan);
  the owning skills each batch routes to.

---

### lint

Action skill — run the full static-analysis gate (phpcs Magento2, phpstan, phpmd,
php-cs-fixer, rector dry-run) over a module or diff and **apply safe auto-fixes to
green**, reporting residual violations as ranked findings. Use when you need to *fix*
coding-standard violations or make a module pass the CI gate. For an architecture/quality
review without fixing, use `review`.

- **Invocation:** `[--module=<Vendor>_<Module>] [--diff [<ref>]] [--scope=module|site]
  [<files>…]`.
- **Phases:** context resolution (tools probe) → scope → read-only analysis pass
  (run-analysis.sh, Phase 2) → **approval gate** (present fix plan, wait for "proceed")
  → apply safe fixes (phpcbf, php-cs-fixer, safe rector, Phase 3) → re-run analysis
  (Phase 4) → report (Phase 5).
- **Safe auto-fixes:** phpcbf (all PHPCS whitespace/formatting), php-cs-fixer
  (`@PSR12` + safe rules), rector safe sets (void return types, unused vars, union types
  on PHP ≥ 8.0). Risky rector rules are proposed only. Vendor/generated/var are never
  touched.
- **Outputs:** `.docs/quality/{Vendor}_{Module}-quality-{date}.md` + JSON
  `.docs/quality/quality-{scope}-{date}.json` + SARIF (via shared `build-findings.sh`,
  `outputKind=quality`).
- **CI gate:** `references/ci-integration.md`; SARIF uploads to GitHub Code Scanning;
  `--diff origin/main` for PR gating.
- **Related:** `review` (read-only architecture review, no fixing);
  `security` (deeper security scan); `fix` (defects needing
  RCA rather than style fixes).

**Routing table (when to use which quality skill):**

| Intent | Skill | Defers to |
|--------|-------|-----------|
| Full release-readiness audit — every dimension, one consolidated report + merged SARIF | `audit` | orchestrates all of the below |
| Run the static toolchain and auto-fix to green (CI gate) | `lint` | `review` |
| Review architecture/quality/security without touching code | `review` | — |
| Deep security scan (CVEs, secrets, EQP) | `security` | `review` |
| Performance profiling (N+1, caching, indexers) | `perf-audit` | — |

---

### review

Static-evidence review of a module (or a diff): architecture, security, persistence,
DI, frontend escaping, ACL/config, cron/queue, APIs, PHPDoc/SOLID/DRY, tests. No
environment assumptions; tools used opportunistically. Reuses the shared JSON/SARIF
emitters owned by the `context` hub.

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
  `.docs/reviews/{Vendor}_{Module}-review-{date}.json` + SARIF sibling.
- **Related:** called by `module-create` / `feature` / `fix` / `upgrade` after every change.

### test-generate

Discovers coverage gaps and generates unit / integration / REST+GraphQL API / Jasmine /
MFTF tests with real assertions. Purely additive — never modifies source. It is the
**backfiller** for code that already exists (including modules with *no* tests); for
*new* behaviour the owning skill writes the test first (see `context`'s
`tdd-discipline.md`), and under `feature`'s TDD mode this skill tops up coverage
on exempt/boilerplate classes rather than authoring the first behaviour test.

- **Invocation:** `[--types=unit,integration,api,js,mftf] [--target-coverage=80]
  [--missing-only] [--overwrite] <Vendor>_<Module>`.
- **Phases:** discovery (`scripts/coverage-gap.sh`) → test plan (gate) → generate from
  templates → verify (`php -l`, `node --check`, `xmllint`; unit tests *run* and fixed)
  → report.
- **Outputs:** tests under the module's `Test/` tree;
  `.docs/tests/{Vendor}_{Module}-coverage-{date}.md`.
- **Related:** called by `feature` (T*/6A), `upgrade` (Phase 5),
  graphql.

### security

Site-wide/per-module security audit beyond `review`: dependency CVEs (`composer
audit`, live; Adobe patch-state via `vendor/bin/patch-status`), secret scanning
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

### marketplace

Read-only Adobe Marketplace / EQP submission readiness audit: composer metadata
completeness, license file + headers, `registration.php` / `etc/module.xml` consistency,
MFTF test presence, README / user-docs, packaging hygiene, and EQP static rules
(delegated to `security`). Emits a tiered scored report with
blockers/warnings/info breakdown. Never modifies code, never packages or uploads.

- **Invocation:** `[--module=<Vendor>_<Module>] [--format=markdown|json|sarif]`.
- **Phases:** context resolution → scope → readiness checks (`scripts/check-readiness.sh`
  + `security` EQP delegation) → report.
- **Severity:** blocker = `critical`/`high`, warning = `medium`, info = `low`/`info`.
  0 blockers required for PASS verdict.
- **Outputs:** `.docs/marketplace/{Vendor}_{Module}-readiness-{date}.json` + `.sarif`
  (automated via `build-findings.sh`, `outputKind=marketplace`) + `.md` narrative.
  JSON carries `readiness_score` (0–100) and `readiness_verdict` (PASS/CONDITIONAL/FAIL).
- **Related:** `security` (deep CVE/secret/EQP static scan);
  `release` (version bump, tag, publish).

**Routing table (when to use which quality/submission skill):**

| Intent | Skill | Defers to |
|--------|-------|-----------|
| Assess EQP submission readiness (metadata, docs, packaging) | `marketplace` | `security` / `release` |
| Deep CVE + secret + EQP static scan | `security` | `review` |
| Version bump, changelog, tag, publish | `release` | — |
| Audit storefront templates for WCAG/a11y issues | `a11y-audit` | `frontend` / `review` |

---

### a11y-audit

Read-only WCAG 2.1 Level AA audit of a module's or theme's storefront templates:
missing alt text, unlabelled form controls, ARIA misuse, heading-order breaks,
keyboard/tab-index problems, and LESS color-contrast heuristics. Static-first (no
running Magento needed); optional opt-in pa11y runtime pass. Never modifies templates.

- **Invocation:** `[--module=<Vendor>_<Module>] [--theme=<Vendor>/<Theme>]
  [--runtime --url=<storefront-url>] [--format=markdown|json|sarif]`.
- **Phases:** context resolution (theme detection via `context`) → scope →
  static scan (`scripts/scan-templates.sh`) → optional pa11y runtime pass (opt-in;
  requires `--runtime`, `--url`, and `pa11y` in `{ctx.tools}`) → report.
- **Severity:** `high` = missing alt/label/accessible text; `medium` = heading order,
  ARIA misuse, contrast heuristic, positive tabindex; `low` = missing lang; `info` =
  runtime pass skipped.
- **Theme-aware:** adapts Luma (Knockout/LESS) vs. Hyva (Alpine/Tailwind) template
  patterns via `{ctx.theme}` from `context`.
- **Outputs:** `.docs/accessibility/{Vendor}_{Module}-a11y-{date}.json` + `.sarif`
  (automated via `build-findings.sh`, `outputKind=accessibility`) + `.md` narrative.
- **Related:** `frontend` (build accessible frontend assets);
  `review` (general module quality review).

---

### perf-audit

Static performance pass (N+1, full-collection loads, missing cache identities/
lifetimes, constructor work, hot-path `around` plugins, synchronous HTTP in storefront,
un-batched cron/consumers) with opt-in runtime checks and optional Blackfire parsing.

- **Invocation:** `[--runtime] [--scope=module|site] [--format=…] [<modules>…]`.
- **Phases:** scope → static pass (`scripts/static-perf.sh`) → runtime pass (opt-in;
  indexers, caches, queue backlog, slow log, Redis) → Blackfire (optional) → report.
- **Outputs:** `.docs/audits/perf-{scope}-{date}.json` + `.sarif` + `.md`.

### debug

Read-only diagnostics, mode-driven: `logs` (signature-grouped triage), `trace`
(observers per event / plugins per method / preference per class, with a Mermaid call
chain), `di` (graph for a type), `slow-queries` (pattern-grouped with index hints),
`snapshot` (one-page system state), `xdebug` (config check/toggle).

- **Invocation:** `/magento2-tools:debug <mode> [--since=…] [--module=…]
  [--format=…] [--save]`.
- **Outputs:** Markdown in conversation; `.docs/debug/{mode}-{date}.md` with `--save`.
- **Related:** routes follow-ups to `fix` / `perf-audit` / `security`; used
  by `feature` smoke triage.

---

## Lifecycle

### feature

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
  `fix` / `debug` / `perf-audit` / `security` / `frontend` /
  `data-migration`.

### fix

Defect remediation: collect → reproduce → RCA (gate) → TDD patch + regression test →
diff review → optional deploy → report. Minimal diff, no scope expansion, `vendor/`
never edited, per-phase `[bug-fix]` commits on a `bugfix/{slug}` branch, never pushes.

- **Invocation:** `"<bug description>"` + optional `--module=`, `--log=`, `--no-deploy`,
  `--severity=`.
- **Outputs:** `.docs/bug-fixes/{slug}/` — collect, reproduction, rca, report.
- **Redirects:** schema changes → `feature` `--mode=extend`; data repairs →
  data-migration patch; investigation → debug.

### deploy

Safe deploy: pre-flight (gate on failure) → env-specific plan (approval gate) →
ordered execution with per-step capture → per-step rollback recipes → smoke tests →
Markdown+JSON report. Production: flag + interactive confirm + maintenance window +
di:compile/static-deploy; snapshot offered (use `--include-db` for non-lossy
`setup:upgrade` rollback).

- **Invocation:** `[--env=local|staging|production] [--strict] [--auto] [--snapshot]
  [--full] [--validate-only] [--i-know-what-im-doing] <modules>…`.
- **Outputs:** `.docs/deployments/{ts}-{env}.md|.json` (+ snapshot tarball).
- **Related:** called by `feature` (D*), `fix` (Phase 6), `upgrade`,
  release (`--validate-only --strict`).

### upgrade

Bring a module to a newer Magento/PHP target. Scanners (Adobe UCT, Rector,
PHPCS-Magento2, deprecation-map AST, composer constraints, PHPStan) derive the change
list; findings classified auto-fixable / manual-fixable / bc-break; plan approval gate;
per-change commits; BC breaks documented in `UPGRADE.md` rather than silently fixed.

- **Invocation:** `--to-magento=X.Y.Z --to-php=X.Y [--scan-only] [--auto-fix]
  [--include-bc-breaks] <modules>`.
- **Outputs:** `.docs/upgrades/{Module}-{from}-to-{to}-{date}.md|.json|.sarif` (JSON + SARIF
  via the shared hub emitter); module `UPGRADE.md`.

### release

Cut a module release: version from conventional commits (path-filtered, downgrade
guard) → validation via `deploy --validate-only --strict` → composer/CHANGELOG bump →
module-prefixed tag → push gate (type `release`) → optional GitHub Release → publish
notes (Packagist/Satis/VCS/Marketplace; usually a no-op for internal modules).

- **Invocation:** `[--version=X.Y.Z] [--no-publish] [--no-github-release] [--dry-run]
  <Vendor>_<Module>`.
- **Outputs:** updated `composer.json`/`CHANGELOG.md`, tag
  `{Vendor}_{Module}-{Version}`, `.docs/releases/{Module}-{Version}.md`.

### i18n

Translation extraction and merge: collect phrases (Magento CLI or regex fallback),
merge into locale CSVs preserving existing translations byte-for-byte, move removed
phrases to `<locale>.obsolete.csv`, validate placeholders (`%1`/`%2` parity) and CSV
well-formedness. Optional machine translation.

- **Invocation:** `[--locales=en_US,de_DE,…] [--machine-translate]
  [--module=<Vendor>_<Module>]`.
- **Outputs:** updated `i18n/{locale}.csv` files; `.docs/i18n/{Module}-{date}.md`.

---

## Adminhtml UI

### admin-form

Scaffold an adminhtml UI-component edit form: declarative `{entity}_form.xml`, DataProvider
(`AbstractDataProvider` + `DataPersistorInterface`), New/Edit/Save/Delete controllers, and
required button blocks, wired to an existing listing. Bakes in the five-name blank-form
naming contract. Open Source-compatible; flags Commerce-only features.

- **Invocation:** *"scaffold an admin edit form for Entity in Acme_Module"*;
  `--module=Acme_Module --entity=Entity`.
- **Phases:** resolve context → plan (gate) → **test-first** (failing test before form code)
  → generate (form XML + DataProvider + controllers + buttons) → verify (`php -l`,
  `xmllint`, phpcs) → report with `setup:upgrade` command.
- **Outputs:** `view/adminhtml/ui_component/{entity}_form.xml`, `Model/DataProvider.php`,
  controllers under `Controller/Adminhtml/{Entity}/`, layout XML, `Block/Adminhtml/…`
  button blocks; `.docs/adminhtml/{Module}-form-{date}.md`.
- **Related:** sibling `admin-listing` (the grid); reviewed by
  `review`; called by `feature` (M* tasks).

### admin-listing

Scaffold an adminhtml UI-component grid/listing: declarative `{entity}_listing.xml`,
DataProvider (`AbstractDataProvider` default; optional SearchResult for joins), columns,
actions column, mass-action controllers, and an `Index` controller, wired to an existing
edit form. Bakes in the 5-place listing naming contract (the empty-grid pitfall). Reuses
existing routes/ACL/menu from `admin-form` when present.

- **Invocation:** *"scaffold an admin grid for Entity in Acme_Module"*;
  `--module=Acme_Module --entity=Entity`.
- **Phases:** resolve context → plan (gate) → **test-first** (failing test before listing
  code) → generate (listing XML + DataProvider + actions column + mass-action controllers
  + Index controller) → verify (`php -l`, `xmllint`, phpcs) → report with `setup:upgrade`
  command.
- **Outputs:** `view/adminhtml/ui_component/{entity}_listing.xml`, `Model/ResourceModel/{Entity}/Grid/Collection.php`
  or DataProvider, `Controller/Adminhtml/{Entity}/Index.php` and mass-action controllers,
  layout XML; `.docs/adminhtml/{Module}-listing-{date}.md`.
- **Related:** sibling `admin-form` (the edit form); reviewed by
  `review`; called by `feature` (M* tasks).

### system-config

Add admin Stores → Configuration settings to an **existing** module: `system.xml`
section/group/field declarations, `config.xml` defaults, `acl.xml` resource, optional
source and backend models, and a typed `Config` reader that wraps `ScopeConfigInterface`.
Handles all field types (text, select, multiselect, obscure/encrypted). Config paths
follow the `{vendor_lower}_{module_lower}/{group}/{field}` convention.

- **Invocation:** *"add a config toggle for Acme_Checkout"*;
  `--module=Acme_Checkout --section=acme_checkout --group=general --field=enable --type=select`.
- **Phases:** resolve context → resolve inputs (section/group/fields table) → plan (gate) →
  **test-first** (3A: mock-based unit test for typed reader + source model tests) → generate
  (system.xml + config.xml + acl.xml + optional source/backend models + typed reader) →
  verify (`php -l`, `xmllint`, `review --diff`) → report.
- **Outputs:** `etc/adminhtml/system.xml`, `etc/config.xml`, `etc/acl.xml`,
  optional `Model/Config/Source/{SourceName}.php` and `Model/Config/Backend/{BackendModelName}.php`,
  `Model/Config.php` (typed reader), `Test/Unit/Model/ConfigTest.php`;
  `.docs/system-config/{Module}-{section}-{date}.md`.
- **Related:** use `module-create` first if the module does not exist; for an
  admin **data** edit form use `admin-form`; reviewed by `review`.

### cli-command

Add a `bin/magento` console command or a cron job to an **existing** module. Two modes:
**command** (Symfony `Command` subclass + `CommandList` DI registration + arguments/options
+ `Cli::RETURN_*` exit codes) and **cron** (`crontab.xml` job declaration + job class with
a delegate service; fixed `<schedule>` or `<config_path>` schedule). Business logic always
lives in the injected service class.

- **Invocation:** *"add a CLI command to sync orders in Acme_Orders"*;
  *"add a cron job to Acme_Orders to run every 15 minutes"*;
  `--mode=command --module=Acme_Orders --class=SyncOrdersCommand --name=acme:orders:sync`;
  `--mode=cron --module=Acme_Orders --class=SyncOrders --job=acme_orders_sync --schedule="*/15 * * * *"`.
- **Phases:** resolve context (hard-stop if module absent — offer `module-create`)
  → resolve inputs (mode-specific table) → plan (gate) → **test-first** (3A: `CommandTester`
  unit test for command mode; idempotency + delegate-once test for cron mode) → generate
  from templates → verify (`php -l`, `xmllint`, `review --diff`) → report.
- **Outputs:** `Console/Command/{CommandClass}.php` + `etc/di.xml` (command mode) or
  `Cron/{CronJobName}.php` + `etc/crontab.xml` (cron mode) + unit tests;
  `.docs/cli-commands/{Vendor}_{Module}-{mode}-{slug}-{date}.md`.
- **Related:** use `module-create` first if the module does not exist; pair with
  `system-config` when the cron schedule should be configurable from admin.

### extension-point

Wire behaviour onto an **existing** Magento 2 class without editing it. Three modes:
plugin (before/after/around interceptor + `di.xml`), observer (`events.xml` + Observer
class), or preference (swap an interface/class binding). Chooses the lightest mechanism
for the use case. Refuses to plugin `final`/`private`/`static` methods or data
interfaces.

- **Invocation:** `--mode=plugin --target=Fqcn --method=methodName --type=before|after|around --module=Vendor_Module`;
  `--mode=observer --event=event_name --module=Vendor_Module`;
  `--mode=preference --for=FqcnOfInterface --module=Vendor_Module`.
- **Phases:** resolve context → resolve inputs (mode-specific table) → plan (gate) →
  **test-first** (3A: failing unit test before implementation; preference: integration
  test) → generate from templates → verify (`php -l`, `xmllint`,
  `review --diff`) → report.
- **Outputs:** `Plugin/{PluginName}.php`, `Observer/{ObserverName}.php`, or
  `Model/{EntityName}.php` + the matching `etc/{area}/di.xml` or `etc/{area}/events.xml`;
  unit/integration tests; `.docs/extension-points/{Module}-{mode}-{slug}-{date}.md`.
- **Related:** use `module-create` first if the module does not exist;
  `feature` for multi-surface work that includes interception tasks.

### message-queue

Scaffold a full **async message-queue** surface on an **existing** module: a
`communication.xml` topic (typed DTO `request`), the `queue_topology.xml` /
`queue_publisher.xml` / `queue_consumer.xml` bindings, a `di.xml` DTO `<preference>`, a
typed message interface + model, a `PublisherInterface`-backed publisher, and an
idempotent consumer that decodes the typed message and delegates to a domain handler.
Goes beyond `module-create`'s bare queue stub by wiring all five XML files so the
topic ↔ topology ↔ publisher ↔ consumer ↔ queue chain resolves.

- **Invocation:** *"process orders asynchronously in Acme_Orders"*;
  *"add a queue consumer to Acme_Orders"*;
  `--module=Acme_Orders --topic=acme.orders.order.export --entity=OrderExport --publisher=OrderExportPublisher --consumer=OrderExportConsumer --queue=acme.orders.export --connection=db`.
- **Phases:** resolve context (hard-stop if module absent — offer `module-create`)
  → resolve inputs (topic/DTO/publisher/consumer/connection/queue) → plan (gate) →
  **test-first** (3A: consumer unit test asserts a decoded typed message is handed to the
  handler exactly once, and a redelivery is an idempotent no-op) → generate from templates
  → verify (`php -l`, `xmllint`, `review --diff`) → report.
- **Outputs:** `etc/communication.xml` + `etc/queue_topology.xml` + `etc/queue_publisher.xml`
  + `etc/queue_consumer.xml` + `etc/di.xml` (all merge) + `Api/Data/{EntityName}Interface.php`
  + `Model/{EntityName}.php` + `Model/{PublisherName}.php` + `Model/Consumer/{ConsumerName}.php`
  + the consumer unit test; `.docs/message-queues/{Vendor}_{Module}-{topic}-{date}.md`.
- **Related:** use `module-create` first if the module does not exist (it emits the
  bare queue stub this skill goes beyond).

### indexer

Scaffold a custom indexer and materialized view (mview) onto an **existing** module:
`indexer.xml` declaration, `mview.xml` subscriptions, an indexer class that implements
both `ActionInterface`s (executeFull/executeList/executeRow + Mview execute), and a
dedicated action class that owns all batching and SQL logic. Bakes in idempotent
delete-then-insert batching, the `view_id`/`id` parity contract (the #1 mview bug), and
the ActionInterface name-clash resolution. Use for "add a custom index". Dimensions
(Commerce-only sharding) are noted but not scaffolded by default.

- **Invocation:** *"add a custom indexer to Acme_Catalog"*;
  *"scaffold an mview indexer for product stock in Acme_Catalog"*;
  `--module=Acme_Catalog --class=ProductStock --id=acme_catalog_productstock --source-table=cataloginventory_stock_item --id-column=product_id --target-table=acme_catalog_productstock_index`.
- **Phases:** resolve context (hard-stop if module absent — offer `module-create`)
  → resolve inputs (indexer id/title/description, source table, id column, target table)
  → plan (gate) → **test-first** (3A: mock-based unit test asserting delegation of all
  four methods with correct ids; statelessness check across instances) → generate
  (`indexer.xml` + `mview.xml` + indexer class + action class) → verify (`php -l`,
  `xmllint`, `review --diff`) → report.
- **Outputs:** `etc/indexer.xml` (merge), `etc/mview.xml` (merge),
  `Model/Indexer/{IndexerName}.php`, `Model/Indexer/{IndexerName}Action.php`,
  `Test/Unit/Model/Indexer/{IndexerName}Test.php`;
  `.docs/indexers/{Vendor}_{Module}-{indexer_id}-{date}.md` (includes the
  `indexer:reindex {indexer_id}` and `indexer:set-mode` commands).
- **Related:** use `module-create` first if the module does not exist; to
  review or diagnose existing indexer performance use `perf-audit`.

### widget

Scaffold a CMS widget onto an **existing** module: the `etc/widget.xml` declaration
(parameters, containers, `template` options), the `Magento_Widget` sequence + composer
dependency, a `BlockInterface` block with typed parameter accessors and a parameter-aware
`getCacheKeyInfo()`, a theme-neutral `.phtml` template, and unit + integration tests.
Bakes in the contracts that fail silently — every parameter arrives as a string, blank
parameters are dropped, container templates must name `template` options, and a block
without `BlockInterface` renders as an empty string. Use for "add a widget" / "make X
insertable from Content → Widgets". Not for jQuery-UI `$.widget` / Breeze JS widgets
(`frontend` / `breeze-adapt`).

- **Invocation:** *"add a promo banner widget to Acme_Promo"*;
  *"create a widget.xml for a CMS block picker in Acme_Content"*;
  `--module=Acme_Promo --class=PromoBanner --label="Promo Banner" --description="Configurable promotional banner"`.
- **Phases:** resolve context (hard-stop if module absent — offer `module-create`; read
  the theme for follow-up notes) → resolve inputs (class, id, label, description,
  parameters, containers, email compatibility) → plan (gate) → **test-first** (3A: unit
  test on a mocked `Template\Context` asserting defaults, string coercion and cache-key
  variance; integration test asserting the merged widget config and a frontend render) →
  generate from templates → verify (`php -l`, `xmllint`, `review --diff`) → report.
- **Outputs:** `etc/widget.xml` (merge), `etc/module.xml` (merge), `composer.json` (merge),
  `Block/Widget/{WidgetName}.php`, `view/frontend/templates/widget/{template_name}.phtml`,
  `Test/Unit/Block/Widget/{WidgetName}Test.php`,
  `Test/Integration/Widget/{WidgetName}DeclarationTest.php`;
  `.docs/widgets/{Vendor}_{Module}-{widget_id}-{date}.md` (includes the three placement
  paths — widget instance, WYSIWYG/directive, layout XML — and the cache-clean commands).
- **Related:** use `module-create` first if the module does not exist; JS behaviour for the
  widget goes through `frontend` (Luma/Hyvä) or `breeze-adapt` (Breeze).

### docs

Generate or refresh a module's **technical documentation** from its own code — public
`@api` surface, events fired and observed, plugins, preferences, admin config paths, CLI
commands, cron jobs, REST routes, GraphQL types, DB schema, and module dependencies.
Never modifies source: it extracts facts from real files and writes only under
`{module}/docs/`, `{module}/README.md`, `{module}/CHANGELOG.md` and the run-report root.
Produces up to seven documents inside the module — a `README.md`,
`docs/technical-reference.md`, `docs/developer-guide.md`, conditional `docs/user-guide.md`
(when an admin/storefront surface exists), conditional `docs/api-reference.md` (when REST
routes exist), conditional `docs/graphql-reference.md` (when GraphQL operations exist), and
a `CHANGELOG.md` scaffold — plus a run report under `.docs/docs-generated/`. Illustrative
JSON examples are derived from real DTO/GraphQL field types and captioned accordingly.
Mermaid diagrams are generated only from extracted facts. Screenshot paths are listed in an
appendix; no image embeds are written. Every table entry cites its source file path.

For a module with a non-empty REST surface it additionally emits **machine-readable API
description artifacts** under `{module}/docs/api/` — `openapi.yaml` (OpenAPI 3.1),
`{slug}.http` for the JetBrains HTTP Client plus a secret-free `http-client.env.json`, and a
Postman v2.1 collection + environment. These come from the same static extraction: no
running instance, no network, no credentials, and byte-identical across runs so they are
reviewable in a PR. A blocking nine-assertion secret/privacy gate withholds any artifact
that would carry a credential, a personal identifier, or a concrete hostname, and the
private JetBrains token file is never generated. Output nests under `docs/api/` and never
`{module}/api/`, which on a case-insensitive filesystem is the module's own `Api/`.

- **Invocation:** *"document this module"*; *"generate module docs for Acme_OrderExport"*;
  `--module=Acme_OrderExport`; `--docs=readme,technical-reference,developer-guide,user-guide,api-reference,graphql-reference,changelog,openapi,http-client,postman`
  (default: every applicable doc; conditional docs are omitted automatically when their
  surface is absent). Because the default is "every applicable doc", a module with REST
  routes now produces the three API description artifacts too — re-running the skill on an
  already-documented module will show new untracked files under `docs/api/`.
- **Phases:** resolve context (hard-stop if module absent) → scope (which module, which
  docs) → extract surface via `scripts/extract-surface.sh` + present doc plan with
  api_methods/GraphQL-ops/user-surface counts and which conditional docs will be
  produced or omitted, plus any bare-`array` preflight warnings (gate) → render templates
  and run `scripts/emit-api-artifacts.sh` → verify (no unsubstituted tokens, no empty
  tables, no `![]` embeds, example captions present, Mermaid balanced, YAML/JSON parse, no
  source file touched, nine-assertion secret gate) → report to `.docs/docs-generated/`.
- **Outputs:** `{module}/README.md`, `{module}/docs/technical-reference.md`,
  `{module}/docs/developer-guide.md`, `{module}/docs/user-guide.md` (conditional),
  `{module}/docs/api-reference.md` (conditional), `{module}/docs/graphql-reference.md`
  (conditional), `{module}/CHANGELOG.md` (scaffold); `{module}/docs/api/openapi.yaml`,
  `{module}/docs/api/{slug}.http`, `{module}/docs/api/http-client.env.json`,
  `{module}/docs/api/postman/{slug}.postman_{collection,environment}.json` (all conditional
  on REST routes); `.docs/docs-generated/{Vendor}_{Module}-{date}.md`.
- **Related:** `review` for architecture/quality review (findings, not docs);
  `release` to consume `CHANGELOG.md` after docs are in place;
  `test-generate` for the `webapi.xml` ↔ `openapi.yaml` parity test (a `.php` file,
  which this skill may not write); `lint` to fix the bare `array`
  annotations this skill only warns about.

---

## Breeze (Swissup Breezefront)

Skills for the [Breeze](https://breezefront.com) frontend framework, which replaces
RequireJS/Knockout/jQuery with a Cash-based stack. All three resolve `theme.breeze` from
`context` and refuse to run (printing the install command) when Breeze is not installed.

### breeze-theme

Scaffolds a Breeze child theme: `theme.xml` with a `Swissup/breeze-*` parent, `registration.php`,
`composer.json`, a Breeze-only `breeze_default.xml` layout handle, and Breeze-side overrides in
`web/css/breeze/_default.less` (with the `@critical` guard). Sibling to `frontend`
(generic Luma/Hyva/custom themes); this one is Breeze-specific.

- **Invocation:** `/magento2-tools:breeze-theme [--vendor=Acme] [--name=BreezeCustom] [--parent=breeze-evolution]`.
- **Phases:** context (Breeze gate) → inputs → generate (prefers `bin/magento breeze:theme:create`
  when available) → verify (`xmllint`, `php -l`) → report with activation commands.
- **Outputs:** a registered theme under `app/design/frontend/{Vendor}/{Theme}/`.

### breeze-adapt

Generates a companion `{Vendor}_{Module}Breeze` integration module (sequenced after the target +
`Swissup_Breeze`) holding the Breeze adapter layer for an existing module — `breeze_default.xml` JS
registration, `web/css/breeze/_default.less`, and Cash `$.widget` stubs converted from the target's
RequireJS/Knockout/jQuery widgets. Never edits the target module, so it works on read-only `vendor/`
modules. Pairs with `breeze-compat` (which finds what needs adapting).

- **Invocation:** `/magento2-tools:breeze-adapt <Vendor_Module>`.
- **Phases:** context → scope (optionally audit first; choose surfaces) → generate companion module
  → enable (`setup:upgrade`, static deploy) + `?breeze=1&compat=1` test guidance.
- **Outputs:** `app/code/{Vendor}/{Module}Breeze/` (module.xml, layout, LESS, JS widgets).

### breeze-compat

Read-only static auditor: scans a module for RequireJS/Knockout/jQuery-widget/mixin usage and emits
ranked findings (Markdown + JSON `outputKind=compatibility` + SARIF, via the shared emitters) plus a
verdict — *compatible out-of-box* / *needs Better Compatibility* / *needs manual adapter* — pointing
at `breeze-adapt`.

- **Invocation:** `/magento2-tools:breeze-compat <Vendor_Module>`.
- **Phases:** context → scope → static scan → verdict + findings emit.
- **Outputs:** `.docs/breeze-compat/breeze-compat-{scope}-{date}.{json,sarif}` (+ a Markdown summary).

---

## Choosing between adjacent skills

Several skills have adjacent triggers. The `description` frontmatter encodes these boundaries so
Claude routes correctly; they are summarized here for contributors. When you add or reword a
description, keep its cross-references intact — `tests/test-routing-discriminators.sh` enforces the
key ones.

| If the request is… | Use | Not |
|---|---|---|
| Add a bin/magento console command or cron job | `cli-command` | `module-create` |
| Add an async message queue (topic + consumer) | `message-queue` | `module-create` |
| Add admin store configuration (system.xml + typed reader) | `system-config` | `module-create` / `admin-form` |
| Wire behaviour onto an existing class (plugin/observer/preference) | `extension-point` | `module-create` / `feature` |
| A single admin edit form | `admin-form` | `feature` / `module-create` |
| A GraphQL query/mutation/type | `graphql` | `feature` / `module-create` |
| A single product/customer/category attribute | `eav-attribute` | `module-create` / `data-migration` |
| Bulk/reference data seeding, M1 import, transforms | `data-migration` | `eav-attribute` |
| A new module/extension scaffold | `module-create` | `feature` (unless multi-surface) |
| Multi-step / multi-surface / unclear-scope work | `feature` | the single sub-skills above |
| Per-module architecture/quality review | `review` | `security` / `perf-audit` |
| Security depth (CVEs, secrets, EQP, cross-module/repo) | `security` | `review` |
| Performance depth (N+1, caching, ranked findings) | `perf-audit` | `debug` |
| Read-only log/DI/queue inspection, one session | `debug` | `perf-audit` |
| Generate module technical documentation from code | `docs` | `review` |
| Add a custom indexer + mview | `indexer` | `module-create` / `perf-audit` |
| Add a CMS widget (etc/widget.xml, Content → Widgets, widget directive) | `widget` | `frontend` / `breeze-adapt` |
| Scaffold a Breeze (Swissup) child theme | `breeze-theme` | `frontend` |
| Adapt an existing module to Breeze (companion module) | `breeze-adapt` | `extension-point` / `breeze-compat` |
| Check if a module is Breeze-compatible (static) | `breeze-compat` | `review` / `breeze-adapt` |
| Decide who fixes an existing findings report, and in what order | `triage` | `audit` (*audit finds; triage decides who fixes*) |
