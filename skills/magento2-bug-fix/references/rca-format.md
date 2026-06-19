# Root Cause Analysis Document Format

The RCA is the approval-gate artefact. It must be complete enough that the user can
approve or redirect without re-reading source code.

## Required Sections

```markdown
# RCA: {Symptom one-liner}

Bug ID: {slug}
Date: {YYYY-MM-DD}

## Symptom

{2-4 sentences: what the user sees, what triggers it, why it matters.}

## Reproduction

Recipe: `.docs/bug-fixes/{slug}/reproduction.md`
Trigger frequency: {deterministic | N in M}

## Stack Trace Summary

Top frame: `{file}:{line}` in `{Class}::{method}()`
First project-owned frame: `{file}:{line}`

## Defect Location

`{file}:{line}` in `{Class}::{method}()`

## What's Wrong

{Plain English: what the code does, what it should do, why the divergence matters.}

## Why (History)

Last touched: `{commit SHA}` ({YYYY-MM-DD}) by {author}
Original intent: {what the original commit was trying to accomplish}
What changed since then: {if applicable: the surrounding context that broke the assumption}

## Proposed Fix

{One paragraph describing the minimal change. Do NOT include code yet — describe the
behaviour change.}

Files to modify:
- `{file1}` — {one-line reason}
- `{file2}` — {one-line reason}

Scope discipline check:
- [ ] Change touches only files listed above
- [ ] No surrounding cleanup
- [ ] No refactor for testability beyond the regression test
- [ ] No new features

## Regression Test Plan

Test class: `Test/Unit/{...}Test.php` (or `Test/Integration/{...}Test.php`)
Test method: `test{Behaviour}()`
Pre-fix expectation: failing assertion `{description}`
Post-fix expectation: passing assertion `{description}`

## Severity

{critical | high | medium | low} — {1-sentence justification per bug-fix SKILL.md
classification table.}

These four levels ARE the shared 5-level scale (`magento2-context/references/severity.md`)
minus `info`: a defect is never `info`, so bug-fix omits that level. `critical`, `high`,
`medium`, and `low` carry exactly the same meaning as in the shared scale, so findings cross
between skills without re-grading.

## Deferred Issues

{If the investigation surfaced additional bugs: list them here. Do not fold into this
fix — they become separate `/magento2-bug-fix` runs.}

## Open Questions (Optional)

{If any question blocks the fix, list here. The user must answer before approval can
proceed.}
```

## Explorer Assist

During RCA investigation, the `magento2-explorer` agent can be dispatched to map the suspect
execution path — tracing the call chain from entry point through plugins, observers, and
preferences — so the defect location can be pinpointed without manually reading every interceptor.

## Quality Bar

The RCA is approved only when:

- Defect location cites a specific `file:line`, not "somewhere in this module."
- "What's wrong" is comprehensible to a human who has not read the source.
- "Why" includes git history evidence (at least the last-touched commit).
- Proposed fix is bounded — the scope-discipline checklist is fully checked.
- Severity matches the impact described in "Symptom."
- Regression test plan is specific enough that Phase 4 can write the test without
  re-investigating.

If any of these is missing, do NOT present the RCA — complete it first. Wasting an
approval cycle on an incomplete RCA frustrates the user and delays the fix.

## What NOT to Include

- Speculation. If you're not sure why the line is wrong, do more investigation.
- Multiple proposed fixes. Pick one. List alternatives in a "Considered alternatives"
  appendix only if the user asks.
- Implementation code. Phase 4 writes the code; Phase 3 stays at the design level.
- Praise or blame for prior commits. The RCA is technical, not interpersonal.

## Approval

The user replies with "proceed", "yes", "approved", or "go" — Phase 4 begins.
The user replies with anything else — interpret as a question or revision request;
update the RCA and re-present.
