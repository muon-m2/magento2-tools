# Task Breakdown Guide

Use this file during Phase 4 to decompose a feature into ordered tasks, assign dependencies,
and produce diagrams the user can review before approving implementation.

---

## Task ID Format

Tasks use a two-part ID: `{TypePrefix}{Number}`

| Prefix | Type                                                                                   |
|--------|---------------------------------------------------------------------------------------|
| `M`    | Create new module (maps 1:1 to a `magento2-module-create` invocation)                 |
| `X`    | Modify existing module                                                                |
| `E`    | EAV attribute (maps 1:1 to a `magento2-eav-attribute` invocation)                     |
| `G`    | GraphQL surface design (maps 1:1 to a `magento2-graphql-create` invocation)           |
| `F`    | Frontend asset (maps 1:1 to a `magento2-frontend-create` invocation, when present)    |
| `T`    | Write or expand tests (delegates to `magento2-test-generate` when present)            |
| `R`    | Review (maps 1:1 to a `magento2-module-review` invocation, `--diff` mode)             |
| `V`    | Validate (quality gate)                                                               |
| `D`    | Deploy (maps 1:1 to a `magento2-deploy` invocation)                                   |
| `S`    | Smoke suite (Phase 6B — emitted by the skill, not user-authored)                       |
| `P`    | Report (final implementation report)                                                  |

Example task IDs: `M1`, `M2`, `X1`, `E1`, `G1`, `T1`, `R1`, `V1`, `D1`, `S1`, `S2`, `S8`, `P1`.

### `S*` smoke tasks

Smoke tasks are emitted automatically when Phase 6B starts, not by the planner during Phase 4.
They are still recorded in `plan.md`'s `## Current State` checklist (so resume can pick them
up mid-loop) and in either `tasks.md` or `tasks/` so each suite's scope is documented. IDs are
the fixed suite numbers from `references/smoke-test-guide.md` (`S1` baseline & probe, `S2` REST,
`S3` admin login, `S4` Stores Config, `S5` admin grids, `S6` new/changed routes, `S7` customer
flows, `S8` exception.log diff, `S9` triage). Suites that do not apply to the feature are
omitted, not left unchecked.

---

## Task Record Format

Each task must contain:

```
### {ID}: {Short Title}

Type: Create Module | Modify Module | Test | Review | Validate | Deploy | Report
Target: {module name or file path}
Depends on: {comma-separated IDs, or "none"}
Skill: {skill invoked, or "manual"}
Estimate: {S = <30 min | M = 30–90 min | L = >90 min}

Description:
{One to three sentences. What is done, not how.}

Included changes:
- {File path} — {what changes and why}
- {File path} — {what changes and why}

Risks:
- {Potential risk and mitigation, or "None identified"}

Acceptance criteria:
- {Specific, verifiable outcome}
- {Another criterion}
```

Estimate is informational only. Do not block execution on estimates.

---

## Task Structure: Single File vs Folder

**≤ 5 tasks** — save all task records to a single flat file: `.docs/{FeatureName}/tasks.md`.

**> 5 tasks** — save each task to its own file inside `.docs/{FeatureName}/tasks/`, named
`{ID}-{kebab-title}.md` (e.g. `M1-create-xyz-core.md`, `R1-review-xyz-core.md`). The folder
allows individual tasks to be read and updated in isolation during long-running implementations.

---

## Execution Plan Format (plan.md)

Save the execution plan to `.docs/{FeatureName}/plan.md` after Phase 4 approval. This file is
the single source of truth for resuming interrupted runs.

Required structure:

```markdown
# {Feature Name} — Execution Plan

Date: {YYYY-MM-DD}
Status: Approved | In Progress | Complete
Blueprint: .docs/{FeatureName}/blueprint.md

---

## Implementation Flow

{Mermaid flowchart TD diagram — phases and approval gates}

---

## Module Schema

{Mermaid graph TD diagram — modules and their relationships from Phase 3}

---

## Task Dependency Graph

{Mermaid graph LR diagram — task-level dependency graph}

---

## Current State

- [ ] {ID}: {Short Title}
- [ ] {ID}: {Short Title}
- [ ] ...

(Mark each task [x] immediately after it completes. This section drives resume logic.)

---

## Smoke Iterations

Count: 0 / 5
Last run: —
Outcome: —

(The skill maintains this block during Phase 6B. Increment Count BEFORE each Phase 6 entry.
At Count == 5 with unresolved Critical/High, halt and prompt the user per
`smoke-test-guide.md` §Halt Prompt.)
```

Update the `Status:` line to `In Progress` at the start of Phase 5 and to `Complete` at the end
of Phase 7. Mark each task `[x]` and save `plan.md` after every completed task.

---

## Execution Ordering Rules

1. Module creation tasks (`M*`) for a dependency must complete before the module that depends on it.
2. Review tasks (`R*`) must immediately follow their corresponding creation or modification task.
3. Test tasks (`T*`) may run in parallel with other creation tasks when they are for different modules.
4. A single validate task (`V1`) runs after all module and test tasks are complete.
5. Deploy (`D1`) runs after `V1`.
6. Smoke suites (`S1`–`S9`) run as Phase 6B, after D1 and Phase 6A unit tests pass. Within
   Phase 6B the order is strict: **S1 → S2 → S3 → S4 → S5 → S6 → S7 → S8 → S9**. S1 and S8
   are always present; S2–S7 are emitted only when applicable.
7. Report (`P1`) is always last and only runs once S9 records 0 Critical / 0 High findings (or
   the user has chosen `accept-known-issues` at the iteration cap).

Default ordering template:

```
M1 → R1 → M2 → R2 → X1 → R3 → T* → V1 → D1 → (6A unit) → S1 → S2..S7 → S8 → S9 → P1
                                                              ↑               │
                                                              └─ fix loop ────┘  (max 5 iterations)
```

---

## Mermaid Dependency Graph

Produce a dependency graph showing which tasks block others. Use `graph LR` (left to right).

```mermaid
graph LR
    M1[M1: Create {Vendor}_XyzCore] --> R1[R1: Review {Vendor}_XyzCore]
    M2[M2: Create {Vendor}_XyzAdmin] --> R2[R2: Review {Vendor}_XyzAdmin]
    R1 --> M2
    R1 --> T1[T1: Unit tests XyzCore]
    R2 --> T2[T2: Unit tests XyzAdmin]
    T1 --> V1[V1: Validate all]
    T2 --> V1
    V1 --> D1[D1: Deploy]
    D1 --> S1[S1: Baseline & probe]
    S1 --> S2[S2: REST scenarios]
    S2 --> S3[S3: Admin login]
    S3 --> S4[S4: Stores Config]
    S4 --> S5[S5: Admin grids]
    S5 --> S6[S6: New routes]
    S6 --> S7[S7: Customer flows]
    S7 --> S8[S8: exception.log diff]
    S8 --> S9{S9: Critical/High?}
    S9 -- No --> P1[P1: Final report]
    S9 -- Yes / iter<5 --> FIX[Fix via magento2-* skill]
    FIX --> D1
    S9 -- Yes / iter==5 --> HALT([Halt: ask user])
```

Rules:

- Every task appears as a node with both ID and short title in the label.
- Arrows show blocking direction (A → B means B cannot start until A is done).
- Parallel tasks have no arrow between them.
- Do not include the legend — the ID prefixes are self-explanatory.

---

## Mermaid Flow Diagram

Produce a sequential flow diagram for the human reader. Use `flowchart TD` (top to bottom).
This shows phases, not individual tasks.

```mermaid
flowchart TD
    A([Start: User request]) --> B[Phase 1: Elicit & Analyze]
    B --> C[Phase 2: Feature Blueprint]
    C --> D{User approves blueprint?}
    D -- No --> C
    D -- Yes --> E[Phase 3: Module Schema]
    E --> F[Phase 4: Task Breakdown]
    F --> G{User approves plan?}
    G -- No --> F
    G -- Yes --> H[Phase 5: Execute tasks]
    H --> I[Phase 6A: Unit + Coverage]
    I --> I2{Unit tests pass?}
    I2 -- No --> K1[Fix unit failures]
    K1 --> I
    I2 -- Yes --> SM[Phase 6B: Smoke battery S1..S9]
    SM --> SM2{Critical or High?}
    SM2 -- No --> L[Phase 7: Final report]
    SM2 -- Yes --> CNT{Iteration < 5?}
    CNT -- Yes --> FIX[Delegate fixes via magento2-* skill]
    FIX --> I
    CNT -- No --> HALT([Halt: ask user — retry / accept / abort])
    L --> M([Done])
```

Include this flow diagram verbatim in the task breakdown output; it provides high-level orientation.

---

## Parallel Execution

Tasks with no dependency between them may be executed in parallel using sub-agents. Apply these rules:

- Only parallelize when the user has explicitly authorized parallel execution, or when there are
  ≥ 3 independent creation tasks and the user has not said "sequential".
- Never parallelize a review task with the creation task it reviews.
- Never parallelize two tasks that write to the same module.
- When parallelizing, note in the task record: `Parallel: yes` and list which tasks run together.

---

## Approval Gate

After producing the task breakdown, present this message verbatim before proceeding:

> **Plan ready for approval.**
> Tasks: {count} | Modules to create: {count} | Modules to modify: {count}
> Estimated total effort: {sum of estimates}
>
> Reply **"proceed"** to begin implementation, or describe any changes to the plan.

Do not write any code or invoke any sub-skill until the user replies with an explicit approval signal
("proceed", "yes", "go", "approved", "ok", or equivalent affirmative).
