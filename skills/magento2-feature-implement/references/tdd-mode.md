# TDD Mode (test-first execution)

Phase 5 optionally implements **behaviour-bearing** tasks test-first (red → green → refactor)
instead of test-last. Off by default to preserve existing flows; opt in via any of:

- CLI flag: `--tdd` (and `--no-tdd` to force off)
- CLAUDE.md: `Feature implement: tdd = on`
- Env var: `MAGENTO2_FI_TDD=1`

When ANY of the three is set, TDD mode is on. The canonical loop and the behaviour/boilerplate
line are defined once in `magento2-context/references/tdd-discipline.md` — this file only covers
how `magento2-feature-implement` applies it.

## Per-mode applicability

| Mode | TDD mode |
|------|----------|
| `feature` | Honours the flag. Recommended on. |
| `extend` | Honours the flag. Recommended on (a single surface is easy to drive test-first). |
| `hotfix` | Already test-coverage-required; when the change is a defect, it follows the same loop as `magento2-bug-fix`. |
| `spike` | **Exempt** — throwaway exploration (matches the TDD-skill prototype exception). Tests are not required; findings logged at Info. |

## What changes in Phase 5 when TDD mode is on

The task graph does not change shape; the discipline moves *inside* each behaviour-bearing task.

1. **Acceptance criteria become the RED test list.** Each acceptance criterion written in Phase 4
   is turned into one failing test, authored **before** the implementing code (see
   *acceptance-criteria-as-tests* in `tdd-discipline.md`).
2. **`M*` / `X*` behaviour is written test-first.** For any class that carries behaviour
   (`Service`, `Model` with logic, `Plugin`, `Observer`, `Console/Command`, `Resolver`,
   data-patch transforms): scaffold the **signature** (interface + a body that throws
   `not implemented` — exempt scaffold), write the failing test, watch it fail for the right
   reason, then fill the minimal body to green. Pure scaffold/config (registration, DI, module.xml,
   plain DTOs, db_schema) stays generated-then-covered, not test-first.
3. **`T*` becomes a top-up, not the first author.** Because the behaviour tests were written
   inside the `M*`/`X*` tasks, the `T*` task (and Phase 6A) **verify** the suite and add coverage
   only for exempt/boilerplate classes — they no longer author the behaviour's first test.
   `magento2-test-generate` is still used here for that backfill; it is not the primary author of
   behaviour tests under TDD mode.
4. **Evidence.** With `--per-task-commits` on, a behaviour task's test lands at or before its
   implementation commit, so the history shows the test preceding the code.

## What does NOT change

- The two approval gates (blueprint, plan) are unchanged.
- The Per-task completion protocol (mark `[x]` in `plan.md`, save, optional commit) is unchanged.
- When TDD mode is **off**, Phase 5 behaves exactly as documented in `SKILL.md` (test-last).
- When a Magento install is unavailable, follow the *tiered fallback* in `tdd-discipline.md`
  (prefer a test-first unit test; mark a skipped integration test with its reason; never report
  untested behaviour as done).
