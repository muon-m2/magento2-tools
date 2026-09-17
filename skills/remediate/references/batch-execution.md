# Batch Execution

How a batch is presented, executed, and accounted for. The **plan** decides what the batches
are; this document decides how they run.

## The order is a dependency order

The authoritative order travels in the plan's `batches[]`, and it is defined once in
`triage/references/plan-format.md`. It is **not** re-derived here and must not be
re-sorted — but executing it well means knowing what each position is protecting, because a
run that reorders "just this once" pays for it in re-churn or a lost fix:

| # | Batch | What breaks if it runs later |
|---|---|---|
| 1 | `upgrade` | It rewrites call sites. Run it after `fix` and every behavioural patch is written against the old API, then patched a second time by the migration. |
| 2 | `fix` | Behavioural and security defects, applied to the *migrated* code. Run it before `upgrade` and its regression tests encode the pre-migration signature. |
| 3 | structural owners (`extension-point`, `indexer`, `message-queue`, `webapi`, `graphql`, `admin-form`, `admin-listing`, `system-config`, `data-migration`, `feature`) | New surfaces produce new strings, new templates and new code paths. Running them after `i18n`, `test-generate` or `lint` means those three ran against code that no longer exists. |
| 4 | `frontend` / `breeze-adapt` | Same argument, one layer out: the templates these produce are what `i18n` extracts from and what `a11y` findings were raised against. |
| 5 | `i18n` | Extraction is only complete once **every** user-facing string the run will produce exists. Run it early and the phrases added by batches 3–4 are simply missing from the CSV. |
| 6 | `test-generate` | Tests are written against final code. Run it earlier and it tests an intermediate state, then fails in the same run that produced it. |
| 7 | `lint` | **Last.** It formats everything the run produced and catches style the remediation itself introduced. Run it first and every later batch re-dirties what it just fixed. A Critical `lint` finding still runs last — severity sets order *within* a batch, never between batches. |
| 8 | `docs` | Regenerates module documentation from the finished code, picking up what the run changed. |

An owner the list does not name is a structural owner (position 3): specialist work that
should neither jump ahead of `upgrade` nor trail behind `lint`.

## Presenting a batch

One message, then **one approval**. It carries:

- the batch sequence, the owner skill, and the gate (`auto` / `batch` / `manual`);
- per finding: severity, title, `file:line` evidence, fingerprint (short form is enough), and
  a one-line **drafted intent** taken from the finding's `recommendation`;
- the `verification` that will decide whether each finding closed;
- any `gate: manual` item, called out as a human action with what the human must actually do;
- what will be committed — one commit per finding.

Do not ask per finding, and do not re-present the same batch after a partial failure. The
approval covers the batch as presented; a finding that turns out to need more than its
evidence describes is `deferred`, not re-negotiated mid-batch.

An `auto` batch under `--yes-auto` is announced, not asked. A `manual` batch is never
executable, so it is reported rather than gated.

## The per-finding invocation contract

Every invocation carries the **same four things**, because the point of routing is that the
owning skill starts from the diagnosis instead of re-deriving it:

1. the plan (or source report) path and the finding id,
2. the `fingerprint`,
3. the `file:line` evidence and snippet,
4. the `--docs-root` of this run.

| Owner | Invocation |
|---|---|
| `fix` | `fix --from-finding=<plan.json>#<finding-id> --docs-root=<root>` — see `fix/references/from-finding.md`. Its RCA gate is delegated **upward** to the batch gate; it does not re-prompt. |
| `upgrade` | The upgrade skill with the finding's target version constraint and evidence. |
| `lint` | The lint skill scoped to the finding's file (`auto` gate; safe auto-fixes only). |
| `extension-point`, `indexer`, `message-queue`, `webapi`, `graphql`, `admin-form`, `admin-listing`, `system-config`, `data-migration` | The generator, with the evidence and `recommendation` as its requirement, on the **project** module — never on the file under `vendor/` the finding points at. |
| `frontend`, `breeze-adapt` | The frontend owner with the template/asset evidence; `breeze-adapt` builds the companion module and never edits the target. |
| `i18n`, `test-generate`, `docs` | Scoped to the module the run touched, once, at their batch position. |
| `inline` | No sub-skill owns it: a metadata or packaging edit this skill makes directly, under the same commit rule. |
| `none` / `unrouted` | Not executable. Reported, never executed. |

A vendor-path finding is **never** patched in place. The remediation is a plugin, observer or
preference in a project module, and the commit records which module took it.

## Failure policy

No silent passes. The run records what happened and keeps going.

| Situation | Recorded as | Run continues? |
|---|---|---|
| Change landed, `verification` passed | `closed` | yes |
| Change landed, `verification` failed | `still-open`, with the command and its output | yes — next finding |
| Owning skill ran but produced no change addressing the evidence | `still-open`, with what it reported | yes |
| Finding needs more than its evidence describes | `deferred`, with what it would take | yes — nothing is committed |
| Owning skill unavailable or refuses | whole batch `skipped`, with the reason | yes — next batch |
| `gate: manual` | `pending-manual` | yes — never executed |
| Commit rejected by a hook | Fix the cause, re-stage, commit again with the same message (never `--no-verify`, never amend). Three consecutive failures → `still-open` and move on. | yes |
| Working tree dirty at start | The run does not start | no |

A `skipped` batch is the one outcome that is easy to mistake for success, because nothing
failed — nothing ran. It is never counted clean, and it is reported with the same prominence
as a failure: an absent result is not a result.

`audit --compare` is what proves the outcome. A finding this run called `closed` that still
appears in the closure diff's `still_open` bucket means the verification was too weak, and the
report says so rather than trusting this skill's own bookkeeping.
