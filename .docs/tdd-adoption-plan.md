# Widening TDD across the Magento 2 development flow

**Status:** Partially implemented (2026-06-15). See *Implementation status* below.
**Scope:** the `magento2-tools` plugin (17 skills under `skills/`).
**Date:** 2026-06-15
**Author:** analysis for Serge Autushka

---

## 0. Implementation status (2026-06-15)

Implemented in this pass (all 26 contract tests green):

- **Move 1 — shared discipline + orchestrator.** New shared reference
  `skills/magento2-context/references/tdd-discipline.md` (red→green→refactor + behaviour/
  boilerplate line + interface-first seam + Magento specifics + tiered fallback).
  `magento2-bug-fix` now points at it. `magento2-feature-implement` (2.6.0 → **2.7.0**) gains
  opt-in **TDD mode** (`--tdd` / `Feature implement: tdd = on` / `MAGENTO2_FI_TDD=1`, default off,
  `spike` exempt) via new `references/tdd-mode.md`; Phase 5 `M*`/`X*` behaviour goes test-first,
  Phase 4 acceptance criteria seed the RED tests, `T*` becomes a coverage top-up.
- **Move 2 — data-migration + EAV only.** `magento2-data-migration` (1.1.1 → **1.2.0**) and
  `magento2-eav-attribute` (1.1.2 → **1.2.0**) now do *Test First, then Generate*: a failing
  integration test asserts state/scope/wiring **and idempotency** before the patch, with a
  tiered unit fallback when no test DB is available.

Deliberately **not** done (per direction):

- **`magento2-test-generate` positioning** — left as-is; it is the right tool for backfilling
  modules that have no tests.
- **Move 3 — `magento2-module-review` test-first enforcement** — skipped; the review skill must
  stay usable on modules that legitimately have no tests, so no test-first gate was added.
- **graphql-create / frontend-create / module-create** — out of scope this pass (§4.4/§4.6 remain
  proposals for a later iteration).
- **`magento2-context` was not version-bumped** — adding a cross-cutting reference doc doesn't
  change its resolved JSON/schema/probes, and a bump would force-touch 17 files pinning
  `magento2-context@1.6.0` for no behavioural reason.

The sections below are the original analysis; §4.3, §4.5, §4.6 and the graphql/frontend parts of
§4.4 describe deferred work, not what shipped.

---

## 1. TL;DR

The toolkit already contains a **working, disciplined TDD loop** — but only in one place:
`magento2-bug-fix`. Every other code-writing path is **test-after**: code is generated
first, then tests are produced (often by `magento2-test-generate`, a backfiller) and merely
*validated* later. Tests-after gives coverage but loses the thing TDD exists for — proof the
test can fail, and design pressure exerted *before* the code is written.

**The recommendation is not "force strict red-green everywhere."** Magento modules are mostly
scaffolding and configuration, where strict TDD adds friction without value. The recommendation
is to **draw a precise line between behaviour and boilerplate**, apply test-first discipline to
the behaviour-bearing slice, exempt the scaffold explicitly (the canonical TDD skill already
allows "generated code" and "configuration files" as exceptions), and make the discipline
**checkable** rather than aspirational.

Concretely, three moves:

1. **Lift bug-fix's loop into a shared reference** (`tdd-discipline.md`) and make
   `magento2-feature-implement` order its tasks **test-first for behaviour** (write the failing
   test, watch it fail, implement to green) instead of test-last.
2. **Give the spoke generators a test-first sub-step** for the behaviour they emit
   (`graphql-create`, `eav-attribute`, `data-migration`, `frontend-create`), and reposition
   `magento2-test-generate` as what it actually is: a **legacy/characterization backfiller**,
   not the primary feature-test mechanism.
3. **Make `magento2-module-review` enforce test-first evidence** so the discipline survives
   contact with real work.

All three are **opt-in-then-default** and mirror the existing `per-task-commits` config pattern,
so no team is forced into a flow change overnight.

---

## 2. Current state — audit

### 2.1 Per-skill testing posture

| Skill | Emits behaviour? | Has a test step? | First or after? | Gap |
|-------|------------------|------------------|-----------------|-----|
| `magento2-bug-fix` | yes (the fix) | **yes — explicit** | **test-first (red→green→refactor)** | — *(reference model)* |
| `magento2-feature-implement` | yes (orchestrates all) | yes (`T*` tasks + Phase 6A) | **after** — `T*` runs after `M*`/`X*`; 6A validates coverage | **High** — this is the top orchestrator; its ordering sets the house style |
| `magento2-test-generate` | no (additive only) | yes (its whole job) | **after by definition** — "tests for an existing module" | Medium — fine as a backfiller; wrong as the *primary* mechanism |
| `magento2-module-create` | partial (scaffold + some logic) | scaffolds `Test/Unit/` dir + templates | **after** — code generated Step 4, tests are scaffold stubs; Quick mode skips tests | Medium |
| `magento2-graphql-create` | yes (resolvers, batch loaders, auth) | yes — delegates to test-generate | **after** — Phase 3 emits resolvers, tests "after Phase 3" | Medium-High (resolvers carry real auth/scope logic) |
| `magento2-eav-attribute` | yes (patch, source/backend models) | effectively none for attribute behaviour | n/a | Medium (idempotency + scope untested) |
| `magento2-data-migration` | yes (patches, importers, transforms) | **none (0 mentions)** | n/a | **High** — idempotency/transform correctness is exactly what a test should pin |
| `magento2-frontend-create` | yes (KO components, view models, JS) | **none (0 mentions)** | n/a | Medium-High (Jasmine patterns exist in test-generate but are never invoked here) |
| `magento2-module-upgrade` | yes (BC shims) | references tests | after | Low-Medium |
| `magento2-deploy` | no | runs/relies on tests | n/a (consumer) | — |
| `magento2-module-review` | no | inspects tests | n/a (gate) | **Opportunity** — best place to *enforce* test-first |
| `context`, `i18n`, `release`, `debug`, `security-audit`, `performance-audit` | no | n/a | n/a | — (correctly test-free) |

### 2.2 The one good example, in its own words

`magento2-bug-fix` Core Rules + Phase 4 already encode the canonical loop:

> **TDD is the preferred approach.** … write the failing regression test, watch it fail for the
> right reason, then write the minimal production code to make it pass. … If the test passes
> before any fix, the test does not capture the bug or the RCA is wrong: stop and return to
> Phase 3 before writing any production code.

This is exactly the discipline from the `superpowers:test-driven-development` skill
("NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST", "watch it fail"). **The pattern is proven
inside this very toolkit.** The work is propagation, not invention.

### 2.3 Why test-after dominates (root cause, not symptom)

1. **One orchestrator sets the ordering, and it's last-test.** In `feature-implement`, the task
   types are `M*` (create) → `R*` (review) → `T*` (test) → `V*` (validate) → `D*` (deploy), with
   Phase 6A measuring coverage at the end. Tests are a *trailing* task. Everything the
   orchestrator drives inherits this shape.
2. **`test-generate` is framed as the universal test mechanism.** feature-implement's `T*` task
   and graphql-create's Phase both delegate to it, and its purpose is literally "generate tests
   for an existing module." A backfiller invoked as the default guarantees test-after.
3. **Scaffolding is generated in bulk.** `module-create` Step 4 emits dozens of files in one
   pass; there's no natural seam to write a failing test *before* a class that doesn't exist yet.
4. **No shared discipline doc.** The red→green→refactor rules live only inside bug-fix's prose,
   so they can't be referenced or enforced by other skills.

---

## 3. Design principles (what "wider TDD" should mean here)

Strict red-green on every generated `registration.php` would be theatre. The useful version of
this proposal rests on one line:

### 3.1 The behaviour / boilerplate line

| Apply test-first (RED before code) | Exempt — scaffold then cover |
|------------------------------------|------------------------------|
| `Service/` and `Model/` methods with logic | `registration.php`, `etc/module.xml`, `composer.json` |
| `Plugin/`, `Observer/`, `Console/` command logic | `etc/di.xml` and other DI/config XML |
| GraphQL `Resolver/` (auth, scope, shape, batch) | Pure DTO interfaces + getters/setters |
| Data-patch **transform/idempotency** logic | `db_schema.xml` (validated by XSD/integration, not unit) |
| EAV source/backend **model** behaviour | Plain CRUD repository wiring (cover with one integration round-trip) |
| KO component public methods / view-model logic | `.phtml`, LESS, layout XML (cover via MFTF/smoke, not unit) |

This line is **already sanctioned** by the canonical TDD skill, which lists *"Generated code"*
and *"Configuration files"* as explicit exceptions ("ask your human partner"). We're just making
the carve-out systematic instead of ad hoc.

### 3.2 Acceptance-criteria-as-tests

`feature-implement` Phase 4 already requires **acceptance criteria** per task. Those criteria are
the RED test list. The bridge is mechanical: *each acceptance criterion becomes a failing test
written before the implementing code.* This reuses an artifact the flow already produces — no new
planning burden.

### 3.3 Interface-first seam for bulk scaffolds

To get a failing test before a class exists, scaffold the **signature** (interface + empty method
that throws `not implemented`), write the test against the type, watch it fail on the throw, then
fill the body. The scaffold (signature/config) is exempt; the **body** is test-first. This makes
TDD compatible with `module-create`'s bulk generation instead of fighting it.

### 3.4 Discipline must be checkable, not just stated

bug-fix's rules work because Phase 4 forces "confirm it fails for the right reason." Spread that
by giving `module-review` a concrete, gradable check (§4.5) rather than trusting prose alone.

---

## 4. Proposed changes (per skill)

> Numbering note: P-A/P-B/P-C map to the rollout phases in §5. None of this is implemented yet.

### 4.1 New shared reference — `tdd-discipline.md` *(P-A, foundational)*

Extract bug-fix's loop into a skill-agnostic reference that any skill can load:

- Location: `skills/magento2-context/references/tdd-discipline.md` (context is the universal
  leaf every skill already depends on — natural home for cross-cutting discipline).
- Content: the red→green→refactor loop; "watch it fail for the right reason"; the behaviour /
  boilerplate table (§3.1); the interface-first seam (§3.3); Magento-specific notes (PHPUnit DI
  mocking, integration `#[DataFixture]`/`#[DbIsolation]`, when to prefer integration over unit).
- `magento2-bug-fix` then *references* this instead of owning the prose (single source of truth).

### 4.2 `magento2-feature-implement` — order tasks test-first *(P-A, highest leverage)*

This is the centre of gravity. Changes:

1. **Re-sequence behavioural tasks.** For every `M*`/`X*` task that emits behaviour, the plan
   pairs it with a **preceding** RED test step. Either:
   - split `T*` into `T*-red` (write failing test, before impl) and keep coverage top-up at
     Phase 6A; **or**
   - add a per-task rule: "behaviour-bearing tasks implement test-first per
     `tdd-discipline.md`" and have the task's acceptance criteria seed the failing tests.
2. **New `--tdd` mode flag + config**, mirroring `per-task-commits`:
   - CLI: `--tdd` / `--no-tdd`
   - `CLAUDE.md`: `Feature implement: tdd = on`
   - Env: `MAGENTO2_FI_TDD=1`
   - Default **off** for one release (announce in CHANGELOG), then **on** for `feature` and
     `extend` modes; `hotfix` follows bug-fix discipline already; `spike` stays exempt
     (throwaway — matches the TDD skill's prototype exception).
3. **Phase 6A becomes a gate, not the source.** When `--tdd` is on, 6A *verifies* that tests
   pre-existed their code (evidence below) rather than generating them late. test-generate is
   only called in 6A to **top up** coverage on exempt/boilerplate classes, never as the primary
   author of behaviour tests.
4. **Evidence of test-first.** With `--per-task-commits` on, the test commit for a behavioural
   task lands at or before its implementation commit; `module-review --diff` (§4.5) checks this.

### 4.3 `magento2-test-generate` — reposition + add characterization mode *(P-C)*

The skill is genuinely useful; the problem is *how it's invoked*. Changes:

1. **Reframe the description** from "the test mechanism" to "**legacy coverage backfiller**":
   generate tests for **pre-existing untested** code (the `--missing-only` default is already
   exactly this). Add an explicit note: "for *new* behaviour, prefer test-first via the owning
   skill; use this to backfill code that already exists."
2. **Add `--characterization` mode.** When backfilling legacy code, generate *characterization
   tests* that pin current behaviour (and say so in output), since you cannot watch those fail
   first. This is honest about what test-after can and can't prove — and keeps it out of the
   "pretend it's TDD" trap.
3. **Stop being feature-implement's default behaviour-test author** (see §4.2.3).

### 4.4 Spoke generators — add a test-first sub-step *(P-B)*

Each behaviour-emitting spoke gets a small, consistent addition that loads `tdd-discipline.md`:

- **`graphql-create`**: write the resolver test **first** (positive shape + auth-fail +
  input-error — it already lists these as acceptance criteria), watch it fail, then implement the
  resolver to green. Today it emits the resolver in Phase 3 and tests "after." Flip the order.
- **`data-migration`** *(biggest gap — 0 tests today)*: for every patch, an integration test that
  asserts (a) seeded/transformed state and (b) **idempotency** (apply twice → same result). Write
  it before the patch body. Idempotency is the skill's headline guarantee; it should be pinned by
  a test, not by inspection.
- **`eav-attribute`**: an integration test asserting the attribute exists with the declared
  **scope**, input type, and source/backend wiring after the patch runs; behavioural source/
  backend models get a unit test first.
- **`frontend-create`**: invoke test-generate's existing **Jasmine** patterns for KO components /
  view models — write the component's public-API test first where the component carries logic
  (pure presentational templates stay smoke/MFTF-covered, per §3.1).

### 4.5 `magento2-module-review` — enforce test-first evidence *(P-A/P-B, the teeth)*

Add a review check (severity **High** when `--tdd` context is active, else **Info/advisory**):

- Every behaviour-bearing class (`Service`, `Model` w/ logic, `Plugin`, `Observer`, `Resolver`,
  `Console`, data-patch with transform) has a corresponding test with **real assertions**
  (reuse test-generate's "no empty stubs / no `markTestIncomplete`" rule).
- In `--diff` mode with per-task-commits on: flag behavioural classes whose implementation commit
  has **no preceding-or-paired test commit** ("test-after detected").
- Surface a one-line **TDD compliance** summary in the review output so the gate is visible.

### 4.6 `magento2-module-create` — make the scaffold TDD-ready *(P-B)*

- Keep bulk scaffold generation (it's the exempt boilerplate), but **stop emitting empty test
  stubs** that masquerade as coverage. Instead emit **interface-first signatures** (§3.3) for
  behavioural classes so the very next step — a failing test — has a type to bind to.
- Quick Create mode stays test-free (explicitly a skeleton) but its report states "no tests —
  behaviour must be added test-first."

---

## 5. Rollout plan (ordered, low-risk first)

Each step is independently shippable and reversible. Verify before moving on.

**Phase A — Foundation + the orchestrator (highest leverage).**
- A1. Write `tdd-discipline.md` (§4.1). *Verify:* bug-fix re-references it; no behaviour change.
- A2. Add the `--tdd` flag/config to `feature-implement`, **default off**; re-sequence behavioural
  tasks to test-first under the flag (§4.2). *Verify:* run a sample `extend` feature with `--tdd`
  on; confirm the plan shows RED-before-impl and the failing test is observed.
- A3. Add the `module-review` test-first check as **advisory** (§4.5). *Verify:* it reports, never
  blocks yet.

**Phase B — Spoke generators + scaffold seam.**
- B1. `data-migration` idempotency test-first (§4.4) — start here; it's the biggest gap and the
  clearest win.
- B2. `graphql-create` order flip (§4.4).
- B3. `eav-attribute` + `frontend-create` test-first sub-steps (§4.4).
- B4. `module-create` interface-first seam; stop emitting stub tests (§4.6).
- *Verify each:* the skill's own `tests/` placeholder-token checks still pass; a sample run
  produces a failing-then-passing test.

**Phase C — Reposition the backfiller + flip defaults.**
- C1. Reframe `test-generate` + add `--characterization` (§4.3).
- C2. Promote `module-review`'s check from advisory to **High** when `--tdd` is active (§4.5).
- C3. Flip `feature-implement --tdd` **default on** for `feature`/`extend`. Announce in CHANGELOG;
  keep the escape hatch (`--no-tdd`, `tdd = off`).

**Docs (parallel with A–C):** update `docs/daily-workflows.md`, `docs/flows-and-scenarios.md`,
and `docs/skills-reference.md` to describe the test-first flow and the new flag; add a short
"TDD in this toolkit" section to `README.md`.

---

## 6. Risks, tradeoffs, and mitigations

| Risk | Mitigation |
|------|------------|
| Strict TDD slows bulk scaffolding / annoys users | Behaviour/boilerplate line (§3.1); scaffold stays exempt; flag is opt-in then default-with-escape-hatch |
| "Failing test before a class exists" is awkward in Magento | Interface-first seam (§3.3) — scaffold the signature, fail on the throw |
| Integration tests need a running Magento; CI may lack it | Tier it: unit test-first always; integration test-first when an instance is available, else mark as deferred (the flow already degrades gracefully when tools are absent) |
| Characterization tests pass immediately (can't watch fail) | `--characterization` mode labels them honestly; they're for legacy, never counted as TDD evidence |
| Two test mechanisms (test-first in skills vs test-generate) confuse users | Clear framing: skills author **new** behaviour tests test-first; test-generate **backfills** existing code only |
| Enforcement creates false positives on exempt classes | review check keys off the behaviour/boilerplate classification, not "every class needs a test" |

---

## 7. Open questions (for you to decide before implementation)

1. **Default-on timeline.** Ship `--tdd` off for one release then flip (§5 C3), or default-on
   immediately with a loud CHANGELOG note?
2. **Enforcement severity.** Should missing test-first evidence ever be **blocking** (Critical/High
   in module-review), or stay advisory so it never halts a deploy?
3. **Integration-test baseline.** How much should we lean on integration tests (need a DB/Magento
   install) vs. keeping the test-first guarantee unit-only for portability?
4. **Reference home.** `tdd-discipline.md` under `magento2-context/references/` (proposed) vs. a
   new top-level shared location — affects how other skills load it.
5. **Scope of this pass.** All four spoke generators in one go, or land `data-migration` +
   `feature-implement` first (the two highest-value gaps) and iterate?

---

## Appendix A — before/after task ordering (feature-implement)

A behavioural slice of a feature plan, e.g. "add an `OrderExportService::export()`":

**Today (test-after):**
```
M1  Create Acme_OrderExport module        # emits Service with a real body
R1  Review Acme_OrderExport
T1  Generate tests for Acme_OrderExport    # tests written against code that already works
V1  phpcs / phpstan / phpunit
6A  Measure coverage ≥ 80%                  # first time anyone watches the suite run
```

**Proposed (`--tdd`, test-first for behaviour):**
```
M1  Scaffold Acme_OrderExport              # registration/di/module.xml + Service *signature* (throws)
T1  RED: testExportWritesCsvForOrder()     # write test, run it, WATCH IT FAIL on the throw
M1' GREEN: implement export() body         # minimal code to pass T1
T1' (refactor, stay green)
R1  Review (incl. test-first evidence check)
V1  phpcs / phpstan / phpunit
6A  Verify suite + top-up coverage on exempt/boilerplate only
```

The scaffold (config + signature) is exempt; the **method body** is written only after its test
fails. Acceptance criteria from Phase 4 become the `T1…Tn` RED list.

## Appendix B — alignment with `superpowers:test-driven-development`

| Canonical rule | Where this plan honours it |
|----------------|----------------------------|
| "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" | §4.2 re-sequencing; §4.4 spoke flips |
| "Watch it fail … for the right reason" | §3.4, §4.5 evidence check; bug-fix already does this |
| Exceptions: generated code, config files, prototypes | §3.1 behaviour/boilerplate line; `spike` mode stays exempt |
| "Tests-after answer *what does this do*, not *what should this do*" | §4.3 characterization mode is labelled, never sold as TDD |
| Checklist: every new function has a test that failed first | §4.5 makes it gradable in module-review |
