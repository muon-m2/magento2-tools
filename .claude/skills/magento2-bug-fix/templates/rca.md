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

{Plain English description.}

## Why (History)

Last touched: `{commit SHA}` ({YYYY-MM-DD}) by {author}
Original intent: {what the original commit was trying to accomplish}
What changed since then: {if applicable}

## Proposed Fix

{One paragraph describing the minimal change. Behaviour, not code.}

Files to modify:
- `{file1}` — {one-line reason}
- `{file2}` — {one-line reason}

Scope discipline check:
- [ ] Change touches only files listed above
- [ ] No surrounding cleanup
- [ ] No refactor for testability beyond the regression test
- [ ] No new features

## Regression Test Plan

Test class: `Test/Unit/{...}Test.php`
Test method: `test{Behaviour}()`
Pre-fix expectation: failing assertion `{description}`
Post-fix expectation: passing assertion `{description}`

## Severity

{critical | high | medium | low} — {1-sentence justification}

## Deferred Issues

{Bullet list of bugs noticed during investigation that are NOT in scope of this fix.}

## Open Questions (Optional)

{If any question blocks the fix, list here.}
