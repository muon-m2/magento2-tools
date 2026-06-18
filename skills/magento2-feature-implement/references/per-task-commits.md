# Per-Task Git Commits

Phase 5 optionally creates one git commit per completed task. Off by default to preserve
existing workflows where users prefer a single end-of-feature commit; opt in via:

- CLI flag: `--per-task-commits`
- CLAUDE.md: `Feature implement: per-task commits = on`
- Env var: `MAGENTO2_FI_PER_TASK_COMMITS=1`

When ANY of the three is set, per-task commits are on.

## Commit Format

Follow the shared rule in `magento2-bug-fix/references/commit-format.md`: **do not hard-code
skill version numbers or a fixed model name in a commit message** — both drift. Skill
versions are recorded in the feature's saved artefacts (`plan.md`, `report.md`), not in
commits; the commit lists the contributing skill *names* only. Use the co-author line the
harness specifies for the active model.

```
[feature-implement] {TaskID} {Task title}

Module(s): {Vendor}_{ModuleA}, {Vendor}_{ModuleB}
Feature: {FeatureName}
Contributing skills: magento2-feature-implement, magento2-module-create

{Optional 1-2 sentence task summary}
```

Examples:

```
[feature-implement] M1 Create OrderS3Export module

Module(s): Acme_OrderS3Export
Feature: OrderS3Export
Contributing skills: magento2-feature-implement, magento2-module-create

Initial module scaffold with persistence + service_contracts + cron surfaces.
```

```
[feature-implement] R1 Review OrderS3Export module

Module(s): Acme_OrderS3Export
Feature: OrderS3Export
Contributing skills: magento2-feature-implement, magento2-module-review

Fixed 2 High findings (CSRF on admin POST, missing ACL on cron config).
Logged 3 Medium findings.
```

## Hotfix Mode

In hotfix mode the prefix is `[hotfix]` and there is one commit:

```
[hotfix] {Short description}

Module(s): {Vendor}_{Module}
Contributing skills: magento2-feature-implement
Files: Controller/Order/Save.php, etc/di.xml
```

## What Gets Committed Per Task

| Task type | Files included in the commit                            |
|-----------|---------------------------------------------------------|
| M*        | The new module's full directory tree                    |
| X*        | The specific files modified in that task                |
| R*        | The fix files (after Critical/High remediation)         |
| T*        | The Test/Unit/* files added in that task                |
| V*        | No commit (V* runs static checks; no files change)      |
| D*        | No commit (D* runs deploy; no files change)             |

Only files actually touched by the task are staged — `git add` always uses explicit
paths, never `git add -A` or `git add .`. This avoids accidentally committing unrelated
changes the user may have made.

## Failure Handling

If a commit fails (pre-commit hook rejects), do NOT amend or skip hooks. Instead:

1. Log the hook output.
2. Address the cause (typically: code-style failure on a generated file).
3. Re-stage the corrected files.
4. Commit again with the same message.

If three commit attempts fail in a row, abort the task and report. Do not silently skip.

## Sign-off

If `git config user.signingkey` is set AND `git config commit.gpgsign` is true, the
commit is signed. Otherwise it is unsigned. The skill never overrides the user's signing
configuration.

## Co-authored Trailer

Include the standard trailer at the end of every per-task commit:

```
Co-Authored-By: {current Claude model, per the harness convention} <noreply@anthropic.com>
```

Do **not** hard-code a fixed model name here — use the co-author line the harness specifies
for the active model (see the rule above and `magento2-bug-fix/references/commit-format.md`).

## Plan.md Synchronization

After each successful commit, update `plan.md`:
- Mark the task's checkbox `[x]`.
- Append the commit SHA in parentheses: `- [x] M1: Create OrderS3Export module (abc1234)`.

This keeps the plan auditable as a one-to-one map between tasks and commits.

## Off Mode (default)

When per-task commits are off, Phase 5 makes no commits. The user is responsible for
committing at their own cadence. Phase 7 (final report) still references the implemented
files but does not assume any git state.
