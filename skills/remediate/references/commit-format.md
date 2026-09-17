# Remediation Commit Format

One finding, one commit. That is the whole rule, and it is what makes a remediation run
reviewable: a reviewer can read the history and see exactly which change was made because of
which finding, and revert one without unpicking the rest.

```
[remediate] {Module}: {finding title}

Finding: {fingerprint}
Plan: {output_root}/remediation/{Module}-plan-{date}.md
Owner: {owning skill}
Files: {comma-separated list}

Closes-Finding: {fingerprint}

Co-Authored-By: {current Claude model, per the harness convention} <noreply@anthropic.com>
```

- `Finding:` is the full 64-char fingerprint; the short form is only ever for display.
- `Owner:` is the skill from the plan that actually executed the change, so a bad routing
  decision is visible in history rather than only in the plan.
- `Closes-Finding:` is a **trailer** (last block, no blank line inside it). `audit --compare`
  and any `git log --grep` attribution key on it, which is why it repeats the fingerprint
  rather than pointing at the `Finding:` header.

Do not hard-code a skill version or a fixed model name — both drift. Use the co-author line
the harness specifies for the active model, the same rule as
`fix/references/commit-format.md`.

## Who makes the commit

This skill owns the commit boundary: an owning skill invoked from a batch leaves its change in
the working tree and this skill commits it.

**One exception, by design:** a skill that already commits per finding under its own
convention keeps it. `fix --from-finding=` makes a `[bug-fix]` commit that *already*
carries the `Closes-Finding` trailer (`fix/references/from-finding.md`). That commit **is**
the finding's commit. Verify the trailer is present and move on — never re-commit the same
change under a second subject, and never amend the sub-skill's commit to change its prefix.
The prefix records who did the work; the trailer is what carries identity, and it is the
trailer every consumer reads.

## Staging

- Always `git add` explicit paths — never `git add -A` or `git add .`. A remediation run is
  exactly the situation where an unrelated stray file would otherwise be swept in.
- Stage only the files named in the `Files:` line.
- Never stage anything under `vendor/`. If a change landed there, the remediation was done the
  wrong way: revert it and route the finding to `extension-point`.
- The run refuses to start on a dirty tree, so anything in the index at commit time was
  produced by this batch.

## Failure handling

If `git commit` fails (a pre-commit hook rejects it):

1. Read the hook output.
2. Fix the cause — typically a style violation on the patched file.
3. Re-stage the corrected paths and commit again **with the same message**.
4. Never `--no-verify`, never `--no-gpg-sign`, never amend a prior commit.
5. After three consecutive failures, record the finding as `still-open` with the hook output
   and move to the next finding. A change that cannot be committed has not been made.

## Multi-module findings

If closing one finding requires touching two modules — a plugin in a project module against a
class in another — it is still **one** commit: one finding, one fingerprint, one revert. List
both modules in the subject as `{ModuleA}+{ModuleB}` and every path in `Files:`.

## Branch and hand-off

Commits land on `remediation/{slug}`. This skill does not push, open a pull request, or merge.
The branch, its per-finding history and the run report are handed back for review — the
closure diff says what actually closed, and that is a reviewer's decision to act on, not this
skill's.
