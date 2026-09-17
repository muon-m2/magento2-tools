# Configuration

How the toolkit learns about your project, how to correct it when detection isn't
enough, and how to plug its outputs into CI.

## The context resolver

`context` is the single source of truth every skill consults. Resolution
priority for each value:

1. explicit `CLAUDE.md` hint
2. file/composer probe (composer.json, `app/etc/config.php`, compose files, …)
3. tool probe (running containers, binaries on PATH / in `vendor/bin`)
4. ask the user

Never a silent guess: every resolved value records its origin in `resolution_source`,
and a missing tool is `null` rather than an invented path.

What gets resolved:

| Field | Meaning |
|-------|---------|
| `vendor` / `vendor_lower` | Vendor prefix for all generated code |
| `magento_root` / `module_dir` | Repo layout: `.` or `src`; where `app/code` lives |
| `edition` / `magento_version` | open-source / commerce / Commerce Cloud / Mage-OS + version |
| `php_version` / `php_constraint` / `framework_constraint` | For generated `composer.json` files |
| `runner` / `runner_kind` | Command prefix to reach PHP: `""` for bare host PHP, `docker compose exec …` for containers; kind = `bare` / `docker-compose` / `docker-exec` / `custom` / `null` (no PHP env) |
| `magento_cli` / `composer` | Full `bin/magento` and composer invocations (null when unavailable — deploy aborts, others degrade) |
| `theme.frontend` / `theme.adminhtml` | Active theme (Luma / Hyva / custom), with source; drives frontend scaffolding |
| `tools.*` | Paths for phpcs, phpstan, phpunit, phpmd, rector, psalm, xmllint, semgrep, gitleaks, trufflehog, node, pa11y, … |
| `execution_mode` | Project default for the findings/RCA family (`agents` / `inline` / `null`), from `.claude/m2.json` |

### Cache

The JSON is cached at `.claude/.cache/context.json`. The cache key combines
the sha256 of `composer.lock`, `composer.json`, and `CLAUDE.md`; the resolver
short-circuits only when the key is byte-identical and the cache is fresh (default 24h).

- Force refresh: pass `--no-cache` or delete the cache file.
- Changing any override (env var, `m2.json`, `CLAUDE.md`) busts the cache automatically.
- Recommended: add `.claude/.cache/` to `.gitignore` — the cache is per-machine.

## Environment variables

Env vars win over `.claude/m2.json`:

| Variable | Default | Effect |
|----------|---------|--------|
| `M2_PHP_CONTAINER` | auto-detect | Name of the running PHP container. If the named container isn't running, detection falls through to generic name patterns. |
| `M2_MAGENTO_ROOT` | auto-detect (`.` or `src`) | Magento root inside the repo. |
| `M2_CACHE_TTL` | `86400` (24h) | Context cache TTL in seconds; `0` disables caching. |
| `MAGENTO2_FI_PER_TASK_COMMITS` | unset | `1` enables per-task git commits in `feature`. |
| `MAGENTO2_FI_TDD` | unset | `1` turns on **test-first (TDD) mode** in `feature`: behaviour-bearing `M*`/`X*` tasks are implemented test-first (write the failing test, watch it fail, then the minimal code). Off by default; `spike` mode always exempt. |
| `MAGENTO2_SMOKE_NO_BROWSER` | unset | `1` forces **curl-only** smoke testing: REST and error-signal suites run in full, admin/storefront suites run a degraded curl reachability tier and emit a Medium coverage finding. Use in CI where no headless browser is installed. Lowest-priority of the explicit switches — outranked by a prompt directive, the `--no-browser` flag, and `CLAUDE.md`'s `Smoke browser: off`. |
| `MAGENTO2_DEPLOY_NON_INTERACTIVE` | unset | `1` puts `deploy` in CI mode: approval prompts are skipped (pair it with `--auto`), production is still refused without `--i-know-what-im-doing`, JSON reports are emitted, and the run exits non-zero on any failure. |
| `M2_SMOKE_ADMIN_USER` | unset | Admin username for the `feature` smoke battery's authenticated admin suite. Consulted after the `CLAUDE.md` `Smoke admin user:` line and before prompting. |
| `M2_SMOKE_ADMIN_PASS` | unset | Admin password for the same suite. **Env or interactive prompt only** — the skills deliberately refuse to read a password from `CLAUDE.md`, which is a committed file. |
| `DOCS_ROOT` | `.docs` | Output root for artifact-writing **scripts**. Skills take the same value as `--docs-root={path}`. Because env vars do not persist between a skill's Bash calls, it is passed explicitly per invocation rather than exported once. |

## `.claude/m2.json`

The plugin's own override file. Commit it so the whole team shares the same settings:

```json
{
  "php_container": "my-php-container",
  "magento_root": "src",
  "execution_mode": "agents"
}
```

| Key | Effect |
|-----|--------|
| `php_container` | Name of the PHP container, when detection picks the wrong one or finds none |
| `magento_root` | Magento root inside the repo (`.` or `src`) when the layout probe is wrong |
| `execution_mode` | `"agents"` or `"inline"` — the project default for the findings/RCA family (see [Execution modes](#execution-modes-agents-vs-inline)) |

All three are resolved by `context` and folded into its cache key, so editing this file
takes effect on the next skill run without manual cache busting. An unrecognised
`execution_mode` resolves to `null` with the reason recorded in `resolution_source`
rather than being guessed at.

> This is **not** Claude Code's `.claude/settings.json`. The plugin never parses that
> file, and Claude Code accepts unknown keys in it silently — a plugin setting placed
> there would do nothing, with no error to tell you.

## `CLAUDE.md` hints

Skills read your project's `CLAUDE.md` for these lines:

| Line | Read by | Effect |
|------|---------|--------|
| `Vendor prefix: **Acme**` | context resolver (and `feature` fallback) | Vendor for all generated namespaces, tables, ACLs, routes |
| `Allow smoke on production: true` | `feature` smoke runner | Permits Phase 6B smoke tests against a production base URL (refused otherwise) |
| `Feature implement: per-task commits = on` | `feature` | Same as `MAGENTO2_FI_PER_TASK_COMMITS=1` / `--per-task-commits` |
| `Feature implement: tdd = on` | `feature` | Same as `MAGENTO2_FI_TDD=1` / `--tdd` — behaviour tasks implemented test-first (red → green → refactor) |
| `Smoke browser: off` | `feature`, `a11y-audit` | Same as `MAGENTO2_SMOKE_NO_BROWSER=1` / `--no-browser` — smoke and the pa11y runtime pass never drive a browser |
| `Smoke admin user: admin` | `feature` smoke runner | Admin username for the authenticated admin smoke suite. There is deliberately **no** password equivalent — a `Smoke admin pass:` line is ignored and warned about, since `CLAUDE.md` is committed |
| `Explorer model: sonnet` | feature / review / fix | Model tier (`haiku`/`sonnet`/`opus`) for the read-only `explorer` comprehension agent. Defaults to `haiku`; name the tier that matches your session model to run it there. Does not affect `reviewer`. |
| MySQL slow-log path | `perf-audit` / `debug` | Where to read the slow query log when non-default |

`CLAUDE.md` participates in the context cache key, so editing it takes effect on the
next skill run without manual cache busting.

> The per-task `Model tier (advisory)` fields in `feature` plans are
> recommendations only — the harness does not route Skill-tool tasks by tier, so they run on the
> session model. The one directive that takes live effect is `Explorer model:` above (the read-only
> explorer subagent). See the `feature` task-breakdown guide for the tier-by-type mapping.

## Execution modes: agents vs inline

The findings/RCA family — `audit`, `review`, `security`, `perf-audit`, `a11y-audit`,
`marketplace`, and `fix` — can run its analysis two ways. The mode changes only *where*
the work runs: the same references, checklists, and findings schema apply either way.

| Mode | What happens | When it wins |
|------|--------------|--------------|
| `agents` | Read-only subagents run in parallel — `reviewer` (one per findings dimension), `explorer` (comprehension / RCA path-tracing) — and the skill owns synthesis: dedup, severity normalization, conflict tie-breaking | Large modules, multi-dimension audits, security-sensitive targets. Faster wall-clock; your main context stays small |
| `inline` | The skill runs the same analysis itself, sequentially, in the conversation | Small targets, step-by-step steering, token-frugal runs, environments where subagents are unavailable |

Selected in precedence order:

1. **Per run** — `--agents` / `--inline` on the invocation, or plain language
   ("in one flow", "without subagents", "use parallel agents", "delegate").
2. **Per project** — `"execution_mode"` (`"agents"` | `"inline"`) in
   [`.claude/m2.json`](#claudem2json). Absence means no preference; so does an
   unrecognised value, which is reported rather than guessed at.
3. **Per-skill default** — `audit` defaults to `agents` (fanning out is its whole
   point); every other consumer defaults to `inline`. These defaults preserve
   pre-2.0 behaviour.

The chosen mode, and what chose it, is stated in the run header of every report.

**Invariants in both modes:** approval gates always run in the main conversation and are
never delegated; both modes read the same reference packs and emit the same
findings-schema JSON/SARIF; the `reviewer` and `explorer` agents are strictly read-only.

**One documented divergence:** an inline run can pause to ask you a clarifying question
mid-analysis. A subagent cannot — in `agents` mode ambiguities are resolved
conservatively and listed under **Open questions** in the report instead. Pick `inline`
when the target is ambiguous enough that mid-run steering matters.

Contract: `skills/context/references/execution-modes.md`.

## Output conventions

Durable skill outputs go to `.docs/` in your project (full map in
[Flows and scenarios](flows-and-scenarios.md#artifact-map)). Every artifact-producing
skill accepts `--docs-root={path}` to write somewhere else — the skill always appends
its own category subdirectory, so `--docs-root=build/reports` yields
`build/reports/audits/…`. `feature` uses this to nest a whole run's sub-skill artifacts
under one feature folder, and `audit` uses it to keep every dimension's output together.

Decide once per project whether to commit `.docs/`:

- **Commit it** — the team gets shared engineering memory: blueprints, RCAs, deploy
  history, audit baselines. (Feature folders are also what makes interrupted
  feature runs resumable across machines.)
- **Ignore it** — keep reports local; CI artifacts can still be uploaded from the
  generated JSON/SARIF files.

## Waivers — `.docs/findings/waivers.yml`

The one file in `.docs/` that you write and the toolkit reads. It records decisions you
have already taken about findings, so re-running an audit converges instead of re-reporting
the same accepted risks at full severity forever.

```yaml
version: 1
waivers:
  - fingerprint: "a3f9c1…"            # 64-char sha256; see below
    finding: "security/csrf: POST controller missing form key validation"
    file: Controller/Adminhtml/Order/Save.php
    verdict: false-positive           # false-positive | accepted-risk | wont-fix
    reason: "Validated by the parent Action; see ADR-14"
    author: s.autushka
    expires: 2027-01-01               # optional
```

**Why a fingerprint and not a file:line.** A finding's `id` is regenerated on every run
(`{skill}-{date}-{seq}`), and its line number moves the first time you patch the file.
Neither can carry a decision forward. The fingerprint is a sha256 over
`producer`, `category`, `subcategory`, `title`, `file` and the normalized evidence snippet —
deliberately excluding the line number and the run date, so it survives a patch or a
reformat. Copy it from the finding in any `.json` report.

Behaviour you can rely on:

- A waived finding is **reported** in the `waived` bucket with its reason and author. It is
  never silently dropped, and never counted as closed.
- An `expires` date in the past **resurfaces** the finding as needs-triage. Suppression that
  outlives its own deadline is how a deferred risk becomes a forgotten one.
- A waiver matching nothing in the current report is reported as **stale**, so dead entries
  get pruned rather than accumulating.
- Waivers written against a JSON report also match the same finding read back from that
  run's SARIF. They do **not** match a foreign CI SARIF, which lacks the evidence snippet
  the fingerprint is built from.

**Commit this file.** `.docs/` is gitignored in most projects, so `triage` runs
`git check-ignore` on it and warns when suppressions would silently reset. Either commit it
or move it somewhere tracked with `--waivers=<path>`.

---

## CI integration

### Deploy gate

```bash
# In CI: validate without deploying. Exit 0 = all required pre-flight checks pass.
/magento2-tools:deploy --validate-only --strict --env=local Acme_ModuleA
```

Produces `.docs/deployments/{ts}-local.json` with `"mode": "validate-only"` — parse it
or just use the exit code. `release` runs exactly this as its Phase 2 gate.

### Findings to GitHub Code Scanning

`review`, `security`, `perf-audit`, and
`upgrade` all emit the shared findings schema
(`skills/context/references/findings-schema.md`) as JSON, with a SARIF 2.1.0
sibling generated by the shared `emit-sarif.sh`. Upload the `.sarif` with
`github/codeql-action/upload-sarif` to surface findings as PR annotations.

JSON artifacts are stable enough for trend tracking — diff successive
`.docs/audits/*.json` files to show finding counts moving between releases.

### Severity scale (shared by all finding-producing skills)

| Severity | Meaning |
|----------|---------|
| Critical | Exploitable auth/payment/data-loss issue, RCE, secret leak, deployment-breaking defect |
| High | Security bypass, broken public API, unsafe state mutation, production-breaking DI/schema issue |
| Medium | Architectural violation, missing validation, maintainability risk, insufficient tests for risky logic |
| Low | Style, documentation, naming, optional hardening |
| Info | Positive observation, skipped check, context |

Domain calibrations: security findings are bumped by PCI/GDPR impact
(`skills/security/references/severity-security.md`); performance
findings are weighted by impact at scale
(`skills/perf-audit/references/severity-perf.md`).

## Smoke test tooling

Skills that exercise a running Magento instance follow one policy, defined in
`skills/context/references/runtime-test-tooling.md`:

- **REST, GraphQL, and every Web-API surface use `curl`** — always, with no override. A browser
  masks the contract under test.
- **Admin and storefront smoke use a headless browser**, never a headed one and never a
  browser-automation MCP server.
- **A browser is never assumed to exist.** When none is found, admin/storefront suites degrade to
  unauthenticated `curl` reachability checks and the run emits a Medium coverage finding naming
  what was not verified.

To force curl-only testing, in priority order:

```bash
# 1. Say so in the prompt — highest priority
#    "implement X, do not use browser"   /   "…use curl for the smoke tests"

# 2. Flag
/magento2-tools:feature "add X" --no-browser

# 3. CLAUDE.md
echo 'Smoke browser: off' >> CLAUDE.md

# 4. Environment
export MAGENTO2_SMOKE_NO_BROWSER=1
```

Authenticated admin screens (Stores → Configuration walks, admin grids) are **not** covered by
the curl tier — Magento 2.4 requires a form key and mandatory 2FA, so a scripted admin login
would fail for environmental reasons and misreport as a product defect. Those suites are listed
as not covered rather than faked.

## Production safety switches

Collected in one place, since they span skills:

| Switch | Where | Effect |
|--------|-------|--------|
| `--env=production` + interactive confirm | deploy | Both required for any production deploy |
| `--auto --env=production` rejected | deploy | Unless `--i-know-what-im-doing` is also passed |
| Snapshot prompt (`--snapshot`, `--include-db`) | deploy | Offered on every production deploy; DB dump is the only non-lossy `setup:upgrade` rollback |
| `Allow smoke on production: true` | `feature` | Smoke battery refuses production URLs without it |
| Typing `release` | release | Only confirmation that pushes tags |
| Clean git tree + composer dry-run | deploy pre-flight | Required checks on production targets only |
