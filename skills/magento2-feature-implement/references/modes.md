# Feature-Implement Modes

`magento2-feature-implement` has four modes. The mode is chosen during Phase 1 from the
user's request, with `feature` as the default.

## Mode: `feature` (default)

The full 7-phase pipeline as described in `SKILL.md`. Choose when the user describes
**new functionality** — a new module, a new surface, a meaningful behaviour change.

All gates apply (Phase 2 blueprint approval, Phase 4 plan approval).

**Smoke scope (Phase 6B):** full battery — every applicable suite from S1 to S9.

**Documentation scope (Phase 7A):** full set — per-module docs via `magento2-docs-generate`,
`spec.md`, developer + user HTML guides with screenshots, API payload examples when a REST/GraphQL
surface exists, plus applicable artifacts. See `documentation-guide.md`.

## Mode: `hotfix`

Skip Phases 3-4 (Module Schema, Task Breakdown). Use when the request is **small and
already understood**: a one-file bug fix, a single config tweak, a small text or label
change. The blueprint is reduced to a 3-section variant (problem, change, verification).

Triggered when the user's request includes:
- `hotfix`, `quick fix`, `small change`, `one-liner`, `tiny`
- AND the change touches ≤ 3 files in ≤ 1 module

If after Phase 1 the change is bigger than that, escalate to `feature` mode and notify
the user: "Change is larger than initial estimate — switching to full mode."

### Hotfix Pipeline

| Phase | Action |
|-------|--------|
| 0 | `magento2-context` invocation |
| 1 | Collect: symptom + intended change + verification |
| 2 | Mini-blueprint (3 sections): problem, change, verification. Save to `.docs/{slug}/blueprint.md`. |
| 3 | **SKIPPED** |
| 4 | **SKIPPED** |
| 5 | Execute: apply the change as a single task; commit; run `php -l` + `xmllint` on touched files. |
| 6 | Test: 6A unit tests for affected modules; 6B reduced smoke — S1 + S8 + only the suites for surfaces the hotfix actually touched. |
| 7 | Documentation (7A, reduced) + Report (7B): refresh the touched module's docs; short report (3 sections — what was changed, why, verification) + abbreviated Section 10 smoke summary. |

**Hotfix still invokes `magento2-module-review` after the change** (diff mode). It still
requires test coverage for the change. The only things skipped are the schema and detailed
breakdown phases — there is one logical task.

**Smoke scope (Phase 6B):**

- Always run: `S1` baseline & probe, `S8` exception.log diff, `S9` triage.
- Run conditionally on what the hotfix touched:
  - REST handler edited → `S2` (only the affected endpoints).
  - Admin controller / layout / config XML edited → `S3` + `S4` (only changed sections) + `S6`.
  - Frontend page / template / JS edited → `S6` (the affected route) + `S7` (only the affected
    My Account tab if any).
  - Grid declaration edited → `S5` (only the affected grid).
- The loop and 5-iteration cap apply identically.

**Documentation scope (Phase 7A):** reduced — refresh the touched module's `technical-reference.md`
+ add a `CHANGELOG.md` note. No full guide set unless the hotfix changed admin/API behaviour a user
or developer relies on. See `documentation-guide.md`.

## Mode: `extend`

For adding a single surface (plugin / observer / patch / data patch) to an existing
module without creating new modules. Reuses Phase 2-4 in a shortened form (no module
schema; one task block).

Pipeline:

| Phase | Action |
|-------|--------|
| 0 | `magento2-context` |
| 1 | Collect: target module + surface + intent |
| 2 | Mini-blueprint: surface, files added, interactions |
| 3 | **SKIPPED** |
| 4 | Task list (minimal): one M*/X* task + R* + T* + V*, **written to `plan.md` with a `## Current State` checklist**. Phase 4 is **not** skipped in `extend` — only Phase 3 is. |
| 5 | Execute via `magento2-module-create --augment` for the new files; mark each task `[x]` in `plan.md` `## Current State` on completion — SKILL.md Phase 5 *Per-task completion protocol*. |
| 6 | Test: 6A unit tests; 6B reduced smoke per the same rules as `hotfix` mode — S1 + S8 + only the suites for the added surface. |
| 7 | Documentation (7A) + Report (7B) |

**Smoke scope (Phase 6B):** same shape as `hotfix` — always S1/S8/S9, plus suite(s) matching
the added surface (e.g. observer added → S6 of the controller that dispatches the event;
plugin on a public service → S2 + S3/S5 of the affected admin surface).

**Documentation scope (Phase 7A):** update the affected module's docs and refresh the developer/user
guide sections the new surface touches; add API examples if the surface is REST/GraphQL; `spec.md`
only if the design changed. See `documentation-guide.md`.

## Mode: `spike`

Time-boxed exploration. Produces code that is explicitly NOT for merge. Skips the review
gates (Critical/High findings logged as info), skips coverage targets, skips deploy.

Use when the user says: `spike`, `prototype`, `proof of concept`, `experiment`.

Pipeline runs Phases 0-1-2-5 only, and saves output to `.docs/spikes/{slug}/`. Report
includes a "Promotion checklist" listing what would need to happen to move the spike to a
real feature.

**Smoke scope (Phase 6B):** entirely skipped. Spikes do not run smoke; the promotion
checklist must include "run full Phase 6B in `feature` mode" as a prerequisite for merge.

**Documentation scope (Phase 7A):** entirely skipped. The promotion checklist must also include
"generate full documentation in `feature` mode" as a prerequisite for merge.

## Mode Selection Algorithm

1. Look for explicit mode flag: `--mode=hotfix`, `--mode=extend`, `--mode=spike`.
2. Else scan user request for keywords (table below).
3. Else default to `feature`.

| User says | Mode |
|-----------|------|
| "hotfix" / "quick fix" / "one-liner" | hotfix |
| "add a plugin to X" / "add an observer to X" | extend |
| "spike" / "prototype" / "proof of concept" | spike |
| (anything else) | feature |

State the chosen mode at the start of Phase 1 explicitly:

> Mode: `hotfix`. Skipping Phases 3-4 — small change scope.

## Phase 5 Hotfix Loop

Hotfix mode collapses Phase 5 to a single task. The execute loop is:

1. Identify the file(s) to change.
2. Apply the change.
3. Run `php -l` / `xmllint` on touched files.
4. Invoke `magento2-module-review --diff` on the touched module(s).
5. Fix Critical/High; log Medium.
6. Commit with prefix `[hotfix]`.

No M*, R*, T* task breakdown — the change is a single unit. `hotfix` skips Phase 4, so there is
no `plan.md` / `## Current State` to maintain and no resume bookkeeping applies; the Per-task
completion protocol is an `extend`/`feature`-mode concern. (If a hotfix grows past 3 files or
needs a new module, escalate to `feature` mode per the Escalation Rules — that mode does write
`plan.md`.)

## Escalation Rules

| Trigger | Action |
|---------|--------|
| Hotfix change touches > 3 files | Escalate to `feature` mode, notify user |
| Hotfix change requires a new module | Escalate to `feature` mode, notify user |
| Extend change requires a new surface not in scope | Re-plan and notify |
| Spike produces code worth keeping | Suggest re-running in `feature` mode |
