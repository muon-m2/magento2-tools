---
name: magento2-bug-fix
description:
    End-to-end Magento 2 bug-fix workflow. Use when the user reports a defect, error, crash,
    exception, unexpected behaviour, or regression in an existing Magento 2 module. Drives:
    reproduce → root-cause analysis → minimal patch → regression test → review → optional
    deploy → report. Requires explicit user approval at the RCA gate before any code change.
    Calls magento2-module-review (diff mode) after the fix and magento2-deploy when
    authorized.
---

# Magento 2 Bug Fix

Surgical defect remediation. The user describes a bug; this skill drives reproduction,
root-cause analysis, the minimal fix, a regression test, and review across eight phases
(Phase 0 setup, then Phases 1–7).

## Core Rules

- **TDD is the preferred approach.** Implement every fix test-first (red → green →
  refactor): write the failing regression test, watch it fail for the right reason, then
  write the minimal production code to make it pass. The test encodes the reproduction;
  the patch exists only to turn it green. Reach for a non-TDD flow only when the bug is
  genuinely untestable (see the regression-test rule below), and document why.
  The shared red → green → refactor loop and the behaviour/boilerplate line live in
  `magento2-context/references/tdd-discipline.md` — this skill applies it to defect remediation.
- **One approval gate.** Do not change any production code until the user approves the
  root cause + proposed fix in Phase 3.
- **Minimal change.** The diff must affect only what the bug demands. No surrounding
  cleanup. No refactor. No "while we're here" edits.
- **Regression test required, with two narrow waivers.** Every bug fix produces a test
  that fails before the fix and passes after. The only exceptions are (a) a bug that is
  provably untestable (e.g. a third-party gateway outage — and most "untestable" bugs are
  actually testable with a clock injection or a mock, so push back first), and (b) a
  purely config/XML change validated by XSD instead. Either waiver must be recorded in
  the RCA and confirmed by the user before the fix lands.
- **No scope expansion.** If reproduction or RCA reveals additional bugs, file them as
  separate tasks rather than expanding the current fix.
- **Reproduce first.** If the bug can't be reproduced after 2 attempts, stop and report
  "cannot reproduce" with all evidence collected.
- **Never edit vendor/.** Fix in a project module via plugin/observer/preference. Editing
  `vendor/magento/` or any third-party module is forbidden.
- **Per-task commits.** Each phase that modifies files commits independently with the
  `[bug-fix]` prefix. See `references/commit-format.md`.
- **Coding style.** Patched/added PHP follows PER-CS 3.0 as the baseline, with the Magento 2
  coding standard taking precedence on any conflict; `--standard=Magento2` PHPCS is the gate.
  See `magento2-context/references/php-coding-style.md`. (Stay within the minimal-change rule —
  do not restyle surrounding code.)
- **Process surface is owned — don't defer it.** The reproduce → root-cause → fix loop
  (Phases 1–3) and the test-first discipline (Phase 4) are domain-tuned, owned surfaces. Do not
  route them through a generic process skill (`superpowers:systematic-debugging`,
  `superpowers:test-driven-development`) and do not replace the Phase 5 review with a generic
  one — each duplicates owned work and lacks the Magento specifics (log paths, stack-trace
  frames, ACL/escaping/EQP). Unlike `magento2-feature-implement`, bug-fix has **no** sanctioned
  defer-if-present hand-wave — it is surgical and single-threaded, so there is nothing to defer.
  The governing policy and the reasons are in `magento2-context/references/process-skills.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx.vendor}`, `{ctx.runner}`, `{ctx.magento_cli}`,
`{ctx.magento_root}`, `{ctx.tools}`. If `magento_cli` is null, reproduction Phase 2 will
be limited to static log analysis — note this up-front.

Then ensure work happens on a dedicated branch. If the current branch is the default
(`main`) or a detached HEAD, create `bugfix/{slug}` before any commit. All per-phase
commits land on that branch; the skill never pushes (see `references/commit-format.md`).

### Phase 1 — Collect

Goal: have enough information to attempt reproduction.

1. Parse the user's bug description.
2. Ask for any of the following that's missing (one batch — do not interrupt later):
    - **Symptom**: visible failure?
    - **Trigger**: action that causes it?
    - **Scope**: customer-facing / admin / REST / GraphQL / cron / queue / CLI?
    - **Environment**: production / staging / local; Magento version; module list.
    - **Error**: exact error message or stack trace.
    - **First seen**: date / commit / deploy.
3. Pull relevant log files. Defaults (resolved against `{ctx.magento_root}`):
    - `var/log/system.log`
    - `var/log/exception.log`
    - `var/log/debug.log`
    - Any module-specific log mentioned in the symptom.
4. Grep logs for the symptom signature.

Save the initial collection notes to `.docs/bug-fixes/{slug}/collect.md`.

### Phase 2 — Reproduce

Goal: make the failure happen deterministically.

1. Identify the entry point (URL / CLI / cron job / queue topic).
2. Build the minimal reproduction recipe — see `references/reproduction-patterns.md`.
3. Run the reproduction (or hand it to the user if it requires interactive auth).
4. Capture the failure output and any new log entries.
5. If a live reproduction fails twice, do **not** immediately give up: attempt to encode
   the defect as a failing automated test straight from the stack trace and RCA evidence
   (inject a clock, mock the third party — see `references/regression-test-patterns.md`).
   A failing test is itself a valid reproduction. Only report "cannot reproduce" when
   neither a live recipe nor a failing test can be produced.

The runtime recipe is scaffolding to *find* the failing assertion; the regression test
written in Phase 4 is the durable reproduction artifact. Save the recipe to
`.docs/bug-fixes/{slug}/reproduction.md`.

### Phase 3 — Root-Cause Analysis (APPROVAL GATE)

Goal: locate the exact code line(s) responsible.

1. Follow the stack trace from the entry point through the module(s). See
   `references/stack-trace-reading.md` for tips on plugin/observer/preference frames.
2. For each frame: is the call legitimate? Does it return the expected value?
3. Identify the first frame where behaviour diverges from intent.
4. Read the surrounding code, `git blame`, and recent commits.
5. Write the RCA per `references/rca-format.md`:
    - **Defect location**: `file:line`
    - **Defect description**: what's wrong, in plain English
    - **Why**: history (last-touched commit, original intent)
    - **Proposed fix**: minimal change description (do not write code yet)
    - **Regression test plan**: which test class, what assertion
6. Save RCA to `.docs/bug-fixes/{slug}/rca.md`.
7. Present RCA. **Wait for explicit approval** ("proceed", "yes", "approved").

### Phase 4 — Patch + Regression Test (TDD)

Goal: minimal patch + a test that fails before, passes after. Follow red → green →
refactor.

1. **Write the test first (RED).** Add the test under
   `{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/...` (or `Test/Integration/...`
   if the bug requires DB state). Prefer appending a `testRegression{Behaviour}()` method
   to the module's existing test class for that subject; create a new file only when none
   exists. Follow the location and naming convention in
   `references/regression-test-patterns.md` and start from the matching
   `templates/regression-test-*.php` skeleton.
2. Run the test. **Confirm it fails for the right reason** — the assertion must fail
   with the bug's symptom, not a setup error, fatal, or missing-class error. If the test
   passes before any fix, the test does not capture the bug or the RCA is wrong: stop and
   return to Phase 3 before writing any production code.
3. Apply the minimal patch (GREEN). Write only the code needed to satisfy the failing
   assertion — no more.
4. Run the test. Confirm it passes.
5. Run the full test suite for the affected module, then the project's static checks
   (`{ctx.tools}` — PHPCS/PHPStan). Confirm no other tests broke and the patch is clean
   (REFACTOR: tidy only the lines you touched, keeping the test green).
6. **Apply the shared module-hygiene baseline (required).** After modifying or adding PHP
   files (the patch and the new regression test), run
   `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/add-license-headers.sh {ctx.magento_root}/app/code/{Vendor}/{Module} {Vendor}`
   to stamp the standard copyright header onto every new `.php` (idempotent — it skips files
   that already carry it, so existing patched files are left as-is). On the rare occasion the
   fix adds a `composer.json` `require` entry, resolve a **bounded** constraint via
   `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-dep-constraint.sh <vendor/package>`
   — never `"*"`. See `magento2-context/references/module-hygiene.md`.
7. Commit per `references/commit-format.md`:
   ```
   [bug-fix] {Module}: {symptom}

   RCA: .docs/bug-fixes/{slug}/rca.md
   Files: {list}
   ```

### Phase 5 — Review

1. Invoke `magento2-module-review --diff` on each modified module.
2. Fix any new Critical/High findings introduced by the patch (do not silently leave
   them — they would re-introduce risk on top of the bug fix).
3. Re-run tests after each fix.
4. Commit each review-fix as `[bug-fix] {Module}: review fix - {finding}`.

### Phase 6 — Deploy (Optional)

1. If user authorizes deploy: invoke `magento2-deploy --env={target}`.
2. After deploy, re-run the original reproduction recipe. Assert success.
3. If smoke fails after deploy, follow `magento2-deploy`'s rollback recipe and report.

### Phase 7 — Report

Save report per `templates/report.md` to `.docs/bug-fixes/{slug}/report.md`:

- Symptom
- Reproduction recipe (path)
- Root cause (link to RCA)
- Fix description + files changed
- Regression test path
- Review findings remediated
- Deploy result (if Phase 6 ran)
- Severity classification

Optional: open a PR. Same shape as `magento2-feature-implement` PR step.

## Bug Classification

Classify at the start of Phase 7 (do not let classification gate Phase 6 — the fix is
already in):

| Class    | Definition                                  | Default deploy timing            |
|----------|---------------------------------------------|----------------------------------|
| Critical | Production down, data loss, security breach | Immediate                        |
| High     | Major functional break on common path       | Next deploy window               |
| Medium   | Edge case with workaround                   | Bundled with next feature deploy |
| Low      | Cosmetic / minor inconvenience              | Discretionary                    |

## Edge Cases

| Case                                                              | Behaviour                                                                                                                      |
|-------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Bug in vendor/ third-party module                                 | RCA proceeds; fix proposed as a plugin/observer in a project module, not as a vendor edit.                                     |
| Bug in Magento core                                               | Same: plugin/observer in a project module. Never edit `vendor/magento/`.                                                       |
| Bug spans ≥ 2 modules                                             | Per-task commits; RCA covers each module separately; one report.                                                               |
| Bug can't be reproduced                                           | Phase 2 fails after 2 attempts; report "cannot reproduce" with all evidence collected.                                         |
| Fix requires a **schema** change (`db_schema.xml`)                | Stop; redirect to `magento2-feature-implement --mode=extend`. Bug-fix is for code-only changes.                                |
| Fix requires a **data** repair (correct corrupted rows, backfill) | Stays in-skill: write an idempotent data patch via `magento2-data-migration`; the regression test asserts the corrected state. |
| Bug is in a config file only                                      | Config/XSD-validation waiver applies (see Core Rules); document why no PHPUnit test in the RCA.                                |

## Inputs

```
/magento2-bug-fix "<bug description>"
```

Optional flags:

- `--module=<Vendor>_<Module>` — constrain RCA to a single module.
- `--log=<path>` — additional log file beyond the defaults.
- `--no-deploy` — skip Phase 6.
- `--severity=critical|high|medium|low` — pre-classify.

## Outputs

```
.docs/bug-fixes/{slug}/
├── collect.md      # Phase 1 evidence
├── reproduction.md # Phase 2 recipe
├── rca.md          # Phase 3 RCA
└── report.md       # Phase 7 final report
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under `{ctx.magento_root}`,
`app/code`, or a module dir. See the **Artifact location** rule in `magento2-context/SKILL.md`.

Plus per-task git commits per `references/commit-format.md`.

## Reference Files

- `references/log-targets.md` — bug-fix log-collection specifics; defers to the shared
  `magento2-debug/references/log-locations.md` for the canonical log-path catalogue.
- `references/reproduction-patterns.md` — HTTP / CLI / cron / queue / GraphQL recipes.
- `references/stack-trace-reading.md` — how to follow a Magento stack trace through plugins.
- `references/rca-format.md` — RCA document structure and required sections.
- `references/regression-test-patterns.md` — patterns by bug class (DI, plugin, observer, query, controller).
- `references/deferred-bugs.md` — when to file a new bug vs expand current scope.
- `references/commit-format.md` — `[bug-fix]` commit message format.

## Templates

- `templates/rca.md`
- `templates/report.md`
- `templates/regression-test-unit.php`
- `templates/regression-test-integration.php`
- `templates/regression-test-controller.php`

## Related Skills

| Phase         | Skill                                                                                |
|---------------|--------------------------------------------------------------------------------------|
| 0             | `magento2-context`                                                                   |
| 4             | `magento2-data-migration` (only when the fix is a data repair)                       |
| 5             | `magento2-module-review` (with `--diff`)                                             |
| 6             | `magento2-deploy` (if user authorizes)                                               |
| (alternative) | `magento2-debug` — when reproduction fails and you need to investigate logs/DI graph |

This skill **does not** invoke `magento2-module-create` (no new modules) or
`magento2-feature-implement` (different shape).
