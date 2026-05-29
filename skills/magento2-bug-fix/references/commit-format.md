# Bug-Fix Commit Format

Every code-modifying phase makes a focused git commit. Format:

```
[bug-fix] {Module}: {symptom}

RCA: .docs/bug-fixes/{slug}/rca.md
Files: {comma-separated list}
Severity: {critical|high|medium|low}

Co-Authored-By: {current Claude model, per the harness convention} <noreply@anthropic.com>
```

Do not hard-code skill version numbers or a fixed model name in commits — both drift.
Use the co-author line the harness specifies for the active model, and let traceability
come from the `RCA:` path rather than a `Skill versions:` line.

## Examples

### Patch commit (Phase 4)

```
[bug-fix] Acme_OrderS3Export: Cron job swallows S3 upload exceptions

RCA: .docs/bug-fixes/2026-05-24-s3-upload-swallow/rca.md
Files: Cron/UploadOrders.php, Test/Unit/Cron/UploadOrdersTest.php
Severity: high
```

### Review-fix commit (Phase 5)

```
[bug-fix] Acme_OrderS3Export: review fix - missing @throws on uploadOrder()

RCA: .docs/bug-fixes/2026-05-24-s3-upload-swallow/rca.md
Files: Cron/UploadOrders.php
Severity: high
```

## Staging Rules

- Always `git add` specific paths. Never `git add -A` or `git add .`.
- Stage only the files listed in `Files:` line.
- If you need to commit a generated file (e.g. updated test expectation), include it
  explicitly and note it in the commit message.

## Failure Handling

If `git commit` fails (pre-commit hook rejects):

1. Read the hook output.
2. Fix the cause (typically: PHPCS style violation on the patched file).
3. Re-stage the corrected files.
4. Commit again with the same message — **do NOT** amend a prior commit.
5. After 3 consecutive failures, abort the task and report.

Never use `--no-verify` or `--no-gpg-sign` unless the user explicitly authorizes.

## Pre-Push Reminder

This skill does NOT push to a remote. After Phase 7, ask the user before any push or PR
creation. The fix may need rebasing, squashing, or review before it leaves the local
branch.

## Multi-Module Fixes

If the fix spans multiple modules, make one commit per module — same RCA reference,
different `Module:` and `Files:` lines. This keeps commit blast radius minimal and makes
selective reverting easier if the fix proves wrong.
