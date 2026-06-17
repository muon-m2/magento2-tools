# magento2-tools

A Claude Code **plugin** of skills for end-to-end Magento 2 engineering: scaffolding,
review, testing, bug-fixing, deployment, auditing, and more — built around a shared
context-resolver so the same toolkit adapts to any project and environment.

## Install

```
/plugin marketplace add muon-m2/magento2-tools
/plugin install magento2-tools@muon-m2 --scope user
```

`--scope user` makes it available in every project. Use `--scope project` to pin it to
one repo. Skills are then invoked namespaced, e.g. `magento2-tools:magento2-bug-fix`.

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
/magento2-tools:magento2-debug snapshot
```

Skills are triggered by plain language (*"fix this checkout bug"*, *"scaffold a module
for order export"*) or invoked explicitly with flags
(`/magento2-tools:magento2-deploy --env=staging Acme_OrderExport`). Code-writing skills
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

18 skills under `skills/`, each self-contained (`SKILL.md` + `references/` +
`scripts/` + `templates/`). Per-skill flags, phases, and outputs are documented in
[docs/skills-reference.md](docs/skills-reference.md).

| Skill | Purpose |
|-------|---------|
| `magento2-context` | Resolves project context (vendor, runner, Magento root/version, tools). The hub every other skill delegates environment questions to. |
| `magento2-module-create` | Scaffold a new module. |
| `magento2-module-review` | Review a module / diff against standards. Owns the shared JSON/SARIF emitters. |
| `magento2-feature-implement` | End-to-end feature workflow; orchestrates most other skills. |
| `magento2-bug-fix` | Reproduce → RCA → minimal TDD fix → regression test → review → deploy. |
| `magento2-deploy` | Pre-flight validation, ordered deploy, rollback. |
| `magento2-test-generate` | Generate unit/integration/API/MFTF tests. |
| `magento2-module-upgrade` | BC-break detection, deprecation maps. |
| `magento2-security-audit` | CVE + secret + EQP static scan. |
| `magento2-performance-audit` | N+1, caching, indexer/queue review. |
| `magento2-debug` | Investigate logs / DI graph when reproduction is hard. |
| `magento2-eav-attribute` | Add EAV attributes idempotently. |
| `magento2-graphql-create` | Schema-first GraphQL surfaces. |
| `magento2-frontend-create` | Themes, components, email templates. |
| `magento2-data-migration` | Idempotent data patches / importers. |
| `magento2-release` | Version bump, changelog, tag, publish. |
| `magento2-i18n` | Translation extraction / locale management. |
| `magento2-adminhtml-form` | Scaffold an adminhtml UI-component edit form (form XML + DataProvider + New/Edit/Save/Delete + button blocks). |

### Dependency graph

`magento2-context` is the universal leaf — every other skill resolves environment through
it and it depends on nothing. `magento2-feature-implement` is the top orchestrator.
`magento2-module-review` owns the shared findings emitters that the audit skills reuse.

```
magento2-context  ◄── (called by all others; depends on nothing)

magento2-feature-implement ──► module-create, module-review, test-generate,
                               eav-attribute, graphql-create, frontend-create,
                               data-migration, deploy, debug, security-audit,
                               performance-audit, bug-fix

magento2-bug-fix           ──► context, module-review, deploy, data-migration, debug
magento2-deploy            ──► context, module-upgrade, release
magento2-module-create     ──► context, module-review
magento2-module-review     ──► context        (+ emit-json.sh / emit-sarif.sh shared here)
magento2-security-audit    ──► context, module-review, module-upgrade
magento2-performance-audit ──► context, module-review, security-audit
magento2-eav-attribute     ──► context, module-create, module-review
magento2-graphql-create    ──► context, module-create, module-review, test-generate
magento2-frontend-create   ──► context, module-create, module-review
magento2-module-upgrade    ──► context, module-review, test-generate
magento2-data-migration    ──► context, module-review
magento2-test-generate     ──► context, module-create
magento2-release           ──► context, deploy
magento2-i18n              ──► context
magento2-debug             ──► context, performance-audit, security-audit
```

## Commands

Thin slash-command shortcuts for common operations. Each forwards your arguments verbatim to the
underlying skill — no behaviour changes, and the write commands keep every approval/production
gate. They are always namespaced:

| Command | Routes to | Use |
|---------|-----------|-----|
| `/magento2-tools:context`  | `magento2-context` | resolve project context (`--no-cache`) |
| `/magento2-tools:snapshot` | `magento2-debug` (snapshot) | one-page health snapshot |
| `/magento2-tools:review`   | `magento2-module-review` | review a module / `--diff` |
| `/magento2-tools:security` | `magento2-security-audit` | security audit |
| `/magento2-tools:perf`     | `magento2-performance-audit` | performance audit |
| `/magento2-tools:deploy`   | `magento2-deploy` | deploy (gated) |
| `/magento2-tools:bugfix`   | `magento2-bug-fix` | reproduce → RCA → fix (gated) |
| `/magento2-tools:feature`  | `magento2-feature-implement` | feature orchestrator (gated) |
| `/magento2-tools:release`  | `magento2-release` | cut a release (gated) |

The four write commands (`deploy`, `bugfix`, `feature`, `release`) are user-invoked only; the
read-only five may also be auto-suggested. All arguments/flags are passed straight through to the
skill, which is the source of truth for behaviour and gates.

## Per-project environment overrides

`magento2-context` auto-detects the runner (Docker vs bare PHP) and the Magento root.
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
skills/              # 18 magento2-* skills (auto-discovered by Claude Code)
commands/            # 9 /magento2-tools:<verb> shortcut commands (auto-discovered)
hooks/               # PreToolUse guard: keeps .docs/ artifacts at the project root
tests/               # contract test harness
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
`${CLAUDE_PLUGIN_ROOT}` and `magento2-<skill>/…` cross-refs), context-resolver behaviour
(bare/docker runner contract + src-layout/override fixtures), plugin↔marketplace version
sync, skill-version-registry consistency, and golden-output snapshots of the shared findings emitters (`emit-json` / `emit-sarif`). CI additionally runs `shellcheck`. Tests that
need a missing interpreter exit 77 (SKIP) rather than failing.

## Versioning

Skill versions and changelog live in
`skills/magento2-context/references/skill-versioning.md`. The plugin itself is versioned
in `.claude-plugin/plugin.json`; see `CHANGELOG.md`.
