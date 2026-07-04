---
name: magento2-static-analysis
description:
    Run the project's full static-analysis gate (phpcs Magento2, phpstan, phpmd,
    php-cs-fixer, rector dry-run) over a module or diff and apply safe auto-fixes to
    green, listing manual-only violations as ranked findings (Markdown + JSON + SARIF).
    Use for 'fix coding-standard violations' / 'make this pass CI'. For an
    architecture/quality review WITHOUT fixing, use `magento2-module-review`.
---

# Magento 2 Static Analysis

Action skill — runs the project's static-analysis toolchain, applies safe auto-fixes,
and reports residual violations as ranked findings. Unlike `magento2-module-review`
(read-only, architecture-focused), this skill **modifies files** to green the CI gate.

## Core Rules

- **Probe tools via `{ctx.tools}`.** Skip any tool not present. NEVER install anything.
- **Fixers run ONLY after the Phase-2 approval gate.** No file is touched until the user
  explicitly types "proceed" (or an equivalent confirmation).
- **Safe transforms only.** `phpcbf` and `php-cs-fixer` are the only auto-applied fixers.
  They are purely mechanical and cannot change observable behaviour.
- **Rector is PROPOSED, not auto-applied.** Rector runs in `--dry-run` mode during Phase 2
  (detection only). Its findings are listed for manual review; the skill never applies rector
  transforms automatically. The developer applies any desired rector changes manually after
  reviewing the proposals.
- **Re-run after fixing.** After applying fixes, the analysis gate re-runs and reports
  the residual (manual-only) violations.
- **NEVER edit `vendor/`.** All fixers exclude the `vendor/` directory unconditionally.
- **Severity shared scale.** See `magento2-context/references/severity.md`.
- **Findings schema shared.** See `magento2-context/references/findings-schema.md`
  (`outputKind = quality`).
- **Coding standard.** The enforcement gate is `--standard=Magento2` phpcs. See
  `magento2-context/references/php-coding-style.md` for the full style rules.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx}` — especially `{ctx.tools}` (which tools are
available) and `{ctx.runner}` (Docker vs bare PHP prefix). Abort with a clear error if
no PHP environment is found (`runner_kind` is `null`).

### Phase 1 — Scope

Determine which files to analyse. Three modes:

| Mode | Trigger |
|------|---------|
| Module | `--module=Acme_OrderExport` or a bare module name / path |
| Diff | `--diff [<ref>]` (default `origin/main`) — analyse only changed files |
| Explicit files | One or more file paths passed directly |

For module scope, resolve the absolute path via `{ctx.magento_root}/app/code/{Vendor}/{Module}`.
Exclude `vendor/`, `generated/`, `var/`, `pub/static/` unconditionally.

### Phase 2 — Analysis Pass + Fix Plan (GATE)

Run every available tool in **read-only / dry-run mode** using
`${CLAUDE_SKILL_DIR}/scripts/run-analysis.sh`. Aggregate violations into a findings
JSON array.

Present the fix plan to the user showing:

- Total violations found per tool
- Which violations are **auto-fixable** (phpcbf, php-cs-fixer, safe rector rules)
- Which violations are **manual-only** (phpstan level errors, phpmd, risky rector)
- Estimated residual count after auto-fix

**WAIT for the user to type "proceed" before changing any file.** This gate is
mandatory. A write skill that touches files without explicit approval is a defect.

### Phase 3 — Apply Safe Fixes

Run `${CLAUDE_SKILL_DIR}/scripts/apply-fixes.sh` with the approved scope. The script:

1. Runs `phpcbf --standard=Magento2` over the scope (auto-fixes PHPCS style violations).
2. Runs `php-cs-fixer fix` with safe rules if the tool is available.
3. Captures before/after violation counts.
4. Never touches files outside the approved scope; never touches `vendor/`.

Rector is NOT run by apply-fixes.sh. Rector proposals from Phase 2 are manual-only;
the developer applies them after reviewing each proposed transform.

### Phase 4 — Verify

Re-run `${CLAUDE_SKILL_DIR}/scripts/run-analysis.sh` on the same scope. Report:

- Residual violation count (manual-only findings that remain after auto-fix)
- Delta: violations resolved by auto-fix vs still open
- Confirmation that no new violations were introduced by the fixers
- Confirmation that `vendor/` was not touched

### Phase 5 — Report

Write three artifacts:

1. **Markdown** — narrative report saved to
   `{output_root}/quality/{Vendor}_{Module}-quality-{YYYY-MM-DD}.md` (module scope;
   site/diff scope: `quality-{scope}-{YYYY-MM-DD}.md`). Sections: scope summary,
   auto-fix summary (before/after counts), residual findings by severity/tool, proposed
   risky rector rules (manual action needed), skipped tools.
2. **JSON + SARIF** — built by `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` using
   `OUTPUT_KIND=quality`. Residual findings only (auto-fixed violations are excluded).

## Reference Files

- `references/tool-matrix.md` — which tool detects vs fixes what; run command for each.
- `references/autofix-safety.md` — safe vs review-required transforms.
- `references/ci-integration.md` — running as a CI gate; SARIF upload; `--diff` PR gating.
- `magento2-context/references/findings-schema.md` — finding shape, `outputKind=quality`.
- `magento2-context/references/severity.md` — shared severity scale.
- `magento2-context/references/php-coding-style.md` — the Magento2 coding standard rules.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/run-analysis.sh` — orchestrates read-only tool passes;
  outputs findings JSON array.
- `${CLAUDE_SKILL_DIR}/scripts/apply-fixes.sh` — runs safe fixers (phpcbf, php-cs-fixer
  only); never touches `vendor/`. Rector is never auto-applied.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — assembles residual findings into the
  shared JSON+SARIF format using the `emit-json.sh` / `emit-sarif.sh` emitters owned by
  `magento2-module-review`.

## Inputs

```
/magento2-static-analysis [--module=<Vendor>_<Module>] [--diff [<ref>]] [--scope=module|site] [<files>...]
```

## Outputs

Module scope (basename uses the underscore module name, e.g. `Acme_OrderExport`):
```
{output_root}/quality/{Vendor}_{Module}-quality-{date}.md    # Markdown narrative (LLM, Phase 5)
{output_root}/quality/{Vendor}_{Module}-quality-{date}.json  # JSON findings (build-findings.sh)
{output_root}/quality/{Vendor}_{Module}-quality-{date}.sarif # SARIF (build-findings.sh)
```
Site/diff scope:
```
{output_root}/quality/quality-{scope}-{date}.md
{output_root}/quality/quality-{scope}-{date}.json
{output_root}/quality/quality-{scope}-{date}.sarif
```
`{output_root}` defaults to `.docs` (`{ctx.docs_root}`); see the `--docs-root`/`DOCS_ROOT`
recipe in `magento2-context/references/artifact-layout.md`.

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `magento2-module-review` | Architecture/quality review WITHOUT fixing — use when you want findings, not fixes |
| `magento2-context` | Supplies `{ctx.tools}`, `{ctx.runner}`, `{ctx.magento_root}` |
| `magento2-bug-fix` | For defects found during analysis that require RCA rather than a style fix |
| `magento2-security-audit` | Deeper security scan beyond coding-standard enforcement |
