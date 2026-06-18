# Getting started

This guide takes you from zero to your first useful results with `magento2-tools` —
without changing a single line of your project.

## What this is

`magento2-tools` is a **Claude Code plugin**: a set of 20 *skills* (structured,
reviewable workflows) that teach Claude Code how to do end-to-end Magento 2 engineering
the way an experienced Magento developer would — with reproduction before fixes,
approval gates before code changes, reviews after every change, and reports for
everything.

A skill is not a shell script. It is a specification (`SKILL.md` plus bundled
`references/`, `scripts/`, and `templates/`) that Claude Code loads and follows when you
ask for matching work. You interact with it in plain language; the skill supplies the
discipline.

## Prerequisites

- **Claude Code** (CLI, desktop app, or IDE extension).
- **A Magento 2 project** — Open Source, Adobe Commerce, Commerce Cloud, or Mage-OS.
  Both repo layouts are supported: Magento at the repo root (`./app/code`) or under
  `src/` (`src/app/code`).
- **Any PHP runtime shape** — bare host PHP or Docker (docker compose / docker exec).
  The toolkit auto-detects which one you have. Many skills (review, audits, scaffolding)
  work with **no running Magento instance at all**.
- Optional quality tools (`phpcs`, `phpstan`, `phpunit`, `phpmd`, `gitleaks`, …) are
  probed and used when present, and skipped with an honest note when absent. Nothing is
  required up front.

## Install

From any Claude Code session:

```
/plugin marketplace add muon-m2/magento2-tools
/plugin install magento2-tools@muon-m2 --scope user
```

`--scope user` makes the skills available in every project you open. Use
`--scope project` to pin the plugin to one repo instead.

**Team auto-enable** — commit this to your Magento project's `.claude/settings.json` and
every teammate gets the plugin offered automatically on folder trust:

```json
{
  "extraKnownMarketplaces": {
    "muon-m2": { "source": { "source": "github", "repo": "muon-m2/magento2-tools" } }
  },
  "enabledPlugins": { "magento2-tools@muon-m2": true }
}
```

### Verify

Run `/plugin` in Claude Code and confirm `magento2-tools@muon-m2` is installed and
enabled. The skills are namespaced `magento2-tools:magento2-<skill>` — for example
`magento2-tools:magento2-bug-fix`.

## How you invoke skills

Two ways, both equivalent:

1. **Plain language.** Describe the work; Claude Code matches it to a skill from the
   skill's description. *"This module throws a 500 on checkout, fix it"* → triggers
   `magento2-bug-fix`. *"Scaffold a module for order export with a REST API"* →
   triggers `magento2-module-create`.
2. **Explicit invocation.** Name the skill, optionally with flags the skill documents:

   ```
   /magento2-tools:magento2-deploy --env=staging Acme_OrderExport
   ```

Plain language is the normal mode. Explicit invocation is useful when you want a
specific skill, mode, or flag (e.g. `--validate-only`, `--diff`, `--scan-only`).

## The safety model — what to expect

Before you run anything, know the ground rules every skill follows:

- **Read-only skills stay read-only.** `magento2-debug`, `magento2-module-review`
  (unless you ask for fixes), and the audit skills never modify your code. Their output
  is the deliverable.
- **Code-writing skills gate on your approval.** `magento2-feature-implement` won't
  write code until you approve its blueprint *and* its task plan. `magento2-bug-fix`
  won't touch production code until you approve the root-cause analysis.
  `magento2-deploy` presents its plan and waits for "proceed". `magento2-release` waits
  for you to literally type `release` before pushing anything.
- **Production is double-gated.** Deploys to production require an explicit
  `--env=production` flag *and* an interactive confirmation. Smoke tests refuse to run
  against production unless your `CLAUDE.md` contains `Allow smoke on production: true`.
- **Behaviour is tested first.** Bug fixes, EAV attributes, and data patches are
  test-first by default (write the failing test, watch it fail, then the minimal code);
  feature work becomes test-first with `--tdd`. A shared red → green → refactor discipline
  keeps it consistent across skills.
- **`vendor/` is never edited.** Fixes for core or third-party bugs are implemented as
  plugins/observers/preferences in your own modules.
- **Honest gaps.** A missing tool or unavailable Magento CLI is reported as an
  environment limitation, never silently invented or silently skipped.
- **Everything leaves a paper trail.** Skills write their reports to a `.docs/` folder
  in your project — blueprints, RCAs, deploy reports, audit findings, coverage reports.

## First run: let the toolkit learn your project

Open your Magento project in Claude Code and ask:

```
Resolve the Magento 2 project context
```

This runs `magento2-context`, the hub skill every other skill consults. It detects:

- vendor prefix, Magento edition and version, PHP version and constraints
- the **runner** — bare PHP vs Docker, and the exact command prefix to use
- the Magento CLI and Composer invocations
- the active frontend/adminhtml theme (Luma / Hyva / custom)
- which quality tools are installed (`phpcs`, `phpstan`, `phpunit`, …)

The result is emitted as one JSON document and cached to
`.claude/.cache/magento2-context.json` (keyed by `composer.lock`/`composer.json`/
`CLAUDE.md` hashes, 24h TTL). Every value records *where it came from*
(`resolution_source`), so you can spot and correct a wrong detection.

If anything is detected wrong — say you run PHP in a container with an unusual name —
see [Configuration](configuration.md) for the `M2_PHP_CONTAINER` / `M2_MAGENTO_ROOT`
overrides and the `.claude/m2.json` file.

## Three safe things to try next

All three are read-only.

**1. Quick-review one of your modules:**

```
Quick review of the module app/code/<Vendor>/<Module>
```

Runs `magento2-module-review` in quick mode: security (ACL, CSRF, escaping, SQL
safety), persistence and DI hygiene, controller and API checks, registration sanity.
Findings come back ordered by severity with `file:line` evidence.

**2. Take a system snapshot:**

```
/magento2-tools:magento2-debug snapshot
```

One Markdown snapshot of indexer status, cache types, queue consumers and backlog,
pending cron, Magento mode, maintenance flag, DB/PHP versions, and `composer outdated` —
ready to paste into a ticket.

**3. Static performance pass:**

```
/magento2-tools:magento2-performance-audit Acme_Checkout
```

Scans the module source for N+1 loops, full-collection loads, missing block cache
identities, expensive constructors, un-batched cron jobs, and more — no running
instance needed. Output: severity-ranked findings with concrete replacement patterns.

## Your first code-writing skill

When you're ready to generate something, scaffold a minimal module:

```
Create a quick skeleton module called HelloWorld
```

Quick-create mode generates only the core files (`registration.php`, `etc/module.xml`,
`composer.json`, `etc/di.xml`, `README.md`, `CHANGELOG.md`) under
`app/code/<Vendor>/HelloWorld`, lints them (`php -l`, `xmllint`,
`composer validate`), and offers next steps — including the matching
`magento2-deploy` invocation to enable it. Nothing is deployed automatically.

From here:

- For routine work on an existing project → [Daily workflows](daily-workflows.md)
- For a structured path on a new project → [New project guide](new-project-guide.md)
- To understand what each skill does under the hood → [Flows and scenarios](flows-and-scenarios.md)
