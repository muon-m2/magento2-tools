# Remediation Report: {Vendor}_{Module}

Date: {YYYY-MM-DD}
Branch: `remediation/{slug}`
Plan: `{path}` (triage, {YYYY-MM-DD})
Baseline report: `{path}`
Closure: `{path}` — or **not verified** (`--no-closure`)

## Run Summary

| Findings in plan | Attempted | Closed | Still open | Deferred | Pending manual | Skipped batches |
|------------------|-----------|--------|------------|----------|----------------|-----------------|
| {N}              | {N}       | {N}    | {N}        | {N}      | {N}            | {N}             |

{One paragraph: what this run set out to close and what it actually closed. If any batch was
skipped or any verification failed, say so here — not only in the table below.}

## Batches

| # | Owner | Gate | Attempted | Closed | Still open | Deferred | Outcome |
|---|-------|------|-----------|--------|------------|----------|---------|
| 1 | {owning skill} | {auto \| batch \| manual} | {N} | {N} | {N} | {N} | {executed \| skipped: reason} |

A `skipped` batch is not a pass. Name the reason its owner was unavailable and what stays open
because of it.

### Batch {N} — {owning skill}

| Severity | Finding | Evidence | Outcome | Commit |
|----------|---------|----------|---------|--------|
| {Severity} | {Title} | `{file}` | {closed \| still-open \| deferred} | `{SHA1}` |

Verification run: `{verification command}` → {pass | fail}.

## Still Open

Findings this run attempted and did **not** close. Each records the attempt, not just the
failure.

| Finding | Owner | Why it is still open | Attempt |
|---------|-------|----------------------|---------|
| {Title} | {owning skill} | {reason} | `{SHA1}` or "no change committed" |

## Deferred

Findings that turned out to need more than their evidence describes. Scope is the finding, so
nothing was expanded into — each entry says what closing it would actually take.

| Finding | Evidence | What it would take |
|---------|----------|--------------------|
| {Title} | `{file}` | {description} |

## Human Action Items

**These were never executed and never will be by this skill.** Credential rotations first —
deleting the line that printed a secret does not un-leak it.

1. **{Title}** — `{file}`
   Fingerprint: `{fingerprint}`
   Action: {description}
   Owner: {who must do it}
   Until this is done, the finding stays open in every closure diff, tagged `pending-manual`.

## Closure Diff

`audit --compare` against the baseline: `{path}`

| Bucket | Count | Notes |
|--------|-------|-------|
| closed | {N} | Present in the baseline, absent now. |
| still_open | {N} | Includes every `pending-manual` item above. |
| waived | {N} | Suppressed by `waivers.yml`; never counted closed. |
| regressed | {N} | **Introduced by this run.** |
| skipped | {N} | Dimension could not be re-run — never counted closed. |

Verdict: {From} → {To}. Score: {From} → {To}.

{If `regressed` is non-empty, list every regression in full here with its evidence. A run that
introduced a finding says so before it reports what it closed.}

## Residual Risk

{What is still wrong after this run, in plain terms: the still-open findings, the deferred
ones, the human actions nobody has taken yet, and anything a skipped batch left unexamined.
State plainly whether the module is in a better or merely different state.}

## Next Steps

1. Review `remediation/{slug}` — one commit per finding, each with its `Closes-Finding` trailer.
2. {Re-run the skipped batch once its owner is available / re-run `triage` if routing was wrong.}
3. Action the items under **Human Action Items**, then re-run `audit --compare` to confirm.
