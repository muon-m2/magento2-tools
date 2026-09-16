---
name: audit
version: 1.1.0
description: >-
  Use when the user wants a full pre-release, release-readiness, or "audit everything" pass over a
  Magento 2 module or codebase — one command that runs every read-only findings dimension and
  returns a SINGLE consolidated, de-duplicated, severity-ranked report plus one merged SARIF for CI
  / GitHub Code Scanning. Fans the dimensions out in parallel: architecture/quality/security review
  via the `reviewer` agent per dimension, plus the specialist audits
  `magento2-tools:security`, `magento2-tools:perf-audit`, `magento2-tools:lint`,
  `magento2-tools:a11y-audit`, `magento2-tools:marketplace`, and `magento2-tools:breeze-compat`
  where the module's surface warrants — then consolidates. Read-only; never modifies code. For a
  SINGLE dimension, invoke that skill directly (`magento2-tools:review`, `magento2-tools:security`,
  `magento2-tools:perf-audit`); to BUILD or change functionality rather than inspect it, use
  `magento2-tools:feature`.
---

# Magento 2 Audit

Read-only **release-readiness orchestrator**. Runs the whole findings family over a module (or
codebase), fans the dimensions out in parallel, and collapses their per-dimension JSON/SARIF into
one consolidated, de-duplicated, severity-ranked report + one merged SARIF. This is the *inspect*
counterpart to `feature` (which *builds*).

## Core Rules

- **Read-only.** This skill and every dimension it dispatches only read and emit reports. It never
  edits code. This includes `--compare`, which diffs two runs — it measures remediation, it does
  not perform any. Remediation is a separate, explicit step — route findings to the owning skill
  afterwards (see **Fix Routing** below), exactly as `review` does.
- **Delegate by probing, never by assumption.** The dimension skills ship in the **same plugin**;
  decide a dimension's availability by *attempting* its invocation and falling back only on an
  actual failure. Never pre-declare a sibling skill unreachable.
- **One artifact home.** Every dimension is invoked with `--docs-root=<output_root>` so all
  per-dimension artifacts and the consolidated report nest under one folder (see
  `context/references/artifact-layout.md`). `{output_root}` is the `--docs-root` value when
  passed, else `{ctx.docs_root}`.
- **Consolidate, don't concatenate.** The deliverable is ONE document — deduplicated across
  dimensions by `file:line`+category+title, severity-normalized, with a single verdict. Never hand
  the user seven separate reports to reconcile.
- **Parallel dispatch needs authorization.** Fanning out subagents is opt-in the same way
  `review`'s parallel review is — see `references/parallel-dispatch.md`. Without it,
  run the dimensions sequentially; the consolidation is identical either way.
- **Adaptive scope.** Only run the dimensions the module's surface warrants (accessibility only when
  storefront templates exist; breeze-compat only under a Breeze theme; marketplace only when
  release-readiness is asked for). Record skipped dimensions in the report — never let an unrun
  dimension read as "clean."

## Workflow

### Phase 0 — Context

Invoke `context` once. Resolve vendor, edition, Magento/PHP versions, runner, theme
(including Breeze), and available tools. All dimensions inherit this — never re-probe per dimension.

### Phase 1 — Scope and dimension selection

Resolve the target module(s) or `--scope=site`. Detect the surfaces present and pick the dimension
set from `references/dimensions.md`:

- **Always:** architecture/quality/security **review**, **security**, **perf-audit**,
  **lint**.
- **Conditional:** **a11y-audit** (storefront `.phtml` present), **breeze-compat**
  (Breeze theme active), **marketplace** (release-readiness / Marketplace submission requested).

Present the chosen dimension set and any skipped dimensions with the reason.

## Execution Mode

Default: **agents** — the fan-out below is this skill's whole point. `--inline` (or
`execution_mode` in `.claude/m2.json`, surfaced as `{ctx.execution_mode}`; selection
contract in `context/references/execution-modes.md`) runs the same dimensions sequentially in the
main conversation instead — same dimension set, same consolidation, same artifacts;
slower, but every intermediate step is visible and steerable.

### Phase 2 — Fan-out (parallel)

Dispatch the selected dimensions concurrently. Two mechanisms (see
`references/dimensions.md` for the per-dimension table, model tier, and command):

- **Judgement dimensions** → dispatch `reviewer` subagents, one per review dimension
  (Architecture/API · Security · Frontend/admin · Testing/tooling · Performance/operations), per
  `review`'s `references/parallel-review.md`. Read-only agents; tier per
  `references/parallel-dispatch.md`.
- **Scripted dimensions** → run each specialist skill's `scripts/build-findings.sh`
  (security / perf-audit / lint / a11y-audit / marketplace / breeze-compat) with
  `--docs-root=<output_root>`. These are deterministic scanners that emit their own JSON+SARIF under
  their category dir; they need no LLM turn.

Each dimension writes a findings-schema JSON document (`context/references/findings-schema.md`).

### Phase 3 — Consolidate

Run `${CLAUDE_SKILL_DIR}/scripts/consolidate.sh` with `INPUT_JSONS` (or `INPUT_DIR`) set to the
per-dimension JSON documents from Phase 2, plus `TARGET_MODULE`, `TARGET_PATH`, `SCOPE`, and
`DOCS_ROOT=<output_root>`. It merges every dimension's findings, de-duplicates by
`file:line`+category+title (keeping the highest severity and recording every dimension that raised
it), merges `scanner_errors`, computes an overall `audit_verdict` (`PASS`/`CONDITIONAL`/`FAIL`) and
`audit_score`, and emits the consolidated `outputKind=audit` document (JSON + SARIF) via the shared
`context` hub emitter. See `references/consolidation.md`.

### Phase 4 — Report

Author the consolidated Markdown report at
`{output_root}/audits/{Vendor}_{Module}-audit-{date}.md`:

- **Verdict + score** (from Phase 3) and a one-line readiness statement.
- **Dimension coverage table** — every dimension run, its finding count, and every dimension
  skipped with the reason.
- **Findings**, severity-ranked, each with `file:line` evidence, the dimension(s) that raised it,
  impact, and recommendation. Cross-dimension duplicates appear once.
- **Fix Routing** — the owning skill for each finding class (see below), so remediation is a
  deterministic next step.

### Phase 5 — Closure diff (`--compare` only)

Given `--compare=<baseline.json>`, re-run the same dimension set, then run
`${CLAUDE_SKILL_DIR}/scripts/compare-findings.sh` with `BASELINE_JSON`, `CURRENT_JSON`,
`TARGET_MODULE`, `TARGET_PATH` and `DOCS_ROOT`. It diffs the two documents **by fingerprint**
(not by `id`, which is regenerated each run, nor by line, which moves on the first patch) into
five buckets:

| Bucket | Meaning |
|--------|---------|
| `closed` | In the baseline, absent now. |
| `still_open` | In the baseline, present now. |
| `waived` | Suppressed by `{output_root}/findings/waivers.yml` — reported with its reason, never counted closed. |
| `regressed` | **Absent from the baseline, present now** — introduced by the remediation itself. |
| `skipped` | Raised by a scanner that crashed or is `degraded`/`skipped` on the re-run. **Never** closed: absence of a result is not a result. |

A `gate: manual` item the human has not yet actioned re-appears in `still_open`, which is
accurate — but tag it `pending-manual` in the report so "remediation failed" stays
distinguishable from "awaiting a human action the plan named".

Author the Markdown closure report alongside the JSON: the bucket counts, the
`verdict_delta` and `score_delta`, every regression in full, and the residual risk.

## Fix Routing

This skill never fixes; it routes. The mapping is a **contract, not a judgement call** — it
lives in `context/references/fix-routing.md` and is resolved by
`context/scripts/route-finding.sh`, keyed on each finding's producing skill and
`category`. Do not restate it here and do not pick an executing skill ad hoc.

The consolidated report's Fix Routing section is generated by running `route-finding.sh` over
each finding. A finding whose row yields `unrouted` is reported as unrouted — never quietly
defaulted to `fix`.

To turn the whole report into an ordered, approvable remediation plan — waivers applied,
low-confidence findings held back, batches in dependency order — use `triage`;
`remediate` then executes that plan.

## Inputs

```
/audit [--scope=module|site] [--include=<dim,dim>] [--exclude=<dim,dim>]
                [--release-readiness] [--docs-root=<path>] <Vendor>_<Module>[,<Module>]
```

- `--scope=site` — audit the whole `app/code` tree instead of one module.
- `--include=` / `--exclude=` — force a dimension on/off, overriding surface detection.
- `--release-readiness` — always include `marketplace`.
- `--compare=<baseline.json>` — after re-running the dimensions, diff against that earlier
  findings document and emit a closure report (Phase 5). Note this re-runs **every** selected
  dimension, including ones the remediation did not touch; narrow it with `--include=` when
  the remediation was targeted.
- `--docs-root=<path>` — output-root override; see `context/references/artifact-layout.md`.

## Outputs

```
{output_root}/audits/{Vendor}_{Module}-audit-{date}.md      # consolidated report (LLM)
{output_root}/audits/{Vendor}_{Module}-audit-{date}.json     # consolidated findings (outputKind=audit)
{output_root}/audits/{Vendor}_{Module}-audit-{date}.sarif    # merged SARIF for CI / Code Scanning
{output_root}/audits/{Vendor}_{Module}-closure-{date}.md     # --compare: closure report (LLM)
{output_root}/audits/{Vendor}_{Module}-closure-{date}.json    # --compare: outputKind=closure
{output_root}/audits/{Vendor}_{Module}-closure-{date}.sarif   # --compare: still-open + regressed
```

Per-dimension artifacts remain under their own category dirs (`reviews/`, `audits/`, `quality/`,
`accessibility/`, `marketplace/`, `breeze-compat/`) so a dimension can be re-read in isolation.

## Reference Files

- `references/dimensions.md` — dimension catalogue: which skill/agent runs each, when it is included,
  its output kind, and its advisory model tier.
- `references/parallel-dispatch.md` — how to fan out subagents (authorization, model tiers,
  sequential fallback).
- `references/consolidation.md` — the dedup key, severity-normalization, and verdict/score rules.
- `${CLAUDE_SKILL_DIR}/scripts/compare-findings.sh` — `--compare`: diffs a re-run against its
  baseline by fingerprint and emits the `closure` document (JSON + SARIF).
- `${CLAUDE_SKILL_DIR}/scripts/consolidate.sh` — merges the per-dimension JSON documents into one
  `audit` document (JSON + SARIF) via `context/scripts/emit-findings.sh`.
- `context/references/severity.md` — the shared five-point severity scale.
- `context/references/findings-schema.md` — the findings-document structure
  (`outputKind=audit`).

## Related Skills

| Need | Skill |
|------|-------|
| One dimension only | `review`, `security`, `perf-audit`, `a11y-audit`, `lint`, `marketplace`, `breeze-compat` |
| Build / change behaviour | `feature` |
| Act on the WHOLE report | `triage` (plan), then `remediate` (execute) |
| Fix ONE routed finding | `fix`, `upgrade`, `test-generate` |
| Verify the fixes closed | `audit --compare=<baseline.json>` |
| Environment context | `context` |
