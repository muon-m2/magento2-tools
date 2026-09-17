# Report-Driven Entry (`--from-finding`)

How this skill behaves when the defect arrives as a **finding in a report** rather than as a
user's bug description.

```
/fix --from-finding=<report.json>#<finding-id>
```

`<report.json>` is any findings document (`context/references/findings-schema.md`,
`schemaVersion` ≥ 1.1) — a `review`, `security`, `perf-audit` or consolidated
`audit` document, or a `triage` remediation plan. `<finding-id>` is the
finding's `id` within that document.

## Why the ceremony changes

The interactive Phase 1 questions and the Phase 2 live reproduction exist to *produce* a
diagnosis. A finding already carries one:

| Finding field | Replaces |
|---------------|----------|
| `description`, `category`, `severity` | Phase 1's symptom / scope / severity questions |
| `evidence[].file` / `.line` / `.snippet` | Phase 2's "where does it fail" |
| `recommendation` | The Phase 3 proposed-fix sketch |
| `verification` | Phase 2's reproduction check and Phase 4's green condition |
| `fingerprint` | The stable dossier key (see **Dossier** below) |

Re-deriving those by interview is not extra rigour; it is asking the user to retype a document
the toolkit produced. What `--from-finding` skips is the *interrogation*. It does not skip any
part of the *discipline*.

## What is NOT relaxed

All of these still apply, exactly as in a user-reported bug fix:

- **TDD red → green → refactor.** The regression test is written first and must fail for the
  right reason before any production code is written.
- **The regression test is mandatory**, with only the two narrow waivers in the skill's Core
  Rules (provably untestable; config/XML validated by XSD instead).
- **Minimal change.** The diff affects only what the finding demands. No surrounding cleanup.
- **Never edit `vendor/`.** A finding in a third-party or core file is fixed by a
  plugin/observer/preference in a project module.
- **Module hygiene** — license headers, bounded composer constraints.
- **Phase 5 review** (`review --diff`) still runs on the patch.
- **No scope expansion.** A finding that turns out to need more than its evidence describes is
  reported, not silently widened.

If you find yourself relaxing one of these because "the report already said so", stop. The
report asserts a defect exists; it does not assert that your patch is correct.

## Phase deltas

### Phase 1 — Collect

Pre-filled from the finding. **Skip the interactive question batch entirely.**

Still pull logs when the finding's category is runtime-class — `controllers`, `cron`, `queue`,
`api`, `graphql-auth`, `n_plus_one`, `slow_query` — because a static finding plus a runtime log
line is a stronger diagnosis than either alone. For a purely static category (`style`, `acl`,
`metadata`, `deprecation`) skip log collection; there is nothing in `var/log` to find.

Write the pre-filled collection notes to the dossier as usual, recording the source report path
and the finding id so the provenance is never lost.

### Phase 2 — Reproduce

The finding's `verification` string and `file:line` evidence **are** the reproduction.

This is not a new concession — the skill's existing Phase 2 already sanctions encoding a defect
as a failing test straight from the stack trace and RCA evidence, and states that *a failing
test is itself a valid reproduction*. `--from-finding` simply starts there.

The **2-attempt live-reproduction rule does not apply** to a statically derived finding. A
`security/csrf` finding at `Controller/Adminhtml/Order/Save.php:47` has no runtime recipe to
attempt; demanding one would produce a spurious "cannot reproduce" for a defect whose evidence
is sitting in the file.

If the finding's `confidence` is **not** `confirmed`, stop and say so. A `candidate` finding is
a regex hit, not a diagnosis: confirm it by reading the evidence before writing any test.
(`triage` holds these in its `verify_first` bucket for exactly this reason and will
not route them into a batch.)

### Phase 3 — Root-Cause Analysis

Still write `rca.md`. The finding says *what* is wrong; the RCA must still establish *why* —
the divergence point, the history, the intended behaviour. A finding's `recommendation` is an
input to the RCA, never a substitute for it.

**The approval gate moves, it does not vanish:**

| Invoked | Gate |
|---------|------|
| Standalone (`/fix --from-finding=…`) | Unchanged — present the RCA and wait for explicit approval. |
| By `remediate` | Delegated upward. The RCA is drafted and included in the batch presentation; `remediate` takes **one** approval for the whole batch, then this skill proceeds without re-prompting per finding. |

This mirrors the carve-out `review` already documents: *when invoked from another
skill, return to the caller instead of routing; the caller owns remediation.* The user still
approves before any production code changes — once per batch instead of once per finding.

### Phases 4–7 — unchanged

Patch + regression test (TDD), review, optional deploy, report. No deltas.

Phase 7's report additionally records the finding `fingerprint` and the source report path, so
the closure diff (`audit --compare`) can attribute the fix.

## Dossier

```
{output_root}/bug-fixes/{fingerprint-short}/      # first 12 hex chars of the fingerprint
├── collect.md
├── reproduction.md
├── rca.md
└── report.md
```

Keyed on the fingerprint rather than a symptom slug so that:

- the same finding re-attempted in a later run **appends to one dossier** instead of forking a
  near-duplicate directory;
- the dossier is discoverable from the report and from the closure diff, both of which key on
  the same value.

A user-described bug (no `--from-finding`) keeps the existing `{slug}` dossier naming.

## Commit

Unchanged `[bug-fix]` format (`references/commit-format.md`), with one added trailer so the
commit is attributable to the finding it closes:

```
[bug-fix] {Module}: {finding title}

RCA: {output_root}/bug-fixes/{fingerprint-short}/rca.md
Finding: {report path}#{finding-id}
Files: {list}

Closes-Finding: {fingerprint}
```

## Related

- `context/references/findings-schema.md` — the finding object this flag consumes.
- `context/references/fix-routing.md` — which findings route here at all.
- `triage` — turns a whole report into an ordered plan of such invocations.
- `remediate` — executes that plan and owns the batch approval gate.
