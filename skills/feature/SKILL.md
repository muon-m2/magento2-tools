---
name: feature
version: 2.15.2
description: >-
  End-to-end Magento 2 feature orchestrator. Use to add, change, build, or implement any Magento 2
  functionality, from a model change to a multi-module integration: analysis, blueprint, code,
  review, tests, report. Requires user approval at two gates before writing code. Also resumes a
  feature when the request names a `.docs/{FeatureName}` folder; otherwise starts a new one.
  Single-surface work: magento2-tools:admin-form, magento2-tools:graphql, or
  magento2-tools:eav-attribute.
---

# Magento 2 Feature Implement

End-to-end orchestration skill. The user describes a Magento 2 feature or change; this skill drives
the full implementation from analysis through tested, reviewed, reported delivery across 7 phases.

## Core Rules

Read `references/core-rules-detail.md` when a rule's one-liner is not enough.

- **Mode-driven.** Pick `feature` (default), `hotfix`, `extend` or `spike` in Phase 1 (`references/modes.md`); `hotfix` skips Phases 3-4, `extend` only 3.
- **Two approval gates.** Do not write any code until the user approves both the feature blueprint
  (after Phase 2) and the task plan (after Phase 4). Affirmative replies: "proceed", "yes", "go",
  "approved", "ok", or equivalent. In `hotfix` and `extend` mode only the blueprint gate applies.
- **Blueprint first.** Save the blueprint before building the module schema. The module schema
  derives from the blueprint — not from assumptions.
- **Save before present.** Write `blueprint.md`, `plan.md` and task records to disk and read them back before presenting; cite the path, never present from memory.
- **Ask once.** Gather all clarifying questions in a single batch during Phase 1. Never interrupt
  mid-execution with more questions unless a blocking ambiguity is discovered.
- **Continuous execution.** After the plan gate, Phases 5-7 run without check-ins; a finished task cues the next. Stop only for: a blocking ambiguity, an unobtainable input, the smoke cap, 7B done.
- **Review every module.** After creating or modifying any module, invoke `review`.
  Fix all Critical and High findings before continuing to the next task.
- **Tests must pass.** All unit tests must complete with zero failures before Phase 7. Never mark
  implementation complete with failing tests.
- **Test-first for behaviour (opt-in).** TDD on (`--tdd`, CLAUDE.md, `MAGENTO2_FI_TDD=1`): behaviour-bearing `M*`/`X*` tasks run red → green → refactor; `spike` exempt (`references/tdd-mode.md`).
- **Smoke before report.** Phase 6 runs **6A** (unit tests + coverage) then **6B** (smoke battery); Phase 7 waits until no Critical/High smoke finding is open.
- **Smoke tooling is policy, not preference.** `curl` for REST/GraphQL; **headless** browser for admin/storefront, never headed or a browser-automation MCP server; no browser ⇒ curl tier + Medium finding. A user directive outranks every probe (`context/references/runtime-test-tooling.md`).
- **Smoke loop is bounded.** Critical/High smoke findings are auto-routed to the right
  sub-skill of this pack for remediation, then Phase 6 re-runs from 6A. The loop halts at **5
  iterations** and asks the user how to proceed (`retry` / `accept-known-issues <IDs>` / `abort`).
- **No empty implementations.** Do not create stub classes with `// TODO` bodies and report them
  as done. Every generated file must contain real implementation content.
- **All diagrams are Mermaid.** Every diagram in every document — dependency graphs, flow charts,
  module schemas, ER diagrams — must use Mermaid syntax. No ASCII art or external image links.
- **Document before report (required).** 7B may not start until the 7A documentation set is on disk and current (`references/documentation-guide.md`).
- **Guides and user docs are HTML.** One shared inline CSS color schema; each HTML file declares `<meta charset="utf-8">` first in `<head>`.
- **Per-task git commits (opt-in).** `--per-task-commits`, CLAUDE.md or `MAGENTO2_FI_PER_TASK_COMMITS=1` ⇒ one commit per Phase 5 task (`references/per-task-commits.md`).
- **Model tiering.** Advisory `Model tier` per task; every `Agent` call sets `model`, and comprehension/findings go to `explorer`/`reviewer`, never `Explore`/`general-purpose` (`context/references/execution-modes.md` §"Subagent dispatch").
- **Delegate by probing, never by assumption.** Attempt the sub-skill's `Skill` call; fall back inline only on a real failure, and record it. Never pre-declare one unreachable.
- **Deploy delegation.** D* tasks delegate to `deploy` (module list + environment); `feature` never runs `bin/magento` itself.
- **One artifact home.** Every sub-skill is invoked with `--docs-root=.docs/{FeatureName}`
  so the whole run's reports nest under the feature folder (see
  `context/references/artifact-layout.md`). Never invoke a sub-skill without it.
- **Source of truth.** During planning and generation, do NOT scan unrelated modules under
  `app/code`/`vendor/*`/Magento core for conventions; the generator sub-skills build from their
  templates + shared references. Read only the target of the change and the contracts of modules it
  explicitly depends on. See `context/references/source-of-truth.md`.
- **Output budget.** Follow `context/references/output-budget.md` — targeted reads, summary-first test/lint output, long logs to files.
- **After a context compaction,** re-read the reference for the phase in progress before continuing.

---

## Feature Folder Structure

Each feature lives in `.docs/{FeatureName}/` at the project root; sub-skill reports nest by category, e.g. `.docs/{FeatureName}/reviews/`.
**Read `references/feature-folder-structure.md` before creating it in Phase 2.**

---

## Phase 0 — Resume Check

**Goal:** detect explicit resume requests before running Phase 1.

This phase only fires when the user names a specific feature folder in the request.
Auto-scanning of `.docs/` is intentionally disabled — without an explicit path the
skill treats the request as a new feature.

1. Parse the user request for a path matching `.docs/{FeatureName}` — accept any of:
    - leading `./` or none (`.docs/CaseManagement`, `./.docs/CaseManagement`)
    - `.docs/` or `docs/` (some users elide the leading dot)
    - trailing `/`, `/plan.md`, or `/blueprint.md` are tolerated and stripped
      Examples that match:
    - *"resume execution of ./.docs/CaseManagement"*
    - *"continue .docs/CaseManagement"*
    - *"finish .docs/CaseManagement/plan.md"*
      Examples that do NOT match (fall through to Phase 1 as a new feature):
    - *"continue the plan"*, *"resume what we were doing"*, *"pick up the case stuff"*
2. If no such path is present in the request: skip Phase 0 entirely and start Phase 1.
3. If a path is present:
    1. Verify `.docs/{FeatureName}/plan.md` exists. If not, tell the user the folder has
       no plan and stop — do NOT silently fall back to Phase 1. The user explicitly
       asked to resume; restarting from scratch would destroy work.
    2. Verify `.docs/{FeatureName}/blueprint.md` exists and read its `Status:` line.
        - `Status: Complete` — tell the user the feature is already done and ask whether
          they want to extend it (which is a different mode) before doing anything else.
        - `Status: Awaiting Approval` — the plan never got the Phase 4 approval gate;
          present the existing blueprint + plan and re-enter Phase 4 at the approval prompt.
        - `Status: Approved` or `Status: In Progress` — proceed to step 3 below.
    3. Announce the feature: name, mode (from blueprint), and a summary of completed vs
       pending tasks from `plan.md`'s **Current State** checklist (count of `[x]` vs
       `[ ]` and the next unchecked task ID/title).
    4. Jump directly to **Phase 5 "Resuming a partial run"**. Do NOT re-elicit, do NOT
       re-plan, do NOT re-prompt for the blueprint or plan approval gates — the user
       already approved when the plan was first written.
    5. Continue execution from the first unchecked task in `plan.md`. All standard
       Phase 5 rules (per-task review, per-task commit if enabled, checkbox update on
       completion) apply unchanged.

---

## Phase 1 — Elicit and Analyze

**Goal:** understand the feature well enough to write a complete blueprint.

Pick the mode, resolve `{Vendor}` (prefer `{ctx.vendor}`; never hardcoded), ask clarifying questions in one batch, state your understanding.
**Read `references/phase1-4-design.md` before starting this phase.**

**Multi-spec requests.** If the request names more than one spec or feature, run the first only (say which; list the rest). After Phase 7B, `AskUserQuestion`: "N specs remain: `<list>`. Continue here, or `/clear` and start the next fresh? (each feature adds ~150–300k tokens of context)" Options: **`/clear` and start fresh (Recommended)** — print `/magento2-tools:feature <remaining specs>` to run after `/clear`; **Continue here** — proceed to the next spec in place. Never hard-stop; no queue file.

---

## Phase 2 — Feature Blueprint

**Goal:** produce a complete, approved blueprint.

**Read `references/phase1-4-design.md` before starting this phase** (steps 1–3).

4. Create the feature folder `{ctx.docs_root}/{FeatureName}/` if it does not exist (anchored at the
   project root per the **Artifact location** rule — never under `{ctx.magento_root}`).
   **Write** the blueprint to `.docs/{FeatureName}/blueprint.md` with `Status: Awaiting Approval`
   as the first line. This file MUST exist on disk before step 5 — do not present a blueprint that
   has not been saved (per the **Save before present** rule).
5. **Confirm the file is on disk** (read it back), then present the complete blueprint to the user
   and cite its path: *"Blueprint saved to `.docs/{FeatureName}/blueprint.md` — review there or below."*
6. Before accepting approval, scan section 12 (Open Questions). If any question is marked blocking
   and unresolved, present it inline with the blueprint and wait for an answer before proceeding.
   This is the one permitted exception to the "ask once" rule from Phase 1.
7. **Wait for explicit approval.** Do not proceed to Phase 3 until the user approves the blueprint.
   If the user requests changes, revise, save again, and re-confirm on disk before presenting.

---

## Phase 3 — Module Schema

**Goal:** decide exactly which modules own which parts of the feature.

New-vs-modify matrix, surfaces, Mermaid `graph TD` schema. **No approval pause** — present it with the Phase 4 plan.
**Read `references/phase1-4-design.md` before starting this phase.**

---

## Phase 4 — Task Breakdown and Approval Gate

**Goal:** produce a detailed, approved implementation plan.

**Read `references/phase1-4-design.md` before starting this phase** — steps 1–7 in full. Condensed:

6. **Write `plan.md` AND the detailed task records to disk for review — before presenting and
   before the approval gate.** `plan.md` (`templates/plan.md`): `Status: Awaiting Approval`,
   three Mermaid diagrams, the **Current State** checklist (`- [ ] {ID}: {Title}`), summary
   table — no task records; those go to `tasks.md` (≤ 5) or `tasks/` (> 5). All MUST exist on
   disk before step 7.
7. **Confirm `plan.md` and the task records are on disk** (read them back), then present the plan
   inline, citing the paths.
8. Print the approval prompt verbatim:
   > **Plan ready for approval.**
   > Tasks: {N} | Modules to create: {N} | Modules to modify: {N}
   > Estimated total effort: {sum}
   >
   > Reply **"proceed"** to begin implementation, or describe any changes to the plan.
9. **Wait for explicit approval.** Do not write any code until the user approves. The `plan.md`
   and task records already exist on disk (step 6) for review. If the user requests changes, revise
   **both** `plan.md` and the affected task records, keep them in sync, re-confirm on disk, and
   present again. Once approved:
    - Update the blueprint status line to `Status: Approved` in `.docs/{FeatureName}/blueprint.md`.
    - Update the `plan.md` status line to `Status: Approved`.
    - No further record-writing is needed here — the detailed task records were written in step 6;
      just ensure they reflect any last-round revisions before Phase 5 begins.

---

## Phase 5 — Execute

**Goal:** implement all tasks in dependency order.

**At Phase 5 start:** update the status line to `Status: In Progress` in both
`.docs/{FeatureName}/blueprint.md` and `.docs/{FeatureName}/plan.md`.

**Resuming a partial run:** if `.docs/{FeatureName}/plan.md` exists with `Status: In Progress`,
read `plan.md` and identify completed tasks by their checked `[x]` checkboxes in the Current State
section. Read the task records from `tasks.md` or `tasks/` and resume from the first unchecked
item. Do not re-run tasks already marked complete. Mark each task `[x]` in `plan.md` immediately
after it completes and save the file before starting the next task.

**Read `references/phase5-task-types.md` before starting this phase** (env context, fallback, task types in full).

### Environment context (resolve once, before Phase 5 tool steps)

**Invoke the `context` skill**; use `{runner}` = `{ctx.runner}`, `{magento}` = `{ctx.magento_cli}` (null ⇒ manual next steps), tools = `{ctx.tools.*}` (null ⇒ skip and report). Never hardcode a runner.

---

Work through the approved task list in dependency order; `Parallel: yes` tasks may run as sub-agents per `references/task-breakdown-guide.md`. For each task:

### Per-task completion protocol (mandatory — closes every task type below)

A task is **not done until its checkbox is flipped in `plan.md`.** This step is part of the
task, not optional bookkeeping, and is **not** deferred to Phase 6 or 7 — an unchecked
completed task breaks resume. After a task's acceptance criteria are met, **before starting
the next task**, run these steps in order:

1. Open `.docs/{FeatureName}/plan.md` and change this task's line in `## Current State`
   from `- [ ] {ID}: …` to `- [x] {ID}: …`.
2. Save `plan.md`, then read the line back to confirm the `[x]` landed. If `## Current State`
   has no line for this task (e.g. a `extend` plan that listed only some tasks), add one as
   `- [x] {ID}: {Title}` so resume can still see it.
3. If per-task commits are enabled (see Core Rules), make the commit now.
4. Do **not** begin the next task until `plan.md` shows `[x]` for the task just finished.
   This is an *ordering* constraint on steps 1-3, not a pause: it sequences the bookkeeping
   ahead of the next task, it does not end the turn.
5. **Immediately begin the next unchecked task** — in the same turn, with no progress summary
   and no check-in (Core Rules → **Continuous execution**). When the task just closed was the
   last one, roll straight into Phase 6.

Every task subsection below ends with **"→ run the Per-task completion protocol"** — that is
the cue to perform these five steps. When tasks run in parallel (same wave), apply the
protocol once per task as each one finishes, not once for the whole wave.

### Fallback discipline (applies to every delegating task below)

Fall back inline only when the `Skill` call actually fails; then keep the type prefix (never relabel to `X`), generate from the skill's own `references/`, and record the failure on the `Skill:` line. `D*` never runs inline.

### Task types (M*, X*, R*, T*, E*, G*, I*, C*, L*, Q*, V*, D*)

Each delegates with `--docs-root=.docs/{FeatureName}` and ends with **"→ run the Per-task completion protocol"**.

---

## Phase 6 — Test

**6A** unit tests + coverage, then **6B** smoke battery; each iteration re-enters from 6A, halting at 5 per **Smoke loop is bounded**.
Refuse to run against production unless `CLAUDE.md` contains `Allow smoke on production: true`.
**Read `references/phase6-test.md` before starting this phase.**

---

## Phase 7 — Documentation and Final Report

**7A** documentation is **required** — on disk and current before **7B**, the final report.
**Read `references/phase7-docs-report.md` before starting this phase.**
After 7B, if specs remain, run the **Multi-spec requests** ask (Phase 1).

---

## Reference Files

| Reference | Read when |
|---|---|
| `references/core-rules-detail.md` | a rule's one-liner is not enough |
| `references/feature-folder-structure.md` | Phase 2 |
| `references/modes.md` | Phase 1 |
| `references/phase1-4-design.md` | Phases 1–4 |
| `references/feature-blueprint-format.md` | Phase 2 |
| `references/module-schema-guide.md` | Phase 3 |
| `references/task-breakdown-guide.md` | Phases 4, 5 |
| `references/tdd-mode.md` | TDD on |
| `references/per-task-commits.md` | per-task commits on |
| `references/phase5-task-types.md` | Phase 5 |
| `references/phase6-test.md` | Phase 6 |
| `references/smoke-test-guide.md` | Phase 6B |
| `references/smoke-runner.md` | Phase 6B |
| `references/error-signal-baseline.md` | Phase 6B |
| `references/phase7-docs-report.md` | Phase 7 |
| `references/documentation-guide.md` | Phase 7A |
| `references/final-report-format.md` | Phase 7B |
| `references/tradeoffs-catalog.md` | Phase 7B |

- `context/references/source-of-truth.md` — source-of-truth hierarchy + the no-unrelated-module-scanning rule.

## Related Skills

Invoke all related skills via the `Skill` tool. Do not spawn separate agents for sub-skill
invocations — the `Skill` tool preserves conversation context across phases.

| Skill | For |
|---|---|
| `module-create` | M* |
| `review` | R* (`--diff`) |
| `test-generate` | T*, 6A |
| `eav-attribute` | E* |
| `graphql` | G* |
| `extension-point` | I* |
| `system-config` | C* |
| `cli-command` | L* |
| `message-queue` | Q* |
| `lint` | V* |
| `deploy` | D*, 6B fixes |
| `docs` | 7A, per module |
| `fix` | 6B S9 default |
| `debug` | 6B S9 error signals |
| `perf-audit` | 6B S9 slow/N+1 |
| `security` | 6B S9 ACL, CSRF |
| `frontend` | 6B S9 (augment) |
| `data-migration` | 6B S9 patches |
