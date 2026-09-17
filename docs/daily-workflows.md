# Daily workflows

Recipe-style guide for using `magento2-tools` in routine development on an existing
Magento 2 project. Each recipe describes the invocation, what happens, where you will be
asked to approve, and what artifacts are left behind.

Invocations are shown in their explicit form (`/magento2-tools:<skill> …`);
plain-language requests trigger the same skills — *"fix this bug"*, *"review my
changes"*, *"deploy these modules to staging"*.

## Quick reference

| Task | Skill | Typical invocation |
|------|-------|--------------------|
| Fix a reported defect | `fix` | `/magento2-tools:fix "500 on checkout when…"` |
| Build / change a feature | `feature` | *"Implement a store-pickup-notes feature"* |
| Resume an interrupted feature | `feature` | *"resume ./.docs/StorePickupNotes"* |
| Review code (full or diff) | `review` | `/magento2-tools:review --diff Acme_Checkout` |
| Generate missing tests | `test-generate` | `/magento2-tools:test-generate --types=unit Acme_Checkout` |
| Deploy modules | `deploy` | `/magento2-tools:deploy --env=staging Acme_Checkout` |
| Investigate without changing code | `debug` | `/magento2-tools:debug logs --since=1h` |
| Add an EAV attribute | `eav-attribute` | `--entity=product --code=acme_color --type=select …` |
| Add a GraphQL query/mutation | `graphql` | `--module=Acme_Reviews --operation=query` |
| Frontend scaffold (theme/JS/email) | `frontend` | `/magento2-tools:frontend email-template` |
| Seed / import / transform data | `data-migration` | `--type=import` |
| Sync translations | `i18n` | `--locales=en_US,de_DE Acme_Checkout` |
| Upgrade Magento/PHP compatibility | `upgrade` | `--to-magento=2.4.7 Acme_Checkout` |
| Security audit | `security` | `--scope=site` |
| Performance audit | `perf-audit` | `--scope=site` |
| Cut a release | `release` | `/magento2-tools:release Acme_Checkout` |
| Audit everything before a release | `audit` | `/magento2-tools:audit --release-readiness Acme_Checkout` |
| Decide who fixes each finding | `triage` | `/magento2-tools:triage` |
| Work through a triaged plan | `remediate` | `/magento2-tools:remediate --dry-run` |

---

## Fixing a bug

```
/magento2-tools:fix "Order export cron silently skips orders with virtual items"
```

Optional flags: `--module=Acme_OrderExport` (constrain RCA), `--log=<path>`,
`--no-deploy`, `--severity=high`.

**What happens** (phases 0–7):

1. Context is resolved; a `bugfix/{slug}` branch is created if you're on `main`.
2. **Collect** — missing facts are asked once, in a single batch (symptom, trigger,
   scope, environment, error, first-seen). Logs are pulled and grepped.
3. **Reproduce** — a deterministic reproduction recipe is built. If live reproduction
   fails twice, the skill tries to encode the defect as a *failing test* instead (mocked
   third parties, injected clock) before ever reporting "cannot reproduce".
4. **RCA — your approval gate.** The skill presents defect location (`file:line`),
   description, history, the proposed minimal fix, and the regression-test plan. **No
   production code changes until you approve.**
5. **TDD patch** — regression test first (confirmed failing for the right reason), then
   the minimal patch, then the module's full suite and static checks.
6. **Review** — `review --diff` on each modified module; new
   Critical/High findings introduced by the patch are fixed.
7. **Deploy (optional)** — only if you authorize; delegates to `deploy` and
   re-runs the reproduction recipe afterwards.
8. **Report** — severity-classified summary.

**Rules you can rely on:** minimal diff only (no drive-by refactoring), no scope
expansion (newly discovered bugs are filed, not absorbed), `vendor/` is never edited
(core bugs are fixed via plugin/observer in your module), every phase commits with a
`[bug-fix]` prefix, and the skill never pushes.

**Artifacts:** `.docs/bug-fixes/{slug}/` — `collect.md`, `reproduction.md`, `rca.md`,
`report.md`.

**Edge cases worth knowing:** a fix that needs a `db_schema.xml` change is redirected to
`feature --mode=extend`; a data repair (corrupted rows) stays
in-skill via an idempotent `data-migration` patch.

---

## Implementing a feature

```
Implement a feature: admins can attach internal notes to orders, visible in the order grid
```

**What happens** (7 phases — see [Flows and scenarios](flows-and-scenarios.md) for the
full picture):

1. **Elicit** — a mode is chosen (`feature` / `hotfix` / `extend` / `spike`); ambiguity
   is resolved with one batch of 3–6 questions, never mid-implementation.
2. **Blueprint — approval gate #1.** A 12-section blueprint is saved to
   `.docs/{FeatureName}/blueprint.md`. Nothing is built until you approve it.
3. **Module schema** — which modules own which parts (new vs. modify decision matrix).
4. **Task plan — approval gate #2.** Tasks with IDs (`M*` create, `X*` modify,
   `R*` review, `T*` test, `E*` EAV, `G*` GraphQL, `V*` validate, `D*` deploy,
   `S*` smoke), dependency diagrams, estimates. Reply **"proceed"** to start.
5. **Execute** — tasks run in dependency order; every module is reviewed after creation
   or modification and Critical/High findings are fixed before moving on.
6. **Test** — 6A: unit tests + coverage (≥ 80% target for `Api/`/`Service/`/`Model/`);
   6B: smoke battery against the running instance (REST scenarios, admin login, grids,
   new routes, customer flows, `exception.log` diff). Critical/High smoke findings are
   auto-routed to the right sub-skill and the loop re-runs — bounded at 5 iterations
   before asking you how to proceed.
7. **Report** — `.docs/{FeatureName}/report.md` plus optional HTML developer/user guides.

**Modes:** `hotfix` and `extend` skip phases 3–4 (only the blueprint gate applies);
`spike` reduces phases 6–7. State the mode if you want one: *"hotfix: …"*.

**Test-first (TDD mode):** opt in with `--tdd` (or `Feature implement: tdd = on` in
`CLAUDE.md`, or `MAGENTO2_FI_TDD=1`; default off, `spike` exempt). Behaviour-bearing
classes (services, models with logic, plugins, observers, resolvers, console commands)
are then implemented test-first — the task's acceptance criteria become failing tests
written *before* the code, watched to fail, then turned green — while pure scaffold/config
stays generated-then-covered. The `T*` task becomes a coverage top-up rather than the
first author of the behaviour tests.

**Resuming:** interrupted runs are resumable because `plan.md` tracks every task as a
checkbox. Say *"resume ./.docs/{FeatureName}"* — the skill picks up at the first
unchecked task without re-asking for approvals you already gave. (Without an explicit
`.docs/...` path, a "continue" request is treated as a *new* feature — name the folder.)

---

## Reviewing code

After hand-writing changes (or any time):

```
/magento2-tools:review --diff Acme_Checkout      # only what changed vs origin/main
/magento2-tools:review Acme_Checkout             # full review
Quick review of app/code/Acme/Checkout                           # Tier-1-only fast pass
```

- **Diff mode** restricts the review to files changed since a git ref (default
  `origin/main`) — the right default after every focused change.
- **Full review** covers architecture, security, persistence, DI, frontend escaping,
  ACL/config, cron/queue safety, PHPDoc/SOLID/DRY, and test coverage across 3 risk
  tiers; words like *audit*, *release-readiness*, or *comprehensive* select it
  automatically.
- **Quick review** covers Tier 1 (security, persistence, DI, controllers/CSRF, service
  contracts, registration sanity) for small modules without API/route surfaces.

Findings are ordered by severity (Critical → Info), each with impact, `file:line`
evidence, a recommendation, and a verification suggestion. Static tools (`phpcs`,
`phpstan`, …) are used when installed and reported as skipped when not. The review
does **not** edit your files unless you explicitly ask for fixes — and then it fixes in
severity order, re-checking after each fix.

**Artifacts:** Markdown report in conversation; JSON
(`.docs/reviews/{Vendor}_{Module}-review-{date}.json`) and SARIF siblings on request or
when invoked from another skill — the SARIF uploads straight into GitHub Code Scanning.

---

## Acting on an audit

An audit tells you *what* is wrong. Two more steps decide *who fixes each finding* and
prove it actually closed.

```
/magento2-tools:audit Acme_Checkout          # 1. find      → .docs/audits/…-audit-{date}.json
/magento2-tools:triage                       # 2. decide    → .docs/remediation/…-plan-{date}.md
/magento2-tools:remediate --dry-run          # 3. inspect   (nothing is executed)
/magento2-tools:remediate                    # 4. fix       (one approval per batch)
```

**Triage is read-only.** It fingerprints each finding, applies your waivers, gates on
confidence, routes each one to the skill that owns that kind of fix, and groups the work
into dependency-ordered batches. The routing is a contract, not a judgement call — a queue
finding goes to `message-queue`, an indexer finding to `indexer`, a Breeze finding to
`breeze-adapt`, a missing-coverage finding to `test-generate`.

Read the plan before you run anything. It separates four things you should look at
differently:

| Section | What it means |
|---------|---------------|
| `batches` | Confirmed findings, routed and ordered. This is the work. |
| `verify_first` | Low-confidence findings (regex hits, CI SARIF). **Never** auto-patched — confirm by reading the evidence first. |
| `waived` | Suppressed by your `waivers.yml`, shown with reason and author. Never silently dropped, never counted as fixed. |
| `unrouted` | No routing rule matched. Reported honestly rather than guessed at. |

**Batch order is a dependency order, not a priority order.** `upgrade` runs first because it
rewrites call sites the later batches would otherwise patch twice; `i18n` runs once every
user-facing string exists; `test-generate` writes tests against final code; `lint` runs
**last** so it formats everything the run produced. Running `lint` first guarantees re-churn.

**Remediate asks once per batch, not once per finding.** Each fix still lands as its own
commit, still test-first — `fix --from-finding` skips the interview, never the discipline.
Anything tagged `gate: manual` is listed for you and never executed: deleting a leaked
credential from the code does not un-leak it, so rotation stays a human action.

Finally, closure is measured rather than assumed:

```
/magento2-tools:audit --compare=.docs/audits/Acme_Checkout-audit-2026-09-16.json Acme_Checkout
```

This re-runs and diffs against the baseline by fingerprint, reporting what **closed**, what
is **still open**, what was **waived** — and what **regressed**, i.e. a new finding the
remediation itself introduced. A check that could not run is reported as **skipped**, never
as clean.

**Artifacts:** `.docs/remediation/{Vendor}_{Module}-plan-{date}.{md,json,sarif}` (triage),
a run report alongside it (remediate), and
`.docs/audits/{Vendor}_{Module}-closure-{date}.{md,json,sarif}` (the closure diff, owned by
`audit` — it stays the single source of truth for verdicts and scores).

---

## Generating tests

```
/magento2-tools:test-generate --types=unit,api Acme_OrderExport
```

This skill is the **backfiller** for code that already exists — including modules with no
tests at all. (For *new* behaviour, the owning skill writes the test first: `fix` always,
`feature` under `--tdd`, and `data-migration`/`eav-attribute` by default. See
[Flows and scenarios](flows-and-scenarios.md#test-first-builders-data-migration-eav-attribute).)

Discovery first: `coverage-gap.sh` finds source classes without tests and surfaces
warranting non-unit tests (persistence → integration, `webapi.xml`/`schema.graphqls` →
API, KO/RequireJS → Jasmine, admin UI → MFTF). You get a **test plan to approve** before
anything is written.

Guarantees: every generated test contains real assertions (no
`markTestIncomplete()` stubs), every file passes its static check (`php -l`,
`node --check`, `xmllint`), unit tests are *run* and fixed before reporting done, and
your source files are never modified — untestable classes are surfaced as findings
instead.

**Artifacts:** tests under the module's `Test/` tree;
`.docs/tests/{Vendor}_{Module}-coverage-{date}.md`.

---

## Deploying

```
/magento2-tools:deploy --env=local Acme_ModuleA Acme_ModuleB
/magento2-tools:deploy --env=staging --strict Acme_ModuleA
/magento2-tools:deploy --env=production --snapshot Acme_ModuleA
```

**What happens:** pre-flight validation (files exist, composer validate, unit tests,
disk space, `setup:db:status`; plus PHPCS/PHPStan with `--strict`, clean git tree and
composer dry-run on production) → an ordered plan presented for approval → execution
with per-step capture → smoke tests → report. Any failed step **stops the sequence and
triggers the step's rollback recipe**.

Key safety facts:

- **Production needs `--env=production` + interactive confirm.** `--auto` is rejected
  on production unless you also pass `--i-know-what-im-doing`.
- **`setup:upgrade` rollback is lossy without a DB backup.** Take the offered snapshot
  with `--include-db` before production deploys; applied data patches and declarative
  schema drops cannot be undone by reverting code.
- **`--validate-only`** runs context + pre-flight + plan and exits — safe for CI gating
  (exit 0/1).
- Smoke failures after a completed deploy are reported as "needs investigation", not
  auto-rolled-back.

**Artifacts:** `.docs/deployments/{timestamp}-{env}.md` + `.json` (machine-readable for
CI) + optional `.snapshot.tar.gz`.

---

## Investigating (read-only)

`debug` is the "look, don't touch" skill — six modes:

```
/magento2-tools:debug logs --since=1h --pattern="checkout"   # grouped log triage
/magento2-tools:debug trace --event=checkout_submit_all_after # observers for an event
/magento2-tools:debug trace --method='Magento\Catalog\Model\Product::save' # plugins
/magento2-tools:debug di --for='Magento\Catalog\Api\ProductRepositoryInterface'
/magento2-tools:debug slow-queries --since=24h
/magento2-tools:debug snapshot
/magento2-tools:debug xdebug
```

Output is de-duplicated and grouped (log entries by error signature, slow queries by
query pattern) rather than dumped raw. `trace` and `di` work purely from the source
tree — no running instance needed. Add `--save` to write the report to
`.docs/debug/{mode}-{date}.md`.

When findings need action, the skill points you onward: defects →
`fix`, slow-query patterns → `perf-audit`.

---

## Adding an EAV attribute

```
/magento2-tools:eav-attribute --entity=product --code=acme_color \
  --label="Acme Color" --type=select --module=Acme_Catalog
```

Missing inputs (scope, required, search/filter/grid flags, apply-to types…) are asked
once; you approve the file plan. The skill is **test-first**: before writing the patch
it generates a failing integration test asserting the attribute's scope, input type, and
backend/source wiring **plus idempotency** (running the patch twice doesn't duplicate or
error), watches it fail, then writes the minimal **idempotent**
`Setup/Patch/Data/Add{Code}Attribute.php` (guarded by `EavSetup::getAttribute()`, safe
to re-run) to turn it green — plus companion source/backend/frontend models *only when
the input type needs them* (behavioural ones get a test-first unit test), using the
correct setup factory per entity. Never legacy `InstallData.php`. When no Magento test DB
is available it falls back to a test-first unit test and records the integration gap.

**Artifacts:** the patch + companions in your module;
`.docs/eav-attributes/{Vendor}_{Module}-{code}-{date}.md` with the
`setup:upgrade`/reindex/cache-flush commands to run.

---

## Adding GraphQL

```
/magento2-tools:graphql --module=Acme_Reviews --operation=query --auth=customer
```

Schema-first: you settle the schema fragment and resolver plan (standard vs. **batch**
vs. paginated) before code. Any resolver feeding a parent *list* is generated as a
`BatchResolverInterface` implementation — N inputs, O(1) queries. Mutations get auth
checks (anonymous requires justification); store-scoped data respects the `Store`
header. Existing `schema.graphqls` is appended to, never rewritten. Unit tests come via
`test-generate`, and a `--diff` review follows generation.

---

## Frontend work

```
/magento2-tools:frontend <theme|requirejs-module|ko-component|alpine-component|email-template|static-asset>
```

One operation per invocation. The skill is **theme-aware** via the context hub: on a
Hyva project it steers you from Knockout to Alpine.js components automatically.
Generated assets ship with the layout XML that activates them. `requirejs-config.js`
and `email_templates.xml` are appended/merged, never overwritten.

---

## Data seeding, imports, and transformations

```
/magento2-tools:data-migration --type=seed|import|transform
```

Three shapes: fixed seed (< 100 rows inline in a data patch), bulk import (chunked
importer service + optional `bin/magento {vendor}:{module}:import --dry-run` CLI), and
transformation (SELECT → INSERT → DELETE in a transaction, keyset-paginated). The skill
is **test-first**: before the patch it writes a failing integration test asserting the
post-migration state **and idempotency** (apply twice → identical state, no duplicates),
watches it fail, then writes the minimal patch to turn it green. Every patch implements
`DataPatchInterface`, is idempotent, and documents its rollback path — destructive
patches refuse to run without `--allow-destructive`. Without a Magento test DB it falls
back to a test-first unit test of the idempotency guard and records the gap.

**Artifacts:** `Test/Integration/…` test + `.docs/migrations/{name}-{date}.md` (with the
red → green evidence).

---

## Keeping translations in sync

```
/magento2-tools:i18n --locales=en_US,de_DE --module=Acme_Checkout
```

Extracts phrases (via `i18n:collect-phrases` when the CLI is available, regex fallback
otherwise), merges into each locale CSV **without ever overwriting existing
translations**, moves phrases no longer in code to a sidecar
`<locale>.obsolete.csv`, and validates placeholder consistency (`%1`, `%2` counts must
match per locale) and CSV well-formedness. Optional machine translation
(`--machine-translate`, requires a provider API key in the environment).

**Artifacts:** updated `i18n/{locale}.csv` files; `.docs/i18n/{Vendor}_{Module}-{date}.md`.

---

## Cutting a release

```
/magento2-tools:release Acme_OrderExport
```

The next version is derived from **conventional commits** since the last
module-prefixed tag (`feat:` → minor, `fix:` → patch, `BREAKING CHANGE`/`feat!:` →
major) — path-filtered to the module, so sibling modules in the same repo don't pollute
the bump. Override with `--version=X.Y.Z` (downgrades and equal versions are refused).

Before anything is tagged, the release runs
`deploy --validate-only --strict --env=local` — pre-flight only, never a
state-changing deploy. Then: `composer.json` bump + `CHANGELOG.md` update + commit, a
module-prefixed annotated tag (`Acme_OrderExport-1.4.0`), and the **push gate — you
must type `release` to confirm**; anything else cancels. Optional GitHub Release via
`gh`, and registry notes for Packagist/Satis/VCS/Marketplace.

**Artifacts:** updated `composer.json`/`CHANGELOG.md`, the tag,
`.docs/releases/{Module}-{Version}.md`.

---

## Periodic hygiene

Worth scheduling weekly or before every launch:

**Everything at once** — the release-readiness pass:

```
/magento2-tools:audit --release-readiness Acme_Checkout
```

The umbrella over every audit below. It picks the dimensions the module's surface
actually warrants (accessibility only where storefront templates exist, Breeze
compatibility only under a Breeze theme, marketplace readiness only when you ask for it),
runs them, and **consolidates** rather than concatenates: duplicates across dimensions
collapse into one finding tagged with every dimension that raised it, keeping the highest
severity, ending in a single `PASS` / `CONDITIONAL` / `FAIL` verdict and score. You get
one report and one merged SARIF instead of seven to reconcile.

Fanning the dimensions out to parallel read-only subagents is `audit`'s default and is
opt-in authorization; `--inline` runs the same dimensions sequentially with identical
consolidation and artifacts. Skipped dimensions are named in the report — an unrun
dimension never reads as "clean".

Output: `.docs/audits/{Vendor}_{Module}-audit-{date}.md|.json|.sarif`; each dimension's
own artifacts stay under their usual category dirs. Reach for a single dimension's skill
directly when you only want that one — the recipes below.

**Security audit** — site-wide:

```
/magento2-tools:security --scope=site
```

Dependency CVEs (live `composer audit` + Adobe patch-state via `vendor/bin/patch-status`), secret
scanning (gitleaks/trufflehog or regex fallback), Magento-specific static patterns
(anonymous REST resources, missing form keys, insecure cookie flags, risky
`<preference>`s…), Marketplace coding-standard checks, and cross-module collision
detection (dual preferences, dependency cycles, duplicate cron names). Findings are
severity-calibrated to PCI/GDPR impact. Output: Markdown + JSON + SARIF under
`.docs/audits/`.

**Performance audit** — static by default, runtime opt-in:

```
/magento2-tools:perf-audit --scope=site            # static only
/magento2-tools:perf-audit --runtime --scope=site  # + indexers, caches, queues, slow log
```

**Compatibility scan** — before platform upgrades:

```
/magento2-tools:upgrade --scan-only --to-magento=2.4.7 Acme_Checkout
```

Phases 0–2 only: Adobe UCT, Rector, PHPCS-Magento2, deprecation-map AST scan, composer
constraints, PHPStan — each finding classified `auto-fixable` / `manual-fixable` /
`bc-break`, with no edits. Drop `--scan-only` when you're ready to apply (you approve
the plan first; BC breaks are documented in `UPGRADE.md`, not silently "fixed").
