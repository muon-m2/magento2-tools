# magento2-tools

A Claude Code **plugin** of skills for end-to-end Magento 2 engineering: scaffolding,
review, testing, bug-fixing, deployment, auditing, and more — built around a shared
context-resolver so the same toolkit adapts to any project and environment.

🌐 **Website:** <https://muon-m2.github.io/magento2-tools/>

## Install

```
/plugin marketplace add muon-m2/magento2-tools
/plugin install magento2-tools@muon-m2 --scope user
```

`--scope user` makes it available in every project. Use `--scope project` to pin it to
one repo. Skills are then invoked namespaced, e.g. `magento2-tools:fix`.

**Team auto-enable** — commit to a project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "muon-m2": { "source": { "source": "github", "repo": "muon-m2/magento2-tools" } }
  },
  "enabledPlugins": { "magento2-tools@muon-m2": true }
}
```

On folder-trust, Claude Code offers to install the marketplace and enables the plugin —
zero manual steps for teammates.

## First steps (try it on your project)

New to the toolkit? Open any Magento 2 project in Claude Code and try these — all
read-only, nothing is modified:

```
# 1. Let the toolkit learn your project (vendor, runner, versions, theme, tools)
Resolve the Magento 2 project context

# 2. Severity-ranked review of one of your modules, with file:line evidence
Quick review of the module app/code/<Vendor>/<Module>

# 3. One-page health snapshot: indexers, caches, queues, cron, versions
/magento2-tools:snapshot
```

Skills are triggered by plain language (*"fix this checkout bug"*, *"scaffold a module
for order export"*) or invoked explicitly with flags
(`/magento2-tools:deploy --env=staging Acme_OrderExport`). Code-writing skills
always stop at an approval gate (blueprint, RCA, deploy plan, release push) before
changing anything; reports land in your project's `.docs/` folder. The full
walkthrough lives in [docs/getting-started.md](docs/getting-started.md).

## Documentation

Developer documentation lives in [`docs/`](docs/README.md):

| Doc | What it covers |
|-----|----------------|
| [Getting started](docs/getting-started.md) | Install, first run, safety model, first commands for first-time users |
| [Daily workflows](docs/daily-workflows.md) | Day-to-day recipes: bug fixes, features, reviews, tests, deploys, audits, releases |
| [New project guide](docs/new-project-guide.md) | Bootstrapping a new Magento 2 project with the toolkit, from `CLAUDE.md` to first release |
| [Flows and scenarios](docs/flows-and-scenarios.md) | Architecture, per-skill phase flows with diagrams, approval-gate map, artifact map, end-to-end scenarios |
| [Skills reference](docs/skills-reference.md) | Per-skill quick reference: invocation, flags, phases, outputs |
| [Configuration](docs/configuration.md) | Context resolver, overrides, `CLAUDE.md` hints, CI integration (validate-only deploys, SARIF) |

## Skills

36 skills under `skills/`, each self-contained (`SKILL.md` + `references/` +
`scripts/` + `templates/`). Per-skill flags, phases, and outputs are documented in
[docs/skills-reference.md](docs/skills-reference.md).

| Skill | Purpose |
|-------|---------|
| `context` | Resolves project context (vendor, runner, Magento root/version, tools). The hub every other skill delegates environment questions to. Owns the shared findings emitters (`emit-findings.sh` / `emit-json.sh` / `emit-sarif.sh`). |
| `module-create` | Scaffold a new module. |
| `review` | Review a module / diff against standards. Reuses the hub's shared JSON/SARIF emitters. |
| `feature` | End-to-end feature workflow; orchestrates most other skills. |
| `fix` | Reproduce → RCA → minimal TDD fix → regression test → review → deploy. |
| `deploy` | Pre-flight validation, ordered deploy, rollback. |
| `test-generate` | Generate unit/integration/API/MFTF tests. |
| `upgrade` | BC-break detection, deprecation maps. |
| `security` | CVE + secret + EQP static scan. |
| `perf-audit` | N+1, caching, indexer/queue review. |
| `debug` | Investigate logs / DI graph when reproduction is hard. |
| `eav-attribute` | Add EAV attributes idempotently. |
| `graphql` | Schema-first GraphQL surfaces. |
| `webapi` | Contract-first REST / Web-API surfaces for an existing entity (webapi.xml routes + service contract + DTO + repository + di.xml + acl.xml + functional tests). |
| `frontend` | Themes, components, email templates. |
| `data-migration` | Idempotent data patches / importers. |
| `release` | Version bump, changelog, tag, publish. |
| `i18n` | Translation extraction / locale management. |
| `admin-form` | Scaffold an adminhtml UI-component edit form (form XML + DataProvider + New/Edit/Save/Delete + button blocks). |
| `admin-listing` | Scaffold an adminhtml grid/listing (listing XML + DataProvider + columns + actions + mass actions), paired with `admin-form`. |
| `extension-point` | Wire behaviour onto an existing class: plugin (before/after/around interceptor), observer (events.xml + Observer), or preference. |
| `system-config` | Add admin Stores → Configuration settings: system.xml + config.xml + ACL + optional source/backend models + typed Config reader. |
| `cli-command` | Scaffold a bin/magento console command or cron job on an existing module: Symfony Command + CommandList registration, or crontab.xml + job class with a delegate service. |
| `message-queue` | Scaffold an async message-queue surface on an existing module: communication.xml topic + queue_topology/publisher/consumer.xml bindings + a typed message DTO + publisher + idempotent consumer. |
| `lint` | Run the static-analysis gate (phpcs, phpstan, phpmd, php-cs-fixer, rector) and apply safe auto-fixes; emit residual violations as ranked findings (JSON + SARIF). |
| `docs` | Generate or refresh a module's technical documentation from its own code — public @api surface, events, plugins, REST/GraphQL, DB schema, and more. For a module with REST routes it also emits OpenAPI 3.1, a JetBrains `.http` file, and a Postman collection under `docs/api/`. Never modifies source. |
| `indexer` | Scaffold a custom indexer + materialized view (mview) on an existing module: indexer.xml, mview.xml subscriptions, an ActionInterface indexer class + batched action class. |
| `widget` | Scaffold a CMS widget on an existing module: widget.xml declaration (parameters, containers, templates) + Magento_Widget dependency + a BlockInterface block with typed parameter accessors and a parameter-aware cache key + a theme-neutral phtml + unit/integration tests. |
| `marketplace` | Assess an existing module's Adobe Marketplace / EQP submission readiness: composer metadata, licensing, structure, MFTF tests, docs, packaging hygiene. Read-only; emits a tiered scored report (JSON + SARIF, `outputKind=marketplace`). |
| `a11y-audit` | Audit a module's/theme's storefront templates for WCAG 2.1 Level AA issues (alt text, labels, ARIA, headings, keyboard, contrast). Static-first; optional pa11y runtime pass. Read-only; emits ranked findings (JSON + SARIF, `outputKind=accessibility`). |
| `breeze-theme` | Scaffold a Swissup Breeze (Breezefront) child theme: theme.xml `Swissup/breeze-*` parent + registration.php + composer.json + `web/css/breeze/_default.less` (`@critical`) + breeze-only layout. |
| `breeze-adapt` | Adapt an existing module to Breeze by generating a separate companion `{Vendor}_{Module}Breeze` module (breeze.js JS registration + `web/css/breeze` LESS + Cash `$.widget` stubs). Never edits the target. |
| `breeze-compat` | Read-only static audit of a module's Breeze compatibility (RequireJS/Knockout/jQuery-widget/mixins). Emits ranked findings (JSON + SARIF, `outputKind=compatibility`) + a verdict. |
| `audit` | Read-only release-readiness orchestrator: fans out every findings dimension (`review` + `security` + `perf-audit` + `lint` + `a11y-audit` + `marketplace` + `breeze-compat`) in parallel and consolidates them into ONE deduplicated, severity-ranked report + one merged SARIF (`outputKind=audit`). The *inspect* counterpart to `feature`. |
| `triage` | Read-only: turns a findings document into an ordered, approvable remediation plan — every finding fingerprinted, waiver-checked, confidence-gated, routed to its owning skill through the shared routing matrix, and grouped into dependency-ordered batches (`outputKind=remediation`). *audit finds; triage decides who fixes.* |
| `remediate` | Write half of the remediation cycle: executes an approved `triage` plan batch by batch through the skill that owns each finding — one approval per batch, one commit per finding (`Closes-Finding` trailer), `gate: manual` items reported as human actions rather than executed, then `audit --compare` to prove what closed. Never edits `vendor/`. |

### Dependency graph

`context` is the universal leaf — every other skill resolves environment through
it and it depends on nothing. It also owns the shared findings emitters
(`emit-findings.sh` → `emit-json.sh` / `emit-sarif.sh`) and the single findings engine
(`findings-lib.sh`) that every findings-emitting skill reuses. There are two
orchestrators, and they are counterparts: `feature` **builds**, `audit` **inspects**.

`A ──► B` means **A invokes B as part of its own workflow**. Callers are not listed as
edges (`deploy` is invoked by four skills; it invokes only `context`), and neither is
*fix routing* — where a read-only skill hands findings to the skill that owns the
remediation. Routing is listed separately below.

```
context           ◄── (called by all others; depends on nothing;
                       owns the shared findings emitters + findings-lib.sh)

feature           ──► module-create, review, deploy, test-generate, docs,
                      eav-attribute, graphql, extension-point, system-config,
                      cli-command, message-queue, lint          (Phase 5 task types)
                      fix, debug, perf-audit, security, frontend,
                      data-migration                            (Phase 6B smoke-fix routing)

audit             ──► review, security, perf-audit, lint, a11y-audit,
                      marketplace, breeze-compat   (fans out, then consolidates;
                                                    reuses emit-findings.sh)

triage            ──► context                      (+ reuses route-finding.sh,
                                                    waivers-lib.sh, emit-findings.sh;
                                                    reads audit's document, writes a plan)

remediate         ──► context, triage, audit         (loads/creates the plan, then
                      fix, upgrade, extension-point,   proves closure with --compare)
                      indexer, message-queue, webapi,
                      graphql, admin-form, admin-listing,
                      system-config, data-migration,
                      frontend, breeze-adapt, i18n,
                      test-generate, lint, docs        (one batch per owner, in the
                                                        plan's dependency order)

fix               ──► context, review, deploy, data-migration, debug
module-create     ──► context, docs, review
review            ──► context                      (+ reuses emit-json/emit-sarif)
test-generate     ──► context
deploy            ──► context
upgrade           ──► context, test-generate, review
release           ──► context, deploy
i18n              ──► context
docs              ──► context

security          ──► context                      (+ reuses findings-lib.sh)
perf-audit        ──► context                      (+ reuses findings-lib.sh)
lint              ──► context                      (+ reuses findings-lib.sh)
marketplace       ──► context, security            (+ reuses findings-lib.sh)
a11y-audit        ──► context                      (+ reuses findings-lib.sh)
breeze-compat     ──► context                      (+ reuses findings-lib.sh)
debug             ──► context

eav-attribute     ──► context
data-migration    ──► context, review
graphql           ──► context, review, test-generate
webapi            ──► context, module-create, review, test-generate
frontend          ──► context, review, breeze-theme, breeze-adapt, breeze-compat
admin-form        ──► context, module-create, review, test-generate
admin-listing     ──► context, module-create, review, test-generate
system-config     ──► context, module-create, review, admin-form
cli-command       ──► context, module-create, review, system-config
extension-point   ──► context, module-create, review
message-queue     ──► context, module-create, review
indexer           ──► context, module-create, review, perf-audit
widget            ──► context, module-create, review
breeze-theme      ──► context
breeze-adapt      ──► context, breeze-compat
```

**Fix routing** (findings hand-off, not invocation): every findings skill routes each
finding to the skill that owns its remediation. The mapping is a contract, not a
judgement call — it lives in `skills/context/references/fix-routing.md` and is resolved
by `skills/context/scripts/route-finding.sh`, which also names the specialist owners
(`extension-point`, `indexer`, `message-queue`, `webapi`, `graphql`, `admin-form`,
`admin-listing`, `breeze-adapt`, `docs`) that a prose table used to funnel into `fix`.
`triage` applies it to a whole report at once and emits the ordered plan, and `remediate`
executes that plan — the owning skills above are *invoked* there, which is why `remediate`
is the one skill whose dependency line is the routing table. When `review` runs in diff mode
*on behalf of* `feature`, `fix`, or `upgrade`, it returns findings to that caller instead of
routing.

## Commands

Thin slash-command shortcuts for common operations. Each forwards your arguments verbatim to the
underlying skill — no behaviour changes, and the write commands keep every approval/production
gate. They are always namespaced:

<!-- BEGIN GENERATED: commands (gen-routing.sh) -->
| Command | Routes to | Use |
|---------|-----------|-----|
| `/magento2-tools:audit` | `audit` | Full release-readiness audit — every findings dimension consolidated into one ranked report + merged SARIF |
| `/magento2-tools:bugfix` | `fix` | Reproduce → root-cause → minimal TDD fix → regression test → review (gated) |
| `/magento2-tools:context` | `context` | Resolve the Magento 2 project context — vendor, runner, versions, theme, tools |
| `/magento2-tools:deploy` | `deploy` | Deploy Magento 2 module.— pre-flight, ordered deploy, rollback (gated) |
| `/magento2-tools:docs` | `docs` | Generate or refresh a module's technical documentation from its own code — README, guides, API references, CHANGELOG scaffold |
| `/magento2-tools:feature` | `feature` | End-to-end Magento 2 feature implementation orchestrator (gated) |
| `/magento2-tools:i18n` | `i18n` | Extract translatable strings and manage locale CSV files for a Magento 2 module |
| `/magento2-tools:lint` | `lint` | Run the static-analysis gate (phpcs, phpstan, phpmd, php-cs-fixer, rector) and apply safe auto-fixes for a Magento 2 module (gated) |
| `/magento2-tools:perf` | `perf-audit` | Performance audit — N+1, caching, indexer/queue review |
| `/magento2-tools:release` | `release` | Release a Magento 2 module — version bump, changelog, tag, publish (gated) |
| `/magento2-tools:remediate` | `remediate` | Execute an approved remediation plan batch by batch through the owning skills — one approval per batch, one commit per finding (gated) |
| `/magento2-tools:review` | `review` | Review a Magento 2 module or diff against standards |
| `/magento2-tools:scaffold` | `module-create` | Entry point for Magento 2 code generation — routes the request to the matching generator skill (defaults to module-create for a whole new module) |
| `/magento2-tools:security` | `security` | Security audit — CVEs, secrets, EQP static rules, cross-module patterns |
| `/magento2-tools:snapshot` | `debug` | One-page Magento 2 health snapshot — indexers, caches, queues, cron, versions |
| `/magento2-tools:test` | `test-generate` | Generate unit, integration, API, JS, or MFTF tests for a Magento 2 module |
| `/magento2-tools:triage` | `triage` | Turn a findings report into an ordered, approvable remediation plan — who fixes what, in what order |
| `/magento2-tools:upgrade` | `upgrade` | Detect BC breaks, deprecations, and required changes when upgrading a Magento 2 module to a new Magento/PHP version (gated) |
<!-- END GENERATED: commands -->

The seven write commands (`deploy`, `bugfix`, `feature`, `release`, `upgrade`, `lint`, `remediate`) are user-invoked
only; the read-only ten (`context`, `snapshot`, `review`, `security`, `perf`, `test`, `i18n`, `audit`, `docs`,
`triage`) may also be auto-suggested.
The `scaffold` dispatcher routes to `module-create` and guides generation to specialist skills.
All arguments/flags are passed straight through to the skill, which is the source of truth for behaviour and gates.

**Subagents or one flow — your choice.** The audit/RCA commands accept `--agents` /
`--inline` (or set `"execution_mode"` in the project's `.claude/m2.json`): `agents`
fans analysis out to the read-only `reviewer`/`explorer` subagents in parallel, `inline`
runs the same steps sequentially in the conversation. Defaults preserve pre-2.0
behaviour (`audit` fans out; everything else runs inline). Approval gates always run in
the main conversation. Contract: `skills/context/references/execution-modes.md`.

**Security scans are live, with no shipped advisory data.** The `security` skill resolves
dependency advisories at scan time (`composer audit`) and Adobe patch state through the
store's own `vendor/bin/patch-status`; offline runs state "advisories were NOT checked"
in `scanner_errors` instead of silently passing.

## Per-project environment overrides

`context` auto-detects the runner (Docker vs bare PHP) and the Magento root.
For non-standard setups, override detection (env var wins over file):

```bash
export M2_PHP_CONTAINER=my-php-container   # name of the running PHP container
export M2_MAGENTO_ROOT=src                 # Magento root (default: auto-detect "." or "src")
export M2_CACHE_TTL=86400                  # context cache TTL in seconds (0 disables; default 24h)
```

or commit a per-project `.claude/m2.json`:

```json
{ "php_container": "my-php-container", "magento_root": "src" }
```

A configured container that is not running falls through to generic name-pattern
detection. Changing any override busts the resolver cache automatically.

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # this repo doubles as its own marketplace ("muon-m2")
skills/              # 36 skills (auto-discovered by Claude Code)
commands/            # 18 /magento2-tools:<verb> shortcut commands (auto-discovered)
agents/              # first-party read-only subagents: reviewer (per-dimension review) + explorer (code comprehension/tracing)
hooks/               # PreToolUse guard: keeps .docs/ artifacts at the project root
tests/               # contract test harness
scripts/             # release-notes helper (used by .github/workflows/release.yml)
```

Bundled scripts are invoked from SKILL.md as `${CLAUDE_SKILL_DIR}/scripts/<name>` (own
skill) or `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<name>` (cross-skill); the scripts
themselves self-locate via `BASH_SOURCE`, so they are layout-independent.

## Tests

```bash
bash tests/run-all.sh
```

Contract tests cover bash syntax, template lint (PHP/XML/JSON/GraphQL/CSV/JS), SKILL.md
frontmatter validity, cross-reference integrity (including `${CLAUDE_SKILL_DIR}` /
`${CLAUDE_PLUGIN_ROOT}` and `<skill>/…` cross-refs), context-resolver behaviour
(bare/docker runner contract + src-layout/override fixtures), plugin↔marketplace version
sync, skill-version-registry consistency, and golden-output snapshots of the shared findings emitters (`emit-json` / `emit-sarif`). CI additionally runs `shellcheck`. Tests that
need a missing interpreter exit 77 (SKIP) rather than failing.

## Releasing

Bump `.claude-plugin/plugin.json` + `marketplace.json`, convert the CHANGELOG `[Unreleased]`
section to `## [X.Y.Z]`, commit `Release vX.Y.Z`, then push an annotated `vX.Y.Z` tag. The tag push
triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which runs the contract
suite, asserts the tag matches both manifest versions, and publishes a GitHub Release with the
matching CHANGELOG section as its notes (extracted by `scripts/release-notes.sh`). The bump,
CHANGELOG, and tag stay manual.

Also bump the version badge in the [landing page](https://muon-m2.github.io/magento2-tools/)
hero — the `Claude Code plugin · vX.Y.Z` string in `index.html` on the `gh-pages` branch — then
commit and push the updated `gh-pages` branch so the published site matches the release. It is a
static string with no runtime lookup, so it does not update on its own.

## Versioning

Each skill's version lives in its `SKILL.md` frontmatter (`version:`) — the single source
of truth. The table in `skills/context/references/skill-versioning.md` and the README
command table are **generated** (`gen-versions.sh` / `gen-routing.sh` under
`skills/context/scripts/`); contract tests fail when either is stale. The plugin itself
is versioned in `.claude-plugin/plugin.json`; change narrative lives in `CHANGELOG.md`.
