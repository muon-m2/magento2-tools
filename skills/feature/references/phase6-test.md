# Phase 6 — Test

Part of the `feature` skill — read at Phase 6 start, every smoke iteration.

Phase 6 is split into two sub-phases: **6A** (unit + coverage, existing behaviour) and **6B**
(smoke battery, new). A Phase 6 run is only "passed" when **both** sub-phases pass. The smoke
loop re-enters Phase 6 from 6A — not from 6B — so a smoke fix that touches PHP also re-validates
unit tests.

**At Phase 6 start (every iteration):**

1. **Reconcile `## Current State`.** Before anything else, verify every Phase 5 task whose work
   is actually complete is marked `[x]` in `plan.md`. A run that reaches Phase 6 has finished
   all Phase 5 tasks, so any Phase 5 task still showing `- [ ]` here is missed bookkeeping, not
   pending work: flip it to `- [x]` and save. This is a safety net for the Per-task completion
   protocol — it should already be a no-op.
2. If `plan.md` is missing the `## Smoke Iterations` block (i.e. the plan was written before
   this skill version), append it with `Count: 0 / 5` and add the applicable `S*` task
   checkboxes to `## Current State`. Save `plan.md` immediately. This is a one-time migration
   for in-flight features.
3. Increment the smoke-iteration counter in `plan.md` under `## Smoke Iterations`.
4. If the counter would exceed 5, halt and print the halt prompt from
   `references/smoke-test-guide.md` §Halt Prompt. Wait for explicit user reply
   (`retry` / `accept-known-issues <IDs>` / `abort`). Do not loop again automatically.

---

## Phase 6A — Unit Tests + Coverage

**Goal:** ensure all new and modified code has passing unit tests with adequate coverage.

1. If T* tasks were included in the plan: confirm all T* tasks are marked complete and that test
   files exist in `Test/Unit/`. Do not rewrite tests already created in Phase 5.
   If no T* tasks were generated (e.g. single-module, simple feature): delegate to
   `test-generate --types=unit,integration,api --docs-root=.docs/{FeatureName}` for each module.
   Inline fallback (when `test-generate` is absent): write unit tests now for
   every `Api/`, `Service/`, and `Model/` class — do not skip and report it as a limitation.
2. Run all tests using the probed `{runner}`:
   ```bash
   {runner} vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist app/code/{Vendor}/{ModuleName}/Test/Unit
   ```
   Fix any failures. Do not proceed to Phase 6B with failing unit tests.
   If PHPUnit is unavailable, document as an environment limitation and list the command for the user.
3. Run coverage for each new module (requires Xdebug). Select the form that matches the probed
   `{runner}` type:
   ```bash
   # Docker runner — pass the env var inside the exec call
   docker compose exec -e XDEBUG_MODE=coverage -u magento php vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist \
     --coverage-clover var/log/coverage-{Vendor}_{ModuleName}.xml \
     app/code/{Vendor}/{ModuleName}/Test/Unit

   # Bare PHP runner — prefix the command directly
   XDEBUG_MODE=coverage php vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist \
     --coverage-clover var/log/coverage-{Vendor}_{ModuleName}.xml \
     app/code/{Vendor}/{ModuleName}/Test/Unit
   ```
   If Xdebug is not available, skip coverage measurement and note it explicitly.
4. Target: ≥ 80% coverage for `Api/`, `Service/`, `Model/` combined.
   If a module is below 80%, either add tests or document the gap with a specific justification.
5. Record all test results: test count, pass/fail/skip, and coverage percentage per module.

---

## Phase 6B — Smoke Battery

**Goal:** verify the feature works against a running Magento instance and that nothing else
regressed in the surfaces typical sites care about.

Load `references/smoke-test-guide.md`, `references/smoke-runner.md`, and
`references/error-signal-baseline.md` before starting. Phase 6B is **mandatory** in `feature`
mode, reduced in `hotfix` and `extend` modes, and skipped in `spike` mode (see
`references/modes.md`).

Emit one `S*` task per applicable suite (Phase 4 task type `S`). S1 (baseline & probe) and S8
(error-signal diff) are always present; S2–S7 only when the feature exercises that surface.
The suite catalogue, per-suite acceptance, the S1 probe table + production guard, the S9
triage/decision loop, and the data-hygiene/cleanup rules live in the references — **follow
them rather than duplicating here** (the duplicate had already drifted from the source):

- `references/smoke-runner.md` — §1 probe table (Base URL, admin creds, HTTP client, headless
  browser) + production guard; the per-suite driver commands. Refuse to run against production
  unless `CLAUDE.md` contains `Allow smoke on production: true`.
- `references/smoke-test-guide.md` — the S1–S9 suite catalogue, per-suite acceptance, severity
  rubric, fix-routing table, halt prompt, and data-hygiene/cleanup rules.
- `references/error-signal-baseline.md` — the S8 baseline/diff mechanics for all three signal
  sources (`exception.log`, other `var/log/*.log`, `var/report/**`), the level/attribution
  policy, the exit-code contract, and the "no new/unresolved gating signals" pass rule.

Scripts: `${CLAUDE_SKILL_DIR}/scripts/smoke-baseline.sh` (S1), `smoke-tail-since.sh` (S8),
`smoke-browser.mjs` (browser S3–S7), `curl`/PHP-cURL (S2).

**The loop (S9 decision):** 0 Critical + 0 High → Phase 6 passes → Phase 7. ≥1 Critical/High and
iteration < 5 → delegate fixes per `smoke-test-guide.md` §Fix Routing — passing
`--docs-root=.docs/{FeatureName}` to whichever sub-skill handles the fix, per the **One artifact
home** Core Rule — re-deploy via `deploy --docs-root=.docs/{FeatureName}` if code changed,
then re-enter from 6A. ≥1 Critical/High and iteration == 5 →
halt and prompt the user. Record each iteration via `templates/smoke-run-report.md` and keep
`templates/smoke-findings.md` updated (stable finding IDs across iterations).

---

- `templates/smoke-run-report.md`: per-iteration smoke run report template.
- `templates/smoke-scenarios.md`: REST scenarios template.
- `templates/smoke-findings.md`: consolidated, cross-iteration findings template.
- `${CLAUDE_SKILL_DIR}/scripts/smoke-baseline.sh`: S1 — capture the error-signal baseline (all `var/log/*.log` + `var/report/**`).
- `${CLAUDE_SKILL_DIR}/scripts/smoke-tail-since.sh`: S8 — diff every error signal since baseline; emits `signals.json`.
- `${CLAUDE_SKILL_DIR}/scripts/smoke-browser.mjs`: S3–S7 — headless browser driver (Playwright → Puppeteer; neither available → exit 78).
- `frontend`: invoked (in augment mode) by Phase 6B S9 for frontend
  regressions (JS console errors, missing assets, KO bind errors).
