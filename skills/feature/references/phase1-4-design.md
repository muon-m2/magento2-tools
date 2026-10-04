# Phases 1–4 — Design Detail

Part of the `feature` skill — read at the start of each of Phases 1–4 (gate steps stay in SKILL.md).

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
    - Likely surfaces from `module-create/references/surfaces.md`
    - Whether new modules are needed or existing modules will be modified
5. State your understanding in one paragraph, including the resolved `{Vendor}`, and proceed.

---

## Phase 2 — Feature Blueprint

1. Load `references/feature-blueprint-format.md`. Apply its completeness checklist before saving.
2. Use `templates/feature-blueprint.md` as the structural base.
3. Fill in all 12 sections. Do not skip any — use "None" or "N/A" with a brief justification when
   a section genuinely does not apply.

---

## Phase 3 — Module Schema

**Goal:** decide exactly which modules own which parts of the feature.

1. Load `references/module-schema-guide.md`.
2. For each component in the blueprint, apply the decision matrix (new module vs modify existing).
3. Assign surfaces to each new module using `module-create/references/surfaces.md`.
4. Produce a Mermaid `graph TD` dependency diagram showing all modules and their relationships,
   following the format in `references/module-schema-guide.md` (Module Schema Diagram section).
5. Produce the module schema output (new modules table, modified modules table, diagram, load order)
   as described in `references/module-schema-guide.md`.
6. Present the schema to the user as part of the task breakdown in Phase 4.
   **Do not pause for approval here** — present schema and task breakdown together.

---

## Phase 4 — Task Breakdown and Approval Gate

1. Load `references/task-breakdown-guide.md`.
2. Use `templates/plan.md` as the structural base for `plan.md`. The **detailed task records**
   are written separately, from `templates/task-record.md` (step 6, before the approval gate) —
   they are never embedded in `plan.md`.
3. Assign task IDs using the `{TypePrefix}{Number}` format from the guide.
4. For each task, fill in: type, target, depends on, skill invoked, recommended model tier
   (advisory), estimate, description, and acceptance criteria. Assign the tier from the
   default-by-type table in `references/task-breakdown-guide.md` §"Model tier (advisory)".
   When TDD mode is on (see Core Rules), a behaviour-bearing task's
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

---

- `templates/feature-blueprint.md`: feature blueprint template.
- `templates/plan.md`: execution-plan (`plan.md`) template — Mermaid diagrams, Current State checklist, Smoke Iterations, summary. No detailed task records.
- `templates/task-record.md`: detailed task-record template for `tasks.md` / `tasks/` (incl. `S*` examples) — written for review before the plan approval gate.
