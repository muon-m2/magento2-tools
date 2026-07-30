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

The pass also runs the **surface-invariant** rules (`category: surface`) — cross-file
completeness checks that need no external tool, so they run even where phpcs/phpstan are
absent. They catch the class of defect the tool-driven scanners structurally cannot: a surface
whose files are each individually valid but incomplete as a set (a queue topic with no
publisher, a grid collection without the SearchResult bridge, an ACL id re-declared under the
wrong parent — an admin lockout). Every rule came from a real bug report; see
`references/surface-invariants.md`. None of them are auto-fixable — each needs a decision about
which file to add or which type to change.

Present the fix plan to the user showing:

- Total violations found per tool
- Which violations are **auto-fixable** (phpcbf, php-cs-fixer, safe rector rules)
- Which violations are **manual-only** (phpstan level errors, phpmd, risky rector, and every
  `surface` finding)
- Estimated residual count after auto-fix
- Any `scanner_errors` entry — a scanner that degraded checked **nothing**, which is not the
  same as finding nothing. Surface rules that could not be decided report there by name.

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
   Run `build-findings.sh` with `DOCS_ROOT=<output_root>` (the resolved `--docs-root`
   value, or `.docs` by default) so both artifacts land under `{output_root}/quality/`.

## Reference Files

- `references/tool-matrix.md` — which tool detects vs fixes what; run command for each.
- `references/surface-invariants.md` — the cross-file completeness rule pack (SI-01…SI-12): what
  each rule asserts, the bug report it came from, and the two false-positive classes to avoid
  when adding one.
- `references/autofix-safety.md` — safe vs review-required transforms.
- `references/ci-integration.md` — running as a CI gate; SARIF upload; `--diff` PR gating.
- `magento2-context/references/findings-schema.md` — finding shape, `outputKind=quality`.
- `magento2-context/references/severity.md` — shared severity scale.
- `magento2-context/references/php-coding-style.md` — the Magento2 coding standard rules.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/run-analysis.sh` — orchestrates read-only tool passes;
  outputs findings JSON array.
- `${CLAUDE_SKILL_DIR}/scripts/surface-invariants.sh` — the tool-free cross-file completeness
  rules; module scope only (each rule reasons about one module's file set, so a site/diff run
  must invoke it per changed module). Run by `run-analysis.sh`; standalone-callable.
- `${CLAUDE_SKILL_DIR}/scripts/apply-fixes.sh` — runs safe fixers (phpcbf, php-cs-fixer
  only); never touches `vendor/`. Rector is never auto-applied.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — assembles residual findings into the
  shared JSON+SARIF format using the `emit-findings.sh` pipeline (emit-json.sh /
  emit-sarif.sh) owned by the `magento2-context` hub.

## Inputs

```
/magento2-static-analysis [--module=<Vendor>_<Module>] [--diff [<ref>]] [--scope=module|site] [--docs-root=<path>] [<files>...]
```

### Tool environment

| Var | Purpose |
|-----|---------|
| `PHPSTAN_CONFIG` | Config passed as `-c`. Auto-discovered nearest-first: `{TARGET_PATH}/phpstan.neon`, then `phpstan-devpath.neon`/`phpstan.neon` beside the target's parent, then the Magento root, then the cwd. **Without a config phpstan loads no bootstrap and no autoloader**, so every framework class reads as unknown — the pass then emits confident false positives that are indistinguishable from real ones. When nothing is found the run still happens, with a warning in `scanner_errors`. |
| `PHPSTAN_MEMORY_LIMIT` | Default `2G`. php.ini's usual 128M makes phpstan crash on a Magento codebase and return an empty, apparently-clean result. |
| `RECTOR_FORCE` | `1` runs rector even on a pairing known to be broken. |

**Rector 1.x is skipped on PHP ≥ 8.5.** It emits `ReflectionProperty::setAccessible()` deprecations
plus a stack trace for essentially every rule — measured at 495 MB of stderr on one module — and
never emits parseable JSON, so the pass contributes nothing while appearing to have run. Rector
**^2.5 runs clean on 8.5** (verified: valid JSON, zero bytes of stderr) and is *not* skipped, so the
guard is on the pairing rather than the PHP version. Note that adopting Rector 2.x requires
`phpstan/phpstan ^2.2`, so it implies the PHPStan 2.x migration — not a standalone bump.

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

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, run the emitter with
`DOCS_ROOT=<path>` so artifacts land under `<path>/quality/`; otherwise they default
to `{ctx.docs_root}/quality/`. Orchestrators such as `magento2-feature-implement`
pass this to collect a run's artifacts under one folder.

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `magento2-module-review` | Architecture/quality review WITHOUT fixing — use when you want findings, not fixes |
| `magento2-context` | Supplies `{ctx.tools}`, `{ctx.runner}`, `{ctx.magento_root}` |
| `magento2-bug-fix` | For defects found during analysis that require RCA rather than a style fix |
| `magento2-security-audit` | Deeper security scan beyond coding-standard enforcement |
