# Feature Folder Structure

Part of the `feature` skill — read at Phase 2 (folder creation), and whenever you write or look for a feature artifact.

Every feature gets its own subfolder under `.docs/`. Create it at the start of Phase 2.

**Location.** `.docs/` is anchored at the **project working directory** (`{ctx.docs_root}` =
`{project_root}/.docs`), as defined by the **Artifact location** rule in
`context/SKILL.md`. Never create it under `{ctx.magento_root}` (e.g. `src/`),
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
    ├── report.md             # Final implementation report — Phase 7B
    ├── spec.md               # Cross-module technical specification — Phase 7A (required in feature mode)
    ├── guides/               # Developer-scope documentation (HTML) — Phase 7A (required in feature/extend)
    │   └── developer-guide.html
    ├── user-docs/            # User/admin-scope documentation (HTML) — Phase 7A (required in feature/extend)
    │   ├── user-guide.html
    │   └── screenshots/      # Admin/storefront screenshots embedded in the user guide (reuse Phase 6B captures)
    ├── api-examples/         # REST/GraphQL request + response payload samples — when the feature exposes an API
    ├── artifacts/            # Other helpful artifacts (Postman collection, ER/sequence diagrams, sample data)
    ├── reviews/              # .docs/{FeatureName}/reviews/ — review (R* tasks)
    ├── tests/                # test-generate coverage reports
    ├── quality/              # lint (V* tasks)
    ├── audits/               # security / performance audits routed from S9
    ├── docs-generated/       # docs run reports (Phase 7A)
    ├── deployments/          # deploy (D* tasks)
    └── …                     # any other invoked sub-skill's category dir
```

> Sub-skill artifacts nest by category under the feature root per
> `context/references/artifact-layout.md`.

**plan.md** is the single source of truth for resuming a run interrupted **from outside** — a lost
session, a crash, an explicit stop by the user. It must always contain:

- The implementation flow diagram (Mermaid `flowchart TD`)
- The module schema diagram (Mermaid `graph TD`)
- The task dependency graph (Mermaid `graph LR`)
- A **Current State** section listing every task as a checkbox (`- [ ]` pending / `- [x]` done).

After each task completes in Phase 5, mark its checkbox `[x]` in `plan.md` and save immediately,
then continue straight into the next task. `plan.md` exists so an **externally** interrupted run
can be picked up — it is not a licence to interrupt the run yourself (Core Rules →
**Continuous execution**).
