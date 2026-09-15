# Diff Mode

Diff mode scopes the review to files changed in a module since a given git ref. Useful
when the full module has already been reviewed and the user wants a focused check on
recent edits, or when invoked from `feature` / `fix` /
`upgrade` after a code change.

## When to Use

- After the user has applied a fix and wants to verify only the changed files.
- When reviewing a long-lived module where a full-module pass would dwarf the actual diff.
- In CI on a pull-request branch: review only the files touched in the PR.
- When `feature-implement` runs `R*` review tasks after a task completes — the diff is
  exactly what that task produced.

## Invocation

```
/review --diff [<ref>] <module-path>
```

Default ref: `origin/main` (falls back to `HEAD~` if origin/main is missing).

Other examples:

```
/review --diff HEAD~5 src/app/code/Acme/OrderS3Export
/review --diff main src/app/code/Acme/Catalog
```

## Workflow Overrides for Diff Mode

| Step             | Override                                                                                 |
|------------------|------------------------------------------------------------------------------------------|
| Scope (step 1)   | Run `${CLAUDE_SKILL_DIR}/scripts/diff-scope.sh <module-path> <ref>` to get the file list |
| Architecture map | Build only for files in the diff (skip whole-module mapping)                             |
| Tool passes      | Run PHPCS/PHPMD/PHPStan only on changed files (use the file list)                        |
| Checklist tiers  | Only checklist items touching changed files apply                                        |
| Findings         | Restricted to changed files; cross-file findings are noted with "diff"                   |
| Report mode      | Report scope reads "Diff against `<ref>` — N files"                                      |
| JSON `mode`      | Set to `"diff"` and include `"diffRef": "<ref>"` in the `target` block                   |

## Detection Rules

A "changed file" is any file inside `<module-path>` that differs between the point the branch
left `<ref>` and the **working tree** — committed, staged, unstaged, or untracked and not ignored:

```bash
BASE="$(git merge-base <ref> HEAD)"
git diff --name-only --diff-filter=ACMR "$BASE" -- <module-path>            # committed + uncommitted
git ls-files --others --exclude-standard --full-name -- <module-path>   # untracked
```

Uncommitted work is in scope on purpose. `feature` runs its `R*` reviews immediately after each
task, with per-task commits off by default, so the previous commits-only rule
(`git diff <ref>...HEAD`) saw none of the work under review and short-circuited with "nothing to
review". On a clean tree — CI, a pull request — both rules produce the same list.

Renames are followed (the new path is reviewed, the old path is noted in the finding's history).

Deleted files (`D`) are not reviewed — they cannot have findings — but the deletion is
listed in the report's "Removed files" section. If a critical file like `registration.php`
or `etc/module.xml` was deleted, raise a Critical finding.

## Cross-File Findings

A finding that depends on a file outside the diff (e.g. a missing dependency declaration
in `etc/module.xml` discovered by a changed controller) must be reported with both files
cited and a `crossFile: true` flag. The report explains that the second file is outside
the diff scope but affects the finding.

## Limitations

- Diff mode does not catch architectural drift introduced earlier; pair it with periodic
  full reviews.
- Diff mode does not lower severity. A Critical finding stays Critical even when the
  change is small.
- Diff mode can produce empty reports if the changed files are pure config or comments
  — the report is still emitted with a "No issues in diff" status.

## Tooling

- `${CLAUDE_SKILL_DIR}/scripts/diff-scope.sh` — emits the file list.
- The script falls back to `HEAD~` if the requested ref is missing.
- The script returns non-zero (exit 1) when no files in the module changed; the calling
  skill should short-circuit with "no findings — nothing to review."
