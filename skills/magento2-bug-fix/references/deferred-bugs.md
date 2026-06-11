# Deferred Bugs

When RCA or Phase 4 surfaces additional bugs beyond the one being fixed, defer them
rather than expanding scope.

## Rules

1. **The current fix addresses exactly one reproducible bug.** If a second symptom is
   discovered during investigation, capture it as a "deferred bug" and continue with the
   original.
2. **Document deferred bugs in the RCA's "Deferred Issues" section.** Each deferred bug
   gets:
    - One-line symptom
    - File:line where it was noticed
    - Why it's deferred (not in scope of current fix)
3. **After Phase 7, surface deferred bugs to the user.** Offer to start a new
   `/magento2-bug-fix` run for each.

## What Counts as a Deferred Bug

| Discovery                                              | Defer or Include?                              |
|--------------------------------------------------------|------------------------------------------------|
| Same root cause, different symptom                     | Include (it's the same bug)                    |
| Different root cause in the same method                | Defer (would expand scope)                     |
| Code smell in surrounding code                         | Defer (not a bug — file as refactor task)      |
| Missing test for adjacent method                       | Defer (not a bug — file as test-generate task) |
| Failing assertion in unrelated test broken by your fix | Include (you caused it; you fix it)            |
| Pre-existing failing test in another file              | Defer (not yours)                              |

## Example RCA Deferred Section

```markdown
## Deferred Issues

1. **Missing null-check in `OrderRepository::getById()` for soft-deleted orders.**
   Noticed at `Model/OrderRepository.php:127`. Different code path; would expand
   current fix scope. Recommended next step: `/magento2-bug-fix "OrderRepository
   returns ghost orders for soft-deleted IDs"`.

2. **Plugin sortOrder collision between Acme_OrderExport and Acme_OrderArchive.**
   Noticed in `etc/di.xml`. This is a configuration issue, not a code defect.
   Recommended next step: file as a refactor task, not a bug fix.
```

## When to Break the Rule

If two bugs share a root cause that you only discover during Phase 4, it is acceptable
to fix both in one commit — but only if:

- The combined fix is still minimal (< 5 files).
- The combined regression test covers both symptoms.
- You note the bundling explicitly in the RCA and the final report.

If you discover that "fixing bug A also fixes bug B" mid-Phase 4, update the RCA, get
user re-approval for the expanded scope, then proceed.
