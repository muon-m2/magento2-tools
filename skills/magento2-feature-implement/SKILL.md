---
name: magento2-feature-implement
description:
  End-to-end Magento 2 feature implementation orchestrator. Use when the user asks to add,
  change, build, or implement any Magento 2 functionality — from a simple model change to a
  multi-module integration. Drives the full lifecycle: requirement analysis, blueprint, module
  schema, task breakdown, code generation, review, unit tests, smoke testing, and final report.
  Requires explicit user approval at two gates (blueprint and task plan) before writing code.
  Calls magento2-module-create, magento2-module-review, and routes Critical/High findings to
  bug-fix / debug / performance-audit / frontend-create / security-audit.
  Also use to resume, continue, pick up, or finish a feature when the request names a specific
  feature folder under `.docs/` (e.g. "resume ./.docs/CaseManagement"): the skill loads that
  folder's plan.md and resumes from the first unchecked task. Without an explicit
  `.docs/{FeatureName}` path, treat the request as a new feature and start from Phase 1.
---

# Magento 2 Feature Implement

End-to-end orchestration skill. The user describes a Magento 2 feature or change; this skill drives
the full implementation from analysis through tested, reviewed, reported delivery across 7 phases.

## Core Rules

- **Mode-driven.** Pick a mode in Phase 1 (`feature`, `hotfix`, `extend`, `spike`).
  See `references/modes.md`. Default: `feature`. `hotfix` skips Phases 3-4 entirely;
  `extend` skips Phase 3 only and keeps a **minimal Phase 4** that still writes `plan.md`
  with a `## Current State` checklist — so every mode that executes tasks has a checklist
  to maintain and resume from.
- **Two approval gates.** Do not write any code until the user approves both the feature blueprint
  (after Phase 2) and the task plan (after Phase 4). Affirmative replies: "proceed", "yes", "go",
  "approved", "ok", or equivalent. In `hotfix` and `extend` mode only the blueprint gate applies.
- **Blueprint first.** Save the blueprint before building the module schema. The module schema
  derives from the blueprint — not from assumptions.
- **Save before present.** Every review artifact (`blueprint.md` in Phase 2, `plan.md` in Phase 4)
  must be **written to disk and confirmed to exist** before it is presented to the user — never
  present one from memory. After writing, verify the file is on disk (e.g. read it back) and cite
  its path in the message. The user reviews the file, not just the chat. This applies to the
  detailed task records too (`tasks.md` / `tasks/`): they are written **before** the Phase 4
  approval gate, alongside `plan.md`, so the user can review the full task detail — not just the
  index — before approving. They are still kept **out** of `plan.md` itself (no duplication).
- **Ask once.** Gather all clarifying questions in a single batch during Phase 1. Never interrupt
  mid-execution with more questions unless a blocking ambiguity is discovered.
- **Review every module.** After creating or modifying any module, invoke `magento2-module-review`.
  Fix all Critical and High findings before continuing to the next task.
- **Tests must pass.** All unit tests must complete with zero failures before Phase 7. Never mark
  implementation complete with failing tests.
- **Test-first for behaviour (opt-in).** When TDD mode is on (`--tdd`, CLAUDE.md
  `Feature implement: tdd = on`, or `MAGENTO2_FI_TDD=1`), behaviour-bearing `M*`/`X*` tasks are
  implemented test-first (red → green → refactor): write the failing test, watch it fail for the
  right reason, then write the minimal code to pass. Pure scaffold/config stays generated-then-
  covered. Off by default; `spike` mode is always exempt. See `references/tdd-mode.md` and the
  shared loop in `magento2-context/references/tdd-discipline.md`.
- **Smoke before report.** Phase 6 has two sub-phases: **6A** (unit tests + coverage) and **6B**
  (smoke battery — REST scenarios, admin login, Stores → Config, grids, new routes, customer
  flows, exception.log diff). Phase 7 may not start while any Critical or High smoke finding is
  open. See `references/smoke-test-guide.md`.
- **Smoke loop is bounded.** Critical/High smoke findings are auto-routed to the right
  `magento2-*` sub-skill for remediation, then Phase 6 re-runs from 6A. The loop halts at **5
  iterations** and asks the user how to proceed (`retry` / `accept-known-issues <IDs>` / `abort`).
- **No empty implementations.** Do not create stub classes with `// TODO` bodies and report them
  as done. Every generated file must contain real implementation content.
- **All diagrams are Mermaid.** Every diagram in every document — dependency graphs, flow charts,
  module schemas, ER diagrams — must use Mermaid syntax. No ASCII art or external image links.
- **Guides and user docs are HTML.** Development guides and user documentation default to `.html`
  format. Define a CSS color schema once for the feature and apply it inline to every HTML file
  in the feature folder for visual consistency.
- **Per-task git commits (opt-in).** When `--per-task-commits` is set, CLAUDE.md contains
  `Feature implement: per-task commits = on`, or `MAGENTO2_FI_PER_TASK_COMMITS=1` is set,
  every completed task in Phase 5 produces a focused git commit. See
  `references/per-task-commits.md` for format, scoping rules, and failure handling. Off by default.
- **Deploy delegation.** D* tasks delegate to `magento2-deploy`. The skill is invoked with the
  module list and the user's environment selection; this skill does not run `bin/magento`
  commands inline.

---

## Feature Folder Structure

Every feature gets its own subfolder under `.docs/`. Create it at the start of Phase 2.

**Location.** `.docs/` is anchored at the **project working directory** (`{ctx.docs_root}` =
`{project_root}/.docs`), as defined by the **Artifact location** rule in
`magento2-context/SKILL.md`. Never create it under `{ctx.magento_root}` (e.g. `src/`),
`app/code`, or any module directory. When `magento_root` is `src`, the folder is
`./.docs/{FeatureName}/`, a sibling of `src/` — not `src/.docs/{FeatureName}/`.

```
.docs/                        # at the project root — never inside the Magento tree
└── {FeatureName}/
    ├── blueprint.md          # Feature blueprint — saved for review in Phase 2, before the blueprint gate
    ├── plan.md               # Execution plan: diagrams + resumable checkbox list — saved for review in Phase 4, before the plan gate
    ├── tasks.md              # Flat task records (≤ 5 tasks) — written for review before the plan gate
    │   OR
    ├── tasks/                # One file per task (> 5 tasks) — written for review before the plan gate
    │   ├── 001-M1-{title}.md  # {NNN} = execution-order index; same NNN ⇒ runs in parallel
    │   ├── 002-R1-{title}.md
    │   ├── 003-X1-{title}.md  # 003-X1 and 003-X2 share index 003 → parallel wave
    │   ├── 003-X2-{title}.md
    │   └── ...
    ├── report.md             # Final implementation report — Phase 7
    ├── guides/               # Development guides (HTML) — generated when applicable
    │   └── developer-guide.html
    ├── user-docs/            # End-user documentation (HTML) — generated when applicable
    │   └── user-guide.html
    └── spec.md               # Technical specification — generated when scope warrants it
```

**plan.md** is the single source of truth for resuming interrupted runs. It must always contain:

- The implementation flow diagram (Mermaid `flowchart TD`)
- The module schema diagram (Mermaid `graph TD`)
- The task dependency graph (Mermaid `graph LR`)
- A **Current State** section listing every task as a checkbox (`- [ ]` pending / `- [x]` done).

After each task completes in Phase 5, mark its checkbox `[x]` in `plan.md` and save immediately.

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

0. **Pick a mode.** Read `references/modes.md`. Choose `feature` (default), `hotfix`,
   `extend`, or `spike` based on the request. State the chosen mode explicitly:
   > Mode: `hotfix`. Skipping Phases 3-4 — small change scope.
   In `hotfix` mode, Phases 3-4 are skipped. In `extend` mode, Phase 3 is skipped but a
   minimal Phase 4 still runs to write `plan.md` (with its `## Current State` checklist) —
   it is **not** skipped. See `references/modes.md` for the exact per-mode pipeline.
   In `spike` mode, Phases 6-7 are reduced and findings are logged at Info.

1. **Resolve `{Vendor}`** — do not assume a fixed vendor name:
    1. Read `CLAUDE.md` for a `Vendor prefix:` line (e.g. `Vendor prefix: **Acme**`).
    2. If absent, inspect `src/app/code/` (or `app/code/`) and use the top-level directory name found
       there (e.g. if `app/code/Acme/` exists, `{Vendor}` = `Acme`).
    3. If still unresolvable, ask: *"What vendor prefix does this project use (e.g. `Acme`)?"*
       and wait for the answer before proceeding.
       Store `{Vendor}` and use it in all subsequent phases wherever a vendor prefix is needed.
       Never default to any hardcoded vendor name.

2. Read `$ARGUMENTS`. If the request is fully specified (clear feature, scope, and constraints),
   proceed directly to step 4.
3. If the request is ambiguous, ask a single batch of 3–6 targeted questions. Choose from:
    - What business problem does this solve? (if not stated)
    - Which Magento areas are involved? (checkout, catalog, customer, order, inventory, EAV, …)
    - Does this require admin configuration, a REST/GraphQL endpoint, or a frontend UI?
    - Are there existing modules that already own part of this domain?
    - Are there third-party integrations involved?
    - Are there performance or data-volume constraints to design around?
4. After receiving answers, map the request to:
    - Affected Magento areas
    - Likely surfaces from `magento2-module-create/references/surfaces.md`
    - Whether new modules are needed or existing modules will be modified
5. State your understanding in one paragraph, including the resolved `{Vendor}`, and proceed.

---

## Phase 2 — Feature Blueprint

**Goal:** produce a complete, approved blueprint.

1. Load `references/feature-blueprint-format.md`. Apply its completeness checklist before saving.
2. Use `templates/feature-blueprint.md` as the structural base.
3. Fill in all 12 sections. Do not skip any — use "None" or "N/A" with a brief justification when
   a section genuinely does not apply.
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

1. Load `references/module-schema-guide.md`.
2. For each component in the blueprint, apply the decision matrix (new module vs modify existing).
3. Assign surfaces to each new module using `magento2-module-create/references/surfaces.md`.
4. Produce a Mermaid `graph TD` dependency diagram showing all modules and their relationships,
   following the format in `references/module-schema-guide.md` (Module Schema Diagram section).
5. Produce the module schema output (new modules table, modified modules table, diagram, load order)
   as described in `references/module-schema-guide.md`.
6. Present the schema to the user as part of the task breakdown in Phase 4.
   **Do not pause for approval here** — present schema and task breakdown together.

---

## Phase 4 — Task Breakdown and Approval Gate

**Goal:** produce a detailed, approved implementation plan.

1. Load `references/task-breakdown-guide.md`.
2. Use `templates/plan.md` as the structural base for `plan.md`. The **detailed task records**
   are written separately, from `templates/task-record.md` (step 6, before the approval gate) —
   they are never embedded in `plan.md`.
3. Assign task IDs using the `{TypePrefix}{Number}` format from the guide.
4. For each task, fill in: type, target, depends on, skill invoked, estimate, description,
   and acceptance criteria. When TDD mode is on (see Core Rules), a behaviour-bearing task's
   acceptance criteria are also its **RED test list** — each criterion becomes a failing test
   written before the task's implementation code (`references/tdd-mode.md`).
5. Produce the execution flow diagram (Mermaid `flowchart TD`) and the dependency graph
   (Mermaid `graph LR`).
6. **Write `plan.md` AND the detailed task records to disk for review — before presenting and
   before the approval gate.**
   First, save the execution plan to `.docs/{FeatureName}/plan.md` with a `Status: Awaiting Approval`
   line in its header (see `templates/plan.md`). The plan must include, in this order:
    - Implementation flow diagram (Mermaid `flowchart TD`)
    - Module schema diagram (Mermaid `graph TD` from Phase 3)
    - Task dependency graph (Mermaid `graph LR`)
    - **Current State** checklist — every task as an unchecked checkbox: `- [ ] {ID}: {Title}`.
    - The summary table (task count, module counts, total estimate)

   `plan.md` is the resumable **index** — diagrams, the Current State checklist, and the summary.
   It holds **no** detailed task records.

   Then, save the **detailed task records** using `templates/task-record.md` as the structural
   base, so the user can review the full task detail before approving:
    - `.docs/{FeatureName}/tasks.md` if the feature has ≤ 5 tasks (single flat file), or
    - `.docs/{FeatureName}/tasks/` if the feature has > 5 tasks (one file per task named
      `{NNN}-{ID}-{kebab-title}.md`). `{NNN}` is the zero-padded execution-order index
      (`001`, `002`, `003`, …) derived from the dependency order in `plan.md`: assign `001`
      to the first wave (tasks with no unmet dependencies), `002` to the next wave, and so on.
      Tasks expected to run in parallel (same wave — `Parallel: yes`, no dependency between
      them) share the **same** `{NNN}`. So the prefix sorts the folder into execution order
      and reveals parallel groups at a glance (e.g. `003-X1-extend-checkout.md` and
      `003-X2-extend-customer.md` run together).

   Each task record must contain: what is included, which files will change and why, execution
   estimate, dependencies, and possible risks. Per the **Save before present** rule, `plan.md`
   and the task records MUST all exist on disk before step 7.
7. **Confirm `plan.md` and the task records are on disk** (read them back), then present the plan
   to the user, citing the paths so they can review the full detail in the files: *"Plan saved to
   `.docs/{FeatureName}/plan.md`; detailed task records in `.docs/{FeatureName}/tasks.md` (or
   `tasks/`) — review there or below."* Present inline:
    - Implementation flow diagram
    - Module schema (from Phase 3)
    - Task dependency graph
    - Current State checklist (every task ID + title)
    - Summary table (task count, module counts, total estimate)

   The detailed records are reviewed in the file(s); reproduce them inline only if the user asks.
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

### Environment context (resolve once, before Phase 5 tool steps)

**Invoke the `magento2-context` skill** — it is the single source of truth for `{ctx.vendor}`,
`{ctx.runner}`, `{ctx.magento_cli}`, `{ctx.composer}`, `{ctx.tools.*}`, edition, versions, and
the active theme. Do **not** hand-roll a runner/tool probe here (that duplicated the hub and
drifted from it — FI-3). The same applies to the Phase 1 vendor lookup: prefer `{ctx.vendor}`,
falling back to a `CLAUDE.md` `Vendor prefix:` line or an explicit user question only when the
hub reports it as null.

Consume the resolved values directly:

- `{runner}` = `{ctx.runner}` (empty string in bare-PHP mode — `${runner} php …` still works).
- `{magento}` = `{ctx.magento_cli}` (null ⇒ offer the commands as manual "next steps").
- Tool availability = `{ctx.tools.phpcs}`, `{ctx.tools.phpstan}`, `{ctx.tools.phpunit}`, etc.
  (each is the resolved path or null — skip and report the ones that are null).

All subsequent tool invocations in Phase 5 and Phase 6 use these `{ctx.*}` values. Never
hardcode a specific runner — fall back gracefully and report what was skipped.

---

Work through the approved task list in dependency order. For tasks marked `Parallel: yes` in the
task list, concurrent execution via sub-agents is permitted subject to the rules in
`references/task-breakdown-guide.md` (Parallel Execution section). For each task:

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

Every task subsection below ends with **"→ run the Per-task completion protocol"** — that is
the cue to perform these four steps. When tasks run in parallel (same wave), apply the
protocol once per task as each one finishes, not once for the whole wave.

### New module tasks (M*)

1. Invoke the `magento2-module-create` skill with the module name and surfaces.
2. After creation, immediately invoke the `magento2-module-review` skill (the corresponding R* task).
3. Fix all Critical and High findings before starting the next task.
4. Document Medium findings — they will appear in the final report.
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

**TDD mode (on):** for each behaviour-bearing class the module adds (`Service`, `Model` with
logic, `Plugin`, `Observer`, `Console/Command`, `Resolver`, data-patch transforms), scaffold the
**signature** first (interface + a body that throws `not implemented`), write the failing test
from the task's acceptance criteria, **watch it fail for the right reason**, then fill the minimal
body to green before review. Pure scaffold/config (registration, DI, module.xml, plain DTOs,
db_schema) is exempt. Follow `references/tdd-mode.md` and the loop in
`magento2-context/references/tdd-discipline.md`.

### Existing module tasks (X*)

1. Identify the exact files to add or modify.
2. Apply changes following all rules in `CLAUDE.md` and `magento2-module-create/references/`.
   **TDD mode (on):** if the change adds behaviour (not pure config/scaffold), write the failing
   test first and watch it fail for the right reason before applying the production change, per
   `references/tdd-mode.md` and `magento2-context/references/tdd-discipline.md`.
3. Run `php -l` on every modified PHP file and `xmllint --noout` on every modified XML file.
   These tools operate on local files and do not require a runner.
4. Invoke the corresponding review task (R*).
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

### Review tasks (R*)

1. Invoke `magento2-module-review` on the target module.
2. Fix all Critical and High findings in the same task — do not defer.
3. Log Medium findings to the final report.
4. Mark the R* task complete only when all Critical/High findings are resolved.
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

### Test tasks (T*)

Delegate to `magento2-test-generate` when available; fall back to inline generation otherwise.

```
Skill: magento2-test-generate
Args: --types=unit --missing-only {Vendor}_{Module}
```

`magento2-test-generate` discovers untested classes, writes tests with real assertions, and
runs `php -l` per generated file. The T* task completes when the generator reports done.

**TDD mode (on):** the behaviour tests were already written test-first inside their `M*`/`X*`
tasks. Here the T* task **verifies** the suite is green and uses `magento2-test-generate` only to
**top up** coverage on exempt/boilerplate classes — it does not author the behaviour's first test.
Do not regenerate or overwrite the test-first tests.

Inline fallback (when the skill is absent):

1. Write unit tests for every `Api/`, `Service/`, and `Model/` class added or modified in the
   target module. Do not create empty test stubs — every test must contain real assertions.
2. Run `php -l` on all new test files.
3. Do **not** run PHPUnit here — test execution and coverage measurement are handled in Phase 6.
4. Mark the T* task complete when test files exist, contain real test logic, and pass `php -l`.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled) —
whether the T* task was delegated to `magento2-test-generate` or done inline.

### EAV attribute tasks (E*)

When the blueprint declares EAV attributes, generate an E* task per attribute and delegate
to `magento2-eav-attribute`:

```
Skill: magento2-eav-attribute
Args: --entity=product --code={code} --label="{Label}" --type={input_type} --module={Vendor}_{Module}
```

The skill produces the `Setup/Patch/Data/Add{Code}Attribute.php` patch, companion models
when needed, and a brief report. After E* completes, an R* review task runs on the
affected module.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

### GraphQL surface tasks (G*)

When the blueprint declares a GraphQL surface with non-trivial design (batch loaders, auth,
schema migration), generate a G* task per resolver group and delegate to `magento2-graphql-create`:

```
Skill: magento2-graphql-create
Args: --module={Vendor}_{Module} --operation={query|mutation} --auth={customer|admin|anonymous}
```

The skill produces schema, resolver, batch loader (if applicable), DI, and unit tests.
Simple GraphQL surfaces continue to use `magento2-module-create`'s graphql templates.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

### Validate task (V*)

Run each check with the probed `{runner}`. Skip and report any tool that is unavailable.

```bash
# Code style
{runner} vendor/bin/phpcs --standard=Magento2 app/code/{Vendor}/{ModuleName}

# Mess detection
{runner} vendor/bin/phpmd app/code/{Vendor}/{ModuleName} text phpmd.xml

# Static analysis
{runner} vendor/bin/phpstan analyse --level=8 app/code/{Vendor}/{ModuleName}

# Unit tests
{runner} vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist app/code/{Vendor}/{ModuleName}/Test/Unit
```

The validate task is complete only when PHPCS, PHPMD, PHPStan level 8, and PHPUnit all pass for
every new and modified module. Record which tools were skipped due to unavailability — these are
environment limitations, not failures.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

### Deploy task (D*)

Delegate to `magento2-deploy`. Invoke via the `Skill` tool with the module list and the
user's environment selection (default: `local`). This skill does not run `bin/magento`
commands inline — `magento2-deploy` owns the pre-flight, plan, execute, smoke, and
rollback steps.

```
Skill: magento2-deploy
Args: --env=local {Vendor}_{ModuleA} {Vendor}_{ModuleB}
```

Per-task commit (when enabled): D* tasks make no commit (no files change). Record the
deploy report path returned by `magento2-deploy` in `plan.md` next to the D* task.

→ run the **Per-task completion protocol** to mark `[x]` in `plan.md` (no commit for D*).

If `magento2-deploy` is unavailable, state the unavailability explicitly and offer the
equivalent commands as manual next steps for the user to run themselves:
`{magento} module:enable {modules}` → `{magento} setup:upgrade` →
`{magento} setup:di:compile` (prod) → `{magento} setup:static-content:deploy -f` (prod) →
`{magento} cache:flush`. Ask the user to install `magento2-deploy` before re-running.

---

## Phase 6 — Test

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

### Phase 6A — Unit Tests + Coverage

**Goal:** ensure all new and modified code has passing unit tests with adequate coverage.

1. If T* tasks were included in the plan: confirm all T* tasks are marked complete and that test
   files exist in `Test/Unit/`. Do not rewrite tests already created in Phase 5.
   If no T* tasks were generated (e.g. single-module, simple feature): delegate to
   `magento2-test-generate --types=unit,integration,api` for each module.
   Inline fallback (when `magento2-test-generate` is absent): write unit tests now for
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

### Phase 6B — Smoke Battery

**Goal:** verify the feature works against a running Magento instance and that nothing else
regressed in the surfaces typical sites care about.

Load `references/smoke-test-guide.md`, `references/smoke-runner.md`, and
`references/exception-log-baseline.md` before starting. Phase 6B is **mandatory** in `feature`
mode, reduced in `hotfix` and `extend` modes, and skipped in `spike` mode (see
`references/modes.md`).

Emit one `S*` task per applicable suite (Phase 4 task type `S`). S1 (baseline & probe) and S8
(exception.log diff) are always present; S2–S7 only when the feature exercises that surface.
The suite catalogue, per-suite acceptance, the S1 probe table + production guard, the S9
triage/decision loop, and the data-hygiene/cleanup rules live in the references — **follow
them rather than duplicating here** (the duplicate had already drifted from the source):

- `references/smoke-runner.md` — §1 probe table (Base URL, admin creds, HTTP client, headless
  browser) + production guard; the per-suite driver commands. Refuse to run against production
  unless `CLAUDE.md` contains `Allow smoke on production: true`.
- `references/smoke-test-guide.md` — the S1–S9 suite catalogue, per-suite acceptance, severity
  rubric, fix-routing table, halt prompt, and data-hygiene/cleanup rules.
- `references/exception-log-baseline.md` — the S8 baseline/diff mechanics and the "no
  new/unresolved exception groups" pass rule.

Scripts: `${CLAUDE_SKILL_DIR}/scripts/smoke-baseline.sh` (S1), `smoke-tail-since.sh` (S8),
`smoke-browser.mjs` (browser S3–S7), `curl`/PHP-cURL (S2).

**The loop (S9 decision):** 0 Critical + 0 High → Phase 6 passes → Phase 7. ≥1 Critical/High and
iteration < 5 → delegate fixes per `smoke-test-guide.md` §Fix Routing, re-deploy via
`magento2-deploy` if code changed, then re-enter from 6A. ≥1 Critical/High and iteration == 5 →
halt and prompt the user. Record each iteration via `templates/smoke-run-report.md` and keep
`templates/smoke-findings.md` updated (stable finding IDs across iterations).

---

## Phase 7 — Final Report

**Goal:** produce a complete implementation report.

1. Load `references/final-report-format.md`.
2. Use `templates/final-report.md` as the structural base.
3. Fill in all 10 sections:
    - Executive Summary
    - Modules Implemented (table)
    - Public API Index
    - Configuration Guide
    - Tradeoffs (load `references/tradeoffs-catalog.md` and document applicable ones)
    - Deviations from Blueprint
    - Test Coverage Summary
    - Known Limitations
    - Recommended Next Steps
    - Smoke Test Results (per `references/final-report-format.md` §10 — omit in `spike` mode)
4. Update the blueprint status line to `Status: Complete` in `.docs/{FeatureName}/blueprint.md`.
   Update the plan status and mark all remaining checkboxes `[x]` in `.docs/{FeatureName}/plan.md`.
5. Save the report to `.docs/{FeatureName}/report.md`.
6. If the feature includes complex configuration, non-obvious developer integration points, or
   admin workflows, generate the relevant optional documents in the feature folder:
    - `guides/developer-guide.html` — integration and extension guide for developers.
    - `user-docs/user-guide.html` — admin/end-user guide for configuring and using the feature.
    - `spec.md` — technical specification, if the blueprint warrants persistent reference material.
      Each HTML file must define a CSS color schema inline (primary, secondary, background, text,
      accent colors) and apply it consistently across all HTML files in the feature folder.
7. Print the report to the conversation.
8. State explicitly: *"Feature implementation complete. See report above and
   `.docs/{FeatureName}/report.md`."*

---

## Reference Files

- `references/feature-blueprint-format.md`: required sections, completeness checklist, file path.
- `references/module-schema-guide.md`: new vs modify decision matrix, cohesion rules, diagram format.
- `references/task-breakdown-guide.md`: task IDs (including `S*`), task record format, Mermaid syntax, approval gate.
- `references/tradeoffs-catalog.md`: common Magento 2 architectural tradeoffs and documentation format.
- `references/final-report-format.md`: report structure (incl. Section 10 — Smoke Test Results).
- `references/modes.md`: feature/hotfix/extend/spike mode selection, per-mode pipeline overrides, per-mode smoke scope.
- `references/per-task-commits.md`: opt-in per-task git commit format, scoping, failure handling.
- `references/tdd-mode.md`: opt-in test-first execution — flag/config/env triple, per-mode applicability, how Phase 5 applies the shared `tdd-discipline.md` loop.
- `references/smoke-test-guide.md`: Phase 6B suites, severity rubric, fix routing, loop control.
- `references/smoke-runner.md`: environment probe, REST invocation, headless browser commands, fallbacks.
- `references/exception-log-baseline.md`: byte-offset baseline + tail-since-offset diff for `var/log/exception.log`.
- `templates/feature-blueprint.md`: feature blueprint template.
- `templates/plan.md`: execution-plan (`plan.md`) template — Mermaid diagrams, Current State checklist, Smoke Iterations, summary. No detailed task records.
- `templates/task-record.md`: detailed task-record template for `tasks.md` / `tasks/` (incl. `S*` examples) — written for review before the plan approval gate.
- `templates/final-report.md`: implementation report template (incl. Section 10).
- `templates/smoke-run-report.md`: per-iteration smoke run report template.
- `templates/smoke-scenarios.md`: REST scenarios template.
- `templates/smoke-findings.md`: consolidated, cross-iteration findings template.
- `${CLAUDE_SKILL_DIR}/scripts/smoke-baseline.sh`: S1 — capture `var/log/exception.log` baseline.
- `${CLAUDE_SKILL_DIR}/scripts/smoke-tail-since.sh`: S8 — diff `var/log/exception.log` since baseline.
- `${CLAUDE_SKILL_DIR}/scripts/smoke-browser.mjs`: S3–S7 — headless browser driver (Playwright → Puppeteer → CDP).

## Related Skills

Invoke all related skills via the `Skill` tool. Do not spawn separate agents for sub-skill
invocations — the `Skill` tool preserves conversation context across phases.

- `magento2-module-create`: invoked for every new module in Phase 5 (M* tasks).
- `magento2-module-review`: invoked after every module creation or modification (R* tasks).
  Use `--diff` mode after each task to keep the review focused on what changed.
- `magento2-deploy`: invoked for the D* task (Phase 5) and after every Phase 6B fix that
  touches PHP/XML/JS/template before re-entering Phase 6 from 6A.
- `magento2-test-generate`: invoked for the T* task (Phase 5) and Phase 6A when present.
  Generates unit/integration/API tests; falls back to inline test generation if absent.
- `magento2-eav-attribute`: invoked when the blueprint declares EAV attributes — replaces
  hand-written `Setup/Patch/Data/` files for EAV.
- `magento2-graphql-create`: invoked when the blueprint declares a GraphQL surface and
  the design includes batch loaders or auth/scope complexity.
- `magento2-bug-fix`: invoked by Phase 6B S9 to remediate Critical/High smoke findings —
  default fix delegate; see `references/smoke-test-guide.md` §Fix Routing.
- `magento2-debug`: invoked by Phase 6B S9 for triage of new `var/log/exception.log` entries
  before delegating to `magento2-bug-fix`.
- `magento2-performance-audit`: invoked by Phase 6B S9 when smoke surfaces slow pages,
  N+1, or cache misses.
- `magento2-security-audit`: invoked by Phase 6B S9 when smoke surfaces an ACL/CSRF/escaping
  regression.
- `magento2-frontend-create`: invoked (in augment mode) by Phase 6B S9 for frontend
  regressions (JS console errors, missing assets, KO bind errors).
- `magento2-data-migration`: invoked by Phase 6B S9 for schema/data patch regressions.
