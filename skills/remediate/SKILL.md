---
name: remediate
version: 1.0.0
description:
    Execute an approved remediation plan — the write half of the findings cycle. Consumes the plan
    magento2-tools:triage emits (or an audit document, which it triages inline first), works batch
    by batch in dependency order, and invokes the skill that owns each finding with that finding's
    fingerprint and evidence so the diagnosis is never re-derived. One approval per batch, one
    commit per finding carrying a Closes-Finding trailer, and a closure diff from
    magento2-tools:audit --compare at the end to prove what actually closed. Use when the user asks
    to fix, remediate, or work through the findings in a report. Never edits vendor/, and a
    gate: manual item (a leaked credential needs rotation, not a deleted line) is reported as a
    human action, never executed. For one user-reported bug use magento2-tools:fix; to build new
    behaviour use magento2-tools:feature; to find or re-check findings use magento2-tools:audit,
    which stays read-only.
---

# Magento 2 Findings Remediation

`triage` produces a plan a human can approve. This skill **executes that plan** — batch by
batch, through the skill that owns each finding, with one approval per batch and one commit
per finding.

It is the write half of the remediation cycle:

```
audit / review / security / perf-audit  ──►  triage  ──►  remediate  ──►  audit --compare
        (what is wrong)                     (the plan)    (the work)      (what closed)
```

It is an **orchestrator, not an implementer**: it decides *what runs next and whether it may
run*, and the owning skill does the work under its own discipline. Where `feature` orchestrates
building new behaviour, this skill orchestrates closing known defects.

## Core Rules

- **Never edits `vendor/`.** A finding in a third-party or core module is remediated by a
  plugin, observer or preference in a **project** module — the owning skill
  (`extension-point`) knows how; this skill simply never accepts a patch under
  `vendor/`. Inherited from `fix`.
- **Dedicated branch.** Work happens on `remediation/{slug}`, created when the current branch is
  the default branch or detached. **Refuse to start on a dirty tree** — a per-finding commit is
  only attributable if nothing else is in the index.
- **One commit per finding**, `[remediate]` prefix, with a `Closes-Finding: <fingerprint>`
  trailer so the closure diff can attribute a commit back to the finding it closed. An owning
  skill that already commits per finding under its own convention keeps its prefix — `fix
  --from-finding=` writes `[bug-fix]` *with* the same trailer — because the trailer is what
  carries identity and the prefix records who did the work. Never commit the same change
  twice. Format: `references/commit-format.md`.
- **Scope is the finding.** No surrounding cleanup, no opportunistic refactor. A finding that
  turns out to need more than its evidence describes is recorded `deferred`, reported with what
  it would take, and **never expanded into**.
- **One approval per batch, never per finding.** The batch presentation is the gate; once it is
  approved the batch runs to completion without re-prompting. `fix` and the other owning skills
  delegate their own gate upward for exactly this reason (`fix/references/from-finding.md`).
- **`gate: manual` is never executed.** It is presented as a human action item and carried into
  the report. Deleting the line that printed a credential does not un-leak the credential; the
  fix is rotation, and only a human can do it.
- **No silent passes.** A finding whose `verification` fails is `still-open` with the failed
  attempt recorded. A batch whose owning skill is unavailable is `skipped` with the reason.
  Neither is **ever** counted clean — a gate that checked nothing does not report a pass.
- **The plan is the input, not a suggestion.** Batch order, owner and gate come from the plan;
  this skill does not re-route a finding or re-order a batch. If the routing looks wrong, fix
  `context/references/fix-routing.md` and re-run `triage`.
- **Artifact location.** This skill accepts `--docs-root=<path>` (see
  `context/references/artifact-layout.md`) and threads the **same** value into every
  sub-skill invocation, so one run's artifacts stay in one root. Otherwise the run report lands
  under `{ctx.docs_root}/remediation/`.

## Workflow

### Phase 0 — Context and branch

Invoke `context` once; capture `vendor`, `docs_root`, `runner` and `theme.breeze`.

Then resolve the working branch:

| Current branch | Action |
|---|---|
| default (`main`/`master`) or detached | Create `remediation/{slug}` from it. |
| already `remediation/*` | Reuse it — this is a resumed run. |
| any other feature branch | Ask once whether to branch or to continue on it. |

`{slug}` is the plan's target module lower-kebab plus its date —
`remediation/acme-orderexport-2026-09-16`.

**A dirty working tree stops the run here.** Report the dirty paths and stop; do not stash,
do not commit the user's work-in-progress.

Under `--dry-run` nothing in this phase happens beyond resolving `context`: no branch is
created and a dirty tree is reported as a warning, not a stop — the point of a dry run is to
inspect the plan's routing before deciding to start.

### Phase 1 — Load the plan

`--from=<plan.json>` is a `triage` document (`outputKind=remediation`). Given an
`*-audit-*.json` or any other findings document instead, invoke `triage` inline first and
use the plan it emits — this skill never routes findings itself.

With `--from` omitted, use the newest `{output_root}/remediation/*-plan-*.json`.

Validate before executing:

- `outputKind` is `remediation` — anything else is a hard error naming `triage`.
- The plan's `target` matches the module in the working tree.
- Every fingerprint in `batches[]` resolves to a finding in `findings[]`.

Findings in `waived[]`, `verify_first[]` and `unrouted[]` are **not executed** — they are
carried into the run report so the plan's decisions stay visible in its outcome.

### Phase 2 — Present the batch (the gate)

For each batch in plan order, present in one message:

- batch sequence, **owner** skill and **gate**;
- every finding: severity, title, `file:line` evidence, and the **drafted intent** — one line
  of what will change, from the finding's `recommendation`, not a re-diagnosis;
- the verification that will decide whether it closed;
- anything in the batch that is `gate: manual`, called out as a human action.

Then take **one approval for the whole batch**. `--yes-auto` pre-approves batches whose gate is
`auto` (mechanical and reversible — `lint` style fixes and the like); a `batch` gate always
asks, and a `manual` gate is never executable, so there is nothing to approve.

`--dry-run` stops at this presentation for every batch: it creates no branch, invokes no skill,
writes no commit, and prints the batches, owners, gates and the intended per-finding
invocations. It is the cheap way to inspect routing before committing to a run.

### Phase 3 — Execute the batch

Per finding, in the plan's order (severity descending within a batch), invoke the **owner**
named in the plan. The invocation always carries the report path, the fingerprint and the
evidence, so the owning skill does not re-derive the diagnosis:

```
fix --from-finding=<plan.json>#<finding-id> --docs-root=<root>
```

and, for a generator owner, the finding's evidence and recommendation plus the same
`--docs-root`. The per-owner contract is in `references/batch-execution.md`.

After each finding:

1. Run the finding's `verification`.
2. Commit that finding alone, per `references/commit-format.md`.
3. Record the outcome:

| Outcome | When |
|---|---|
| `closed` | The change landed **and** the verification passed. |
| `still-open` | Executed, but the verification failed or the diff did not address the evidence. The attempt and its output are recorded. |
| `deferred` | The finding needs more than its evidence describes (a redesign, a missing module, a decision). Recorded with what it would take; nothing is committed. |
| `pending-manual` | `gate: manual`. Never executed; carried into the human action items. |

A finding that is `still-open` or `deferred` does **not** abort the batch, and it is never
reported as closed.

### Phase 4 — Next batch

Repeat Phases 2–3 in the plan's batch order. A failed or skipped batch does not abort the run:
record it and proceed. `--batch=<owner,…>` restricts the run to those batches without changing
their relative order.

If an owning skill is unavailable — not installed, or refusing for its own reason — mark the
whole batch `skipped` with that reason and move on. The batch's findings stay open in the
report and in the closure diff.

### Phase 5 — Closure

Unless `--no-closure` is set, invoke:

```
audit --compare=<baseline.json> --docs-root=<same root>
```

`<baseline.json>` is the document the plan was built from — the plan's `inputs[].path`, or the
consolidated `audits/*-audit-*.json` when it was built from several.

`audit` re-runs the dimensions that produced the baseline and diffs by fingerprint into
`closed` / `still_open` / `waived` / `regressed` / `skipped`. **The closure document is
`audit`'s artifact, not this skill's** — exactly one skill owns verdicts and scores. This
skill links to it.

Read the `regressed` bucket before writing the report: a finding absent from the baseline and
present now was introduced by this run, and that is the most important thing the run has to
say.

### Phase 6 — Report

Write the run report to `{output_root}/remediation/{Vendor}_{Module}-report-{date}.md` from
`templates/report.md`: per-batch outcomes, deferred findings with reasons, the **human action
items** (credential rotations first), the link to the closure document, and residual risk.

Then summarise in the conversation: what closed, what is still open, what a human must do
next. Never claim a clean run from an unverified batch.

## Inputs

```
/remediate [--from=<plan.json|audit.json>] [--batch=<owner,…>] [--dry-run]
           [--yes-auto] [--no-closure] [--docs-root=<path>] [<Vendor>_<Module>]
```

| Flag | Effect |
|---|---|
| `--from=` | The plan to execute. An audit/findings document is triaged inline first. Default: newest `{output_root}/remediation/*-plan-*.json`. |
| `--batch=` | Run only these owners' batches, in the plan's order. |
| `--dry-run` | Execute nothing. Print batches, owners, gates and intended invocations. |
| `--yes-auto` | Pre-approve `gate: auto` batches only. `batch` gates still ask. |
| `--no-closure` | Skip Phase 5. The report then states that closure was **not** verified. |
| `--docs-root=` | Output root, threaded into every sub-skill invocation. |

## Outputs

```
{output_root}/remediation/{Vendor}_{Module}-report-{date}.md    # this skill's run report
{output_root}/audits/{Vendor}_{Module}-closure-{date}.*         # audit --compare (Phase 5)
```

Plus one git commit per closed finding on `remediation/{slug}`, each carrying its
`Closes-Finding` trailer. This skill does **not** push, open a PR, or merge — the branch is
handed back for review.

## Reference Files

- `references/batch-execution.md` — batch order and its rationale, the per-owner invocation
  contract, how a gate is presented, and the failure policy.
- `references/commit-format.md` — the `[remediate]` commit and its `Closes-Finding` trailer.
- `templates/report.md` — the run report.
- `triage/references/plan-format.md` — the plan document this skill consumes.
- `fix/references/from-finding.md` — report-driven entry, and the gate `fix` delegates
  upward to this skill.
- `context/references/fix-routing.md` — the routing matrix and the gate vocabulary. Read,
  never re-decided, here.
- `context/references/findings-schema.md` — the finding object, `outputKind=remediation`
  and `outputKind=closure`.
- `context/references/artifact-layout.md` — the output root and filename scheme.
- `feature/references/per-task-commits.md` — the shared per-unit commit discipline this
  skill's one-commit-per-finding rule follows.

## Acceptance Criteria

- Runs only on a clean tree, only on a `remediation/*` branch.
- Every executed finding has exactly one commit carrying its `Closes-Finding: <fingerprint>`
  trailer, and no commit touches `vendor/`.
- Exactly one approval is taken per batch; no finding prompts individually.
- No `gate: manual` finding was executed, and every one appears in the report's human action
  items.
- Every finding in the plan appears in the run report with an outcome; a failed verification
  is `still-open` and an unavailable owner is a `skipped` batch — neither is counted closed.
- `--dry-run` creates no branch, no commit and no file — it only prints.

## Related Skills

| Need | Skill |
|---|---|
| Turn a findings report into the plan this skill executes | `triage` |
| Produce the findings in the first place, or verify closure | `audit` (read-only; owns `--compare`) |
| Fix one user-reported bug, with its own RCA gate | `fix` |
| Build new behaviour rather than close a known defect | `feature` |
| Change **who** owns a finding class | `context/references/fix-routing.md`, then re-run `triage` |

The owning skills a batch invokes — `upgrade`, `fix`, `extension-point`,
`indexer`, `message-queue`, `webapi`, `graphql`,
`admin-form`, `admin-listing`, `system-config`,
`data-migration`, `frontend`, `breeze-adapt`, `i18n`,
`test-generate`, `lint`, `docs` — each keep their own discipline; this skill
only decides what runs next and whether it may run.
