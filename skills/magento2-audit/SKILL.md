---
name: magento2-audit
description: >-
  Use when the user wants a full pre-release, release-readiness, or "audit everything" pass over a
  Magento 2 module or codebase — one command that runs every read-only findings dimension and
  returns a SINGLE consolidated, de-duplicated, severity-ranked report plus one merged SARIF for CI
  / GitHub Code Scanning. Fans the dimensions out in parallel: architecture/quality/security review
  via the `magento2-reviewer` agent per dimension, plus the specialist audits
  `magento2-security-audit`, `magento2-performance-audit`, `magento2-static-analysis`,
  `magento2-accessibility-audit`, `magento2-marketplace-prep`, and `magento2-breeze-compat-audit`
  where the module's surface warrants — then consolidates. Read-only; never modifies code. For a
  SINGLE dimension, invoke that skill directly (`magento2-module-review`, `magento2-security-audit`,
  `magento2-performance-audit`); to BUILD or change functionality rather than inspect it, use
  `magento2-feature-implement`.
---

# Magento 2 Audit

Read-only **release-readiness orchestrator**. Runs the whole findings family over a module (or
codebase), fans the dimensions out in parallel, and collapses their per-dimension JSON/SARIF into
one consolidated, de-duplicated, severity-ranked report + one merged SARIF. This is the *inspect*
counterpart to `magento2-feature-implement` (which *builds*).

## Core Rules

- **Read-only.** This skill and every dimension it dispatches only read and emit reports. It never
  edits code. Remediation is a separate, explicit step — route findings to the owning skill
  afterwards (see **Fix Routing** below), exactly as `magento2-module-review` does.
- **Delegate by probing, never by assumption.** The dimension skills ship in the **same plugin**;
  decide a dimension's availability by *attempting* its invocation and falling back only on an
  actual failure. Never pre-declare a sibling skill unreachable.
- **One artifact home.** Every dimension is invoked with `--docs-root=<output_root>` so all
  per-dimension artifacts and the consolidated report nest under one folder (see
  `magento2-context/references/artifact-layout.md`). `{output_root}` is the `--docs-root` value when
  passed, else `{ctx.docs_root}`.
- **Consolidate, don't concatenate.** The deliverable is ONE document — deduplicated across
  dimensions by `file:line`+category+title, severity-normalized, with a single verdict. Never hand
  the user seven separate reports to reconcile.
- **Parallel dispatch needs authorization.** Fanning out subagents is opt-in the same way
  `magento2-module-review`'s parallel review is — see `references/parallel-dispatch.md`. Without it,
  run the dimensions sequentially; the consolidation is identical either way.
- **Adaptive scope.** Only run the dimensions the module's surface warrants (accessibility only when
  storefront templates exist; breeze-compat only under a Breeze theme; marketplace only when
  release-readiness is asked for). Record skipped dimensions in the report — never let an unrun
  dimension read as "clean."

## Workflow

### Phase 0 — Context

Invoke `magento2-context` once. Resolve vendor, edition, Magento/PHP versions, runner, theme
(including Breeze), and available tools. All dimensions inherit this — never re-probe per dimension.

### Phase 1 — Scope and dimension selection

Resolve the target module(s) or `--scope=site`. Detect the surfaces present and pick the dimension
set from `references/dimensions.md`:

- **Always:** architecture/quality/security **review**, **security-audit**, **performance-audit**,
  **static-analysis**.
- **Conditional:** **accessibility-audit** (storefront `.phtml` present), **breeze-compat-audit**
  (Breeze theme active), **marketplace-prep** (release-readiness / Marketplace submission requested).

Present the chosen dimension set and any skipped dimensions with the reason.

### Phase 2 — Fan-out (parallel)

Dispatch the selected dimensions concurrently. Two mechanisms (see
`references/dimensions.md` for the per-dimension table, model tier, and command):

- **Judgement dimensions** → dispatch `magento2-reviewer` subagents, one per review dimension
  (Architecture/API · Security · Frontend/admin · Testing/tooling · Performance/operations), per
  `magento2-module-review`'s `references/parallel-review.md`. Read-only agents; tier per
  `references/parallel-dispatch.md`.
- **Scripted dimensions** → run each specialist skill's `scripts/build-findings.sh`
  (security / performance / static-analysis / accessibility / marketplace / breeze-compat) with
  `--docs-root=<output_root>`. These are deterministic scanners that emit their own JSON+SARIF under
  their category dir; they need no LLM turn.

Each dimension writes a findings-schema JSON document (`magento2-context/references/findings-schema.md`).

### Phase 3 — Consolidate

Run `${CLAUDE_SKILL_DIR}/scripts/consolidate.sh` with `INPUT_JSONS` (or `INPUT_DIR`) set to the
per-dimension JSON documents from Phase 2, plus `TARGET_MODULE`, `TARGET_PATH`, `SCOPE`, and
`DOCS_ROOT=<output_root>`. It merges every dimension's findings, de-duplicates by
`file:line`+category+title (keeping the highest severity and recording every dimension that raised
it), merges `scanner_errors`, computes an overall `audit_verdict` (`PASS`/`CONDITIONAL`/`FAIL`) and
`audit_score`, and emits the consolidated `outputKind=audit` document (JSON + SARIF) via the shared
`magento2-context` hub emitter. See `references/consolidation.md`.

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

## Fix Routing

This skill never fixes; it routes. Per finding class, remediation is owned by:
`magento2-bug-fix` (behavioural/security defects with localised evidence), `magento2-feature-implement`
(`--mode=extend`, new/changed behaviour or schema), `magento2-test-generate` (coverage gaps),
`magento2-module-upgrade` (deprecations/BC breaks), `magento2-i18n` (missing translations),
`magento2-frontend-create` (theme/JS/LESS), `magento2-static-analysis` (style/PHPDoc). Mirror
`magento2-module-review`'s Fix Routing table for anything not listed.

## Inputs

```
/magento2-audit [--scope=module|site] [--include=<dim,dim>] [--exclude=<dim,dim>]
                [--release-readiness] [--docs-root=<path>] <Vendor>_<Module>[,<Module>]
```

- `--scope=site` — audit the whole `app/code` tree instead of one module.
- `--include=` / `--exclude=` — force a dimension on/off, overriding surface detection.
- `--release-readiness` — always include `marketplace-prep`.
- `--docs-root=<path>` — output-root override; see `magento2-context/references/artifact-layout.md`.

## Outputs

```
{output_root}/audits/{Vendor}_{Module}-audit-{date}.md      # consolidated report (LLM)
{output_root}/audits/{Vendor}_{Module}-audit-{date}.json     # consolidated findings (outputKind=audit)
{output_root}/audits/{Vendor}_{Module}-audit-{date}.sarif    # merged SARIF for CI / Code Scanning
```

Per-dimension artifacts remain under their own category dirs (`reviews/`, `audits/`, `quality/`,
`accessibility/`, `marketplace/`, `breeze-compat/`) so a dimension can be re-read in isolation.

## Reference Files

- `references/dimensions.md` — dimension catalogue: which skill/agent runs each, when it is included,
  its output kind, and its advisory model tier.
- `references/parallel-dispatch.md` — how to fan out subagents (authorization, model tiers,
  sequential fallback).
- `references/consolidation.md` — the dedup key, severity-normalization, and verdict/score rules.
- `${CLAUDE_SKILL_DIR}/scripts/consolidate.sh` — merges the per-dimension JSON documents into one
  `audit` document (JSON + SARIF) via `magento2-context/scripts/emit-findings.sh`.
- `magento2-context/references/severity.md` — the shared five-point severity scale.
- `magento2-context/references/findings-schema.md` — the findings-document structure
  (`outputKind=audit`).

## Related Skills

| Need | Skill |
|------|-------|
| One dimension only | `magento2-module-review`, `magento2-security-audit`, `magento2-performance-audit`, `magento2-accessibility-audit`, `magento2-static-analysis`, `magento2-marketplace-prep`, `magento2-breeze-compat-audit` |
| Build / change behaviour | `magento2-feature-implement` |
| Fix a routed finding | `magento2-bug-fix`, `magento2-module-upgrade`, `magento2-test-generate` |
| Environment context | `magento2-context` |
