# Remediation Plan Format

The document `triage` emits: `outputKind=remediation`, written to
`{output_root}/remediation/{Vendor}_{Module}-plan-{YYYY-MM-DD}.json` (+ `.sarif`).

It reuses the findings envelope defined in `context/references/findings-schema.md`
verbatim — `schemaVersion`, `skill`, `target`, `runAt`, `summary`, `findings`, `skipped`,
`tools`, `scanner_errors`. Only the additions are described here. The routing matrix itself
is **not** restated: it lives in `context/references/fix-routing.md` and is
resolved by `context/scripts/route-finding.sh`.

## Per-finding additions

Every entry in `findings[]` is the source finding, unchanged, plus the routing decision:

| Field | Notes |
|---|---|
| `fingerprint` | Carried from the source document, or computed with `findings-lib.sh::finding_fingerprint` for a pre-1.1 one. This is the key a waiver and a closure verdict are recorded against. |
| `owner` | The skill that owns the fix. `none` when nothing executable owns it (waived, held for verification, or a matrix row that routes to no skill). `unrouted` when no row matched. |
| `gate` | `auto` \| `batch` \| `manual` — from the matched matrix row. |
| `batch` | 1-based batch sequence. **Absent** unless the finding is routable and has an executable owner. |
| `routing_rationale` | The matrix row (or the bucket decision) that produced the owner. Routing is never an ad-hoc judgement, so the reason travels with the result. |
| `status` | `routable` \| `waived` \| `verify-first` \| `unrouted`. |
| `source_finding` | `{id, producer}` in the source document. |
| `producers` | Present only when one fingerprint was raised by more than one dimension. |

`id` is re-issued as `triage-{date}-{seq}`; the original lives on in `source_finding.id`.

## The four buckets

Every ingested finding is in `findings[]` **and** in exactly one bucket. Nothing is dropped —
a plan that quietly loses a finding is worse than no plan.

| Bucket | Holds | Why it is a bucket and not a batch |
|---|---|---|
| `batches[]` | `{seq, owner, gate, fingerprints[]}` — the execution order `remediate` follows. | — |
| `waived[]` | Findings suppressed by an **unexpired** waiver, with `verdict`, `reason`, `author`, `expires`. | A decision already taken. Reported so it stays visible; never counted as closed. |
| `verify_first[]` | Findings whose evidence must be re-checked first: `confidence != confirmed`, or a waiver that has **expired**. | Evidence that is not confirmed cannot drive an automated patch. An expired waiver resurfaces the finding rather than continuing to hide it. |
| `unrouted[]` | Findings the matrix has no row for. | Reported as data. Defaulting them to `fix` would turn "we have no owner for this" into "fix owns it", which is how the old prose tables funnelled specialist work to the wrong skill. |

Two further top-level fields:

- `stale_waivers[]` — waiver fingerprints matching nothing in this run, so dead entries get
  pruned rather than accumulating.
- `inputs[]` — `{path, skill, schemaVersion, outputKind, findings}` per ingested document, so
  a plan says what it was built from.

Findings removed by `--severity` or an owner filter are recorded in the envelope's own
`skipped[]` with the reason.

## Batch order

The order is a **dependency order, not a priority order**. A Critical finding owned by `lint`
still runs last, because running it first guarantees re-churn.

```
1. upgrade                        rewrites call sites the later batches would otherwise
                                  patch twice
2. fix                            behavioural and security defects, applied to the
                                  migrated code
3. structural owners              extension-point · indexer · message-queue · webapi ·
                                  graphql · admin-form · admin-listing · system-config ·
                                  data-migration · feature · inline
4. frontend                       frontend · breeze-adapt
5. i18n                           runs once every user-facing string the run will produce
                                  exists
6. test-generate                  tests written against final code
7. lint                           LAST — formats everything the run produced and catches
                                  style the remediation itself introduced
8. docs                           regenerates module docs, picking up what changed
```

An owner the list does not name sorts into the **structural** group: it is specialist work,
not something that should jump ahead of `upgrade` or trail behind `lint`.

Within a batch, findings are ordered by severity descending.

`--include` / `--exclude` remove batches; they never reorder the ones that remain.

## One batch, one gate

A batch is **one approval**, and an approval means a different thing per gate — `auto` is
"apply it", `batch` is "do this group of edits", `manual` is "a human must act". So a batch
never mixes gates: findings group by `(owner, gate)`, and within one owner the gates run
`auto`, then `batch`, then `manual`.

`gate: manual` items are presented but never auto-executed. A leaked credential's fix is
rotation, not deletion of the line that printed it — `remediate` lists it as a human action
and `audit --compare` tags it `pending-manual` rather than "remediation failed".

## Gate vocabulary

Defined once in `context/references/fix-routing.md`; summarised here only so a
reader of a plan knows what the column means.

| Gate | Meaning |
|---|---|
| `auto` | Mechanical and reversible — apply without a per-finding question. |
| `batch` | Needs one approval for the group before the owning skill runs. |
| `manual` | Never executed automatically; reported as a human action. |
