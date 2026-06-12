---
name: magento2-module-upgrade
description:
    Upgrade an existing Magento 2 module to a newer Magento version, newer PHP version,
    or newer framework dependency. Use when the user wants to bump Magento support,
    update PHP constraints, replace deprecated API usage, or scan for and remediate BC
    breaks. Drives: deprecation scan → BC-break detection → patch generation → review →
    test → report. Calls magento2-module-review (diff mode) and magento2-test-generate.
---

# Magento 2 Module Upgrade

Bring an existing module up to a newer Magento or PHP target. The change list is
**derived** (from scans), not user-described.

## Core Rules

- **Target before scan.** Always resolve the upgrade target in Phase 1; never scan
  without a concrete target.
- **Auto-fix only known-safe Rector rules.** Manual approval required for non-trivial
  rewrites.
- **BC-breaks are documented, not silently fixed.** A BC-break may break callers; surface
  it in `UPGRADE.md` so the consumer knows.
- **Per-task commits.** Each Rector rule run, each manual edit, each BC-break note is its
  own commit. Reverting one shouldn't lose others.
- **Test before declare-done.** A passing test suite is the gate to Phase 7.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture current Magento + PHP versions, framework constraint,
runner, tools (rector, phpstan, semgrep).

### Phase 1 — Target Resolution

Determine the upgrade target from the user request:

| Phrase | Resolves to |
|--------|-------------|
| "to Magento 2.4.7" | `magento_target=2.4.7`, keep PHP target |
| "to Magento 2.5" | `magento_target=2.5.0`, may force PHP bump |
| "drop PHP 8.1" | `php_min=8.2`, keep Magento target |
| "compatibility scan" | No target; full report on current code |

State the target explicitly. Ask for clarification if multiple targets fit.

### Phase 2 — Scan

Run scanners in order; record what was available and what wasn't.

| Scanner                                                                                 | Purpose                                               |
|-----------------------------------------------------------------------------------------|-------------------------------------------------------|
| Adobe UCT (`vendor/bin/uct upgrade:check`, edition-gated)                               | First-party compatibility scan                        |
| Rector (core `rector/rector` + hand-listed rules)                                       | Identify rewritable deprecations                      |
| `vendor/bin/phpcs --standard=Magento2` (if `magento/magento-coding-standard` installed) | Magento-specific lints                                |
| Custom AST scan (per `references/deprecation-map.md`)                                   | Removed classes/methods per Magento version           |
| Composer constraint scan                                                                | Detect constraints incompatible with target           |
| PHPStan                                                                                 | Errors that surface only at the new PHP/Magento level |

Emit a **scan report**: each finding categorized as:
- `auto-fixable` (Rector can do it)
- `manual-fixable` (needs human/LLM intervention)
- `bc-break` (caller must update; surfaces an API change)

### Phase 3 — Plan (APPROVAL GATE)

Present the scan report grouped by category. Wait for "proceed."

The user can opt into `--include-bc-breaks` if they want the skill to attempt automated
BC-break remediation; default is "report only."

### Phase 4 — Apply

- Auto-fixable: run Rector with the relevant rule set. One commit per rule set applied.
- Manual-fixable: edit each file directly. One commit per logical change.
- BC-break: write a note in `UPGRADE.md` (template at `templates/upgrade-md.md`) and
  skip the code change.

### Phase 5 — Test

1. Run unit tests; fix breaks introduced by changes.
2. If module has no tests: invoke `magento2-test-generate --types=unit` for the changed
   files before applying further changes.
3. Run integration tests if available; fix breaks.
4. If the module declares `webapi.xml` or `schema.graphqls`: run API tests.

### Phase 6 — Review

Invoke `magento2-module-review --diff` against the pre-upgrade ref. Fix Critical/High
findings.

### Phase 7 — Report

Save to `.docs/upgrades/{Vendor}_{Module}-{from}-to-{to}-{date}.md`:
- Scope (versions, modules, scanners run)
- Findings (auto-fixed, manually-fixed, BC-breaks)
- BC-break consumer notice (paste of `UPGRADE.md`)
- Test results
- Recommended next steps

Also emit JSON sibling per the shared findings schema (subset: category =
`deprecation` / `bc_break` / `magento_compat` / `php_compat`).

## Inputs

```
/magento2-module-upgrade --to-magento=2.4.7 --to-php=8.3 <Vendor>_<Module>[,<Module>]
```

Flags:
- `--to-magento=X.Y.Z`
- `--to-php=X.Y`
- `--scan-only` — Phases 0-2 only; no edits.
- `--auto-fix` — Apply Rector without approval (Phase 3 skipped).
- `--include-bc-breaks` — Attempt automated BC-break remediation.

## Outputs

```
.docs/upgrades/{Vendor}_{Module}-{from}-to-{to}-{date}.md
.docs/upgrades/{Vendor}_{Module}-{from}-to-{to}-{date}.json
{ctx.magento_root}/app/code/{Vendor}/{Module}/UPGRADE.md   # Consumer notice (always present after upgrade)
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under `{ctx.magento_root}`,
`app/code`, or a module dir. See the **Artifact location** rule in `magento2-context/SKILL.md`.

## Reference Files

- `references/magento-version-matrix.md` — known BC breaks by Magento version.
- `references/php-version-matrix.md` — known BC breaks by PHP version.
- `references/deprecation-map.md` — deprecated → replacement API mapping.
- `references/rector-rule-sets.md` — Rector sets by Magento version.
- `references/bc-break-notification.md` — how to write UPGRADE.md entries.
- `references/scanner-tools.md` — tool probe catalogue.

## Templates

- `templates/upgrade-md.md` — module-level UPGRADE.md
- `templates/report.md` — upgrade report

## Edge Cases

| Case | Behaviour |
|------|-----------|
| Module has no tests | Phase 5 invokes `magento2-test-generate` to generate a smoke test before applying changes; subsequent fixes are validated against it. |
| Rector rule set isn't available | Skip auto-fix; report all findings as manual-fixable. |
| Module composer.json constraints can't accept the target Magento version | Phase 1 stops; user must accept a multi-target strategy or narrow scope. |
| Multi-module upgrade where modules depend on each other | Order topologically; one report per module; share an UPGRADE.md preface. |

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| 5 | `magento2-test-generate` (when coverage gaps prevent safe upgrade) |
| 6 | `magento2-module-review --diff` |
