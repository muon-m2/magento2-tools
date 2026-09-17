---
name: triage
version: 1.0.0
description:
    Read-only triage of Magento 2 findings documents — turns an audit/review/security/performance
    JSON report into an ordered, approvable remediation plan. Each finding is fingerprinted,
    checked against the project's waivers, gated on confidence, routed to the skill that owns its
    fix through the shared routing matrix, and grouped into dependency-ordered batches (upgrade →
    fix → structural → frontend → i18n → test-generate → lint → docs). Use when the user asks who
    should fix these findings, wants a remediation order or fix plan, or asks to triage a report.
    Consumes the documents magento2-tools:audit and the other findings skills emit — it never
    re-scans and never edits code. Hand the emitted plan to magento2-tools:remediate to execute it,
    or invoke the owning skill (e.g. magento2-tools:fix) batch by batch. To produce findings for a
    single dimension first, run magento2-tools:review, magento2-tools:security or
    magento2-tools:perf-audit directly.
---

# Magento 2 Findings Triage

`audit` and its sibling findings skills answer *what is wrong*. This skill answers
**what to do about it, in what order, and who does it** — and it answers with a document
a human can approve rather than a conversation that has to be re-held every run.

It is the read-only half of the remediation cycle:

```
audit / review / security / perf-audit  ──►  triage  ──►  remediate  ──►  audit --compare
        (what is wrong)                     (the plan)    (the work)      (what closed)
```

## Core Rules

- **Read-only.** Never edits a module, never writes to `vendor/`, never runs a fix. The only
  thing it writes is its own plan under the output root.
- **JSON is the contract; Markdown is never parsed.** The Markdown report is for humans. Every
  decision is made from the JSON findings document (`context/references/findings-schema.md`).
- **Never guess an owner.** Routing is resolved by `context/scripts/route-finding.sh`
  over the matrix in `context/references/fix-routing.md`. A finding with no matching
  row is reported in `unrouted[]` — it is never quietly defaulted to `fix`.
- **A waived finding is reported, never dropped.** It lands in `waived[]` with its verdict,
  reason and author, and is never counted as closed. An **expired** waiver resurfaces the
  finding instead of continuing to suppress it.
- **Only `confidence: confirmed` is schedulable.** A `candidate` or `needs-triage` finding is
  evidence to re-check, not work to book, so it is held in `verify_first[]`.
- **Nothing is silently discarded.** A finding filtered out by `--severity` or an owner filter
  is recorded in `skipped[]` with the reason.
- **Artifact location.** This skill accepts `--docs-root=<path>` (see
  `context/references/artifact-layout.md`). When set, run the builder with
  `DOCS_ROOT=<path>` so the plan lands under `<path>/remediation/`; otherwise it defaults to
  `{ctx.docs_root}/remediation/`.

## Workflow

### Phase 0 — Context

Invoke `context` once. Capture `vendor`, `docs_root`, and `theme.breeze`
(the Breeze predicate changes who owns a frontend finding).

### Phase 1 — Ingest

Resolve the input document:

| `--from` value | Behaviour |
|---|---|
| *omitted* | Newest `{output_root}/audits/*-audit-*.json`. |
| a findings `.json` | That document. |
| a directory | Every `*.json` in it, merged (per-dimension reports from one run). |

Validate `schemaVersion`: a **major** mismatch is a hard error (exit 4) — the field semantics
are not ours to guess; a **minor** one warns, is recorded in `scanner_errors[]`, and the run
continues. Markdown and SARIF are not inputs: SARIF carries no `confidence`,
`recommendation` or `verification`, so it could never drive a plan.

### Phase 2 — Fingerprint

Read each finding's `fingerprint`; a pre-1.1 document is fingerprinted on the fly with
`findings-lib.sh::finding_fingerprint`. Findings sharing a fingerprint across input
documents collapse into one entry that keeps the **highest** severity and records every
producer that raised it.

### Phase 3 — Waivers

Load `{output_root}/findings/waivers.yml` (or `--waivers=<path>`) and apply it:

| Waiver state | Result |
|---|---|
| active | `waived[]`, with verdict / reason / author. Never counted closed. |
| expired | `verify_first[]`, noted `waiver expired <date>`. |
| matches no current finding | reported in `stale_waivers[]` so dead entries get pruned. |

If the waivers file is gitignored or untracked, the run warns that the suppressions are local
only and will reset — commit the file or relocate it with `--waivers=`.

### Phase 4 — Confidence gate

`confirmed` → routable. Anything else → `verify_first[]` with the reason.

### Phase 5 — Route

One `route-finding.sh` call per finding, keyed on producer, category, subcategory,
severity, evidence file and the Breeze predicate. `unrouted` → `unrouted[]`.

### Phase 6 — Batch

Group routable findings by owner **and gate**, order the groups per
`references/plan-format.md`, and sort within a group by severity descending.
`--include` / `--exclude` filter batches without changing their relative order.

### Phase 7 — Emit and present

Run `scripts/build-plan.sh`, then present the plan for approval: batch order, owner and
gate per batch, the counts in each bucket, and the `gate: manual` items called out as human
actions (a burned credential needs rotation, not just a patch). Approval is what turns a
plan into work — this skill stops here.

## Inputs

```
/triage [--from=<path>] [--waivers=<path>] [--severity=<min>]
        [--include=<owner,…>] [--exclude=<owner,…>] [--docs-root=<path>]
        [<Vendor>_<Module>]
```

Flags map onto `scripts/build-plan.sh` env vars:

| Flag | Env var |
|---|---|
| `--from=` | `INPUT_JSON` |
| `--waivers=` | `WAIVERS_FILE` |
| `--severity=` | `MIN_SEVERITY` |
| `--include=` | `INCLUDE_OWNERS` |
| `--exclude=` | `EXCLUDE_OWNERS` |
| `--docs-root=` | `DOCS_ROOT` |
| `<Vendor>_<Module>` | `TARGET_MODULE` + `TARGET_PATH` |

## Outputs

`{output_root}/remediation/{Vendor}_{Module}-plan-{YYYY-MM-DD}.{json,sarif}` with
`outputKind=remediation`, plus a Markdown plan sharing the basename — the approval
artifact. Shape and buckets: `references/plan-format.md`.

## Reference Files

- `references/plan-format.md` — the `outputKind=remediation` document, its four buckets,
  and the batch-order rationale.
- `context/references/fix-routing.md` — the routing matrix itself (finding → owning skill).
- `context/references/findings-schema.md` — the findings document this skill consumes and
  the `remediation` output kind it emits.
- `context/references/severity.md` — the shared five-point severity scale.
- `context/references/artifact-layout.md` — the output root and filename scheme.

## Scripts

- `scripts/build-plan.sh` — ingest → waive → gate → route → batch → emit.
- `scripts/inject-plan-sections.sh` — `POST_JSON_HOOK` that adds the plan's top-level
  buckets to the emitted document.

## Acceptance Criteria

- Produces `{Vendor}_{Module}-plan-{date}.json` with `outputKind=remediation`, per-finding
  `owner` / `gate` / `batch` / `routing_rationale` / `status` / `source_finding`, and the
  top-level `batches[]`, `waived[]`, `verify_first[]`, `unrouted[]`, `stale_waivers[]`.
- Every ingested finding appears in exactly one bucket; none is dropped.
- `lint` is always the last batch, and `upgrade` (when present) the first.
- No file outside `{output_root}/remediation/` is created or modified.

## Related Skills

- `audit` — produces the consolidated findings document this skill triages.
  *audit finds; triage decides who fixes.*
- `remediate` — executes the plan batch by batch and reports what closed.
- `review` / `security` / `perf-audit` / `lint` / `a11y-audit` /
  `marketplace` / `breeze-compat` — the individual dimensions; run one directly when
  only that dimension is wanted.
- `fix`, `feature`, `upgrade`, `extension-point`, `indexer`,
  `message-queue`, `webapi`, `graphql`, `admin-form`,
  `admin-listing`, `frontend`, `breeze-adapt`, `i18n`,
  `test-generate`, `docs` — the owning skills a plan routes to.
