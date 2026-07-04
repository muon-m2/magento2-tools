---
name: magento2-module-review
description:
    Review Magento 2 modules for architecture, Magento framework requirements, best practices, security, code quality, maintainability, PHPDoc, SOLID/DRY/KISS/SRP, and test coverage. Use when asked to audit, review, validate, assess, or report on a Magento 2 module, including app/code modules, package-source modules, composer-distributed modules, controller/service/model/template/config/schema reviews, or release-readiness checks. The skill is environment-independent: it must not assume Docker, Make, bin/magento, installed dependencies, a database, network access, or a running Magento instance, and should use available static-analysis tools opportunistically. For security-only depth (CVEs, secrets, Marketplace EQP) use magento2-security-audit; for performance-only depth use magento2-performance-audit.
---

# Magento 2 Module Review

Review Magento 2 modules with static evidence first. Use runtime tools only when they are already available and safe. A
missing tool or unavailable Magento runtime is an environment limitation, not a module defect.

## Core Rules

- Treat the module as source under review; do not edit files unless the user asks for fixes.
- Prefer static analysis and direct file inspection over runtime assumptions.
- Do not require Docker, Make, Magento CLI, Composer install, database access, network access, or a running Magento
  instance.
- Use every relevant static-analysis tool that is available locally; skip unavailable tools and report them clearly.
- Avoid reviewing `vendor/` as source unless the user explicitly points to a vendor-distributed module.
- Report findings first, ordered by severity, with file and line references. See
  `references/evidence-citation.md` for citation rules covering grep matches, XML structures,
  missing files, and cross-file findings.
- Separate confirmed defects, recommendations, subjective style notes, and environment limitations.
- Evaluate code style, PHPDoc, DRY, SOLID, KISS, and SRP as maintainability criteria; only escalate when they create
  concrete risk or violate Magento standards.

## Workflow

1. Identify module scope.
    - Determine module name from `registration.php`, `etc/module.xml`, or `composer.json`.
    - **If module identity cannot be resolved from any of these three sources, stop immediately.** Report to
      the user which files are missing or malformed. Do not proceed to step 2 with an unknown module.
    - Record path, namespace, package type, Magento version hints, and feature surface.
    - In Claude Code: use the `Read` tool for individual files, `Bash` with `grep -r` for
      targeted pattern searches, and the `Explore` subagent for broad file-tree discovery
      (keeps results out of main context). Avoid `rg` unless confirmed available.
    - After step 1, present a brief module profile (name, path, file counts, surfaces present), then
      continue to step 2 without waiting for acknowledgment unless the user has asked to approve scope
      before proceeding.
    - **Scope selection:** default to **full review** when the user's request contains any of:
      audit, release-readiness, security review, comprehensive, or report.
      Treat output format (HTML, Markdown) as a separate, orthogonal choice — do not use it as a scope signal.
      Default to **quick review** when the user says quick, fast, time-boxed, or brief.
      Ask only when the request is genuinely ambiguous (e.g. bare "review this module").
    - **Large module protocol (>50 PHP files or >150 total files):** read all config XML fully; read every
      file in `Api/`, `Controller/`, `Plugin/`, and `Observer/` fully; sample-read (first 60 lines) all
      remaining PHP files; state the sampling strategy in the report scope section.

2. Build the architecture map.
    - Map registration, Composer metadata, DI, routes/controllers, service contracts, domain models, persistence,
      config, presentation, cron/queue, APIs, GraphQL, plugins, observers, and tests.
    - Use `references/review-checklist.md` as the evaluation source for all tier criteria. Load it on demand
      when entering each tier — do not load it upfront for areas that will not be reached.

3. Run optional static tool passes.
    - Prefer safe file-only commands first: PHP lint, XML lint, JSON validation, Composer validation, grep-pattern
      scans.
    - Run Magento/PHP tooling only if present: PHPCS, PHPMD, PHPStan, Psalm, PHPUnit, Rector dry-run, Semgrep.
    - Use `${CLAUDE_SKILL_DIR}/scripts/static-tool-probe.sh` to list available tools and suggested commands without
      assuming they exist.
    - Use `${CLAUDE_SKILL_DIR}/scripts/discover-module.sh <module-path>` for a quick source inventory.
    - Use `${CLAUDE_SKILL_DIR}/scripts/collect-evidence.sh <module-path>` for grep-based risk and surface scans.
    - **Script output:** summarise grep/tool output to the top 30 most relevant file:line references before proceeding.
      Do not dump raw script output into context; extract only patterns that warrant further investigation.
    - See `references/static-analysis-tools.md` for the full command list and failure-classification rules.

4. Review code quality and architecture.
    - Validate Magento architectural requirements and framework best practices.
    - Check security, persistence, API boundaries, DI patterns, frontend escaping, admin ACL/config, cron/queue safety,
      and test coverage.
    - Check code style and PHPDoc against `references/phpdoc-code-style.md`.
    - Check DRY/SOLID/KISS/SRP and separation of concerns as maintainability concerns.

5. Produce a report.
    - Use findings-first structure: severity, impact, evidence, recommendation, verification.
    - Include tool results and skipped checks.
    - For Markdown output: use `references/report-template.md`.
    - For HTML output: use `templates/report.html`. Load this file only when the user requests HTML.
    - For JSON output (default when invoked from another skill or with `--format=json`):
      build the findings array per `magento2-context/references/findings-schema.md`, then
      pipe it through `${CLAUDE_SKILL_DIR}/scripts/emit-json.sh`. Writes to
      `{output_root}/reviews/{Vendor}_{Module}-review-{date}.json` — anchored at the project
      root, never under `{ctx.magento_root}`. `{output_root}` is the `--docs-root` value when
      the caller passed one, else `{ctx.docs_root}`. Run as:
      `DOCS_ROOT="${DOCS_ROOT_ARG:-.docs}" bash "${CLAUDE_SKILL_DIR}/scripts/emit-json.sh"`
      (where `DOCS_ROOT_ARG` is the resolved `--docs-root` value) so an in-`src/` cwd cannot
      redirect output into the Magento tree. See "Output Root" below.
    - For SARIF output (CI / GitHub Code Scanning): run `${CLAUDE_SKILL_DIR}/scripts/emit-sarif.sh` on the JSON
      output. Writes alongside the JSON file with `.sarif` extension.
    - Update `Reviewer:` to `Claude Code using magento2-module-review` and include the
      `Skill versions:` block from `references/report-template.md`.

6. If fixes are requested.
    - First route every finding and recommendation per the **Fix Routing** table below. Invoke the
      routed skill for each item it owns; only items the table marks inline are fixed in this skill.
    - Fix inline items in severity order: Critical first, then High, then Medium, then Low. Do not
      silently drop any severity level — anything not fixed is listed as residual risk in the v2 report.
    - Keep each change scoped to its confirmed finding. Do not clean up surrounding code.
    - After each fix, rerun the best available static check on the modified file before proceeding to the
      next finding. If a fix introduces a new finding, report it to the user rather than fixing it silently.
    - Add/update tests for behaviour changes.
    - Create a v2 report summarising resolved findings, items delegated to other skills (naming the
      skill per item), and residual risk.

## Output Root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, run the emitter with
`DOCS_ROOT=<path>` so artifacts land under `<path>/reviews/`; otherwise they default
to `{ctx.docs_root}/reviews/`. Orchestrators such as `magento2-feature-implement`
pass this to collect a run's artifacts under one folder.

## Fix Routing

When the user asks to act on findings or report recommendations, route each item to the skill that
owns that work before touching code. The mapping is deterministic — do not pick the executing skill
ad-hoc.

| Finding / recommendation                                                              | Executed by                                        |
|----------------------------------------------------------------------------------------|----------------------------------------------------|
| Behavioural defect: wrong output, crash, exception, broken controller/API/cron/queue    | `magento2-bug-fix`                                 |
| Security defect with localised evidence: SQLi, XSS/escaping, CSRF, ACL gap, secret      | `magento2-bug-fix`                                 |
| Security exposure needing site-wide or cross-module scoping first                       | `magento2-security-audit`, then `magento2-bug-fix` |
| New or changed functionality, or any `db_schema.xml` change                             | `magento2-feature-implement` (`--mode=extend`)     |
| Missing or insufficient test coverage                                                   | `magento2-test-generate`                           |
| Performance defect, localised, code-only change (N+1 at file:line, missing cache)       | `magento2-bug-fix`                                 |
| Unlocalised slowness symptom (no confirmed file:line)                                   | `magento2-performance-audit`, then `magento2-bug-fix` |
| Data repair: corrupted rows, backfill, reseed                                           | `magento2-data-migration`                          |
| Deprecated API usage, BC break, framework/PHP version-constraint findings               | `magento2-module-upgrade`                          |
| Missing translations or hardcoded user-facing strings                                   | `magento2-i18n`                                    |
| New theme, RequireJS/Knockout, LESS, or email-template scaffolding                      | `magento2-frontend-create`                         |
| Style, PHPDoc, naming, comments, dead code (typically Low)                              | Inline — step 6 of this skill                      |

- Default rows: any other confirmed defect routes to `magento2-bug-fix`; any other recommendation
  that adds behaviour routes to `magento2-feature-implement`.
- Invoke the routed skill with the finding's evidence (`file:line`) and the report path so it does
  not re-derive the diagnosis.
- Exception — invoked from another skill: when this review ran in diff mode on behalf of
  `magento2-feature-implement`, `magento2-bug-fix`, or `magento2-module-upgrade`, return findings
  to the calling skill instead of routing; the caller owns remediation.

## Diff Mode

Use when the user invokes with `--diff [<ref>]` or when this skill is called from
`magento2-feature-implement` / `magento2-bug-fix` / `magento2-module-upgrade` after a
code change. Read `references/diff-mode.md` for the full algorithm.

- Run `${CLAUDE_SKILL_DIR}/scripts/diff-scope.sh <module-path> <ref>` (default ref `origin/main`) to obtain
  the changed-file list. If exit 1, report "no findings — nothing to review" and stop.
- Restrict architecture mapping, tool passes, and checklist application to the changed
  files. Cross-file findings cite the outside file with `crossFile: true`.
- JSON output sets `mode: "diff"` and includes `diffRef` in `target`.
- Report scope reads "Diff against `<ref>` — N files".

## Quick Review Mode

Use when the user requests a quick review, or after the step-1 profile check when the user confirms. A module qualifies
for quick review when it has **fewer than 20 PHP files AND none of** `webapi.xml`, `etc/schema.graphqls`,
`etc/frontend/routes.xml`, or `etc/adminhtml/routes.xml` present — any of these files warrants a full review regardless
of size.

Cover all **Tier 1 areas** (matching the checklist) plus a registration sanity check. Do not include Testing (Tier 2) in
quick reviews.

- **Security:** ACL, CSRF, escaping, input validation, secrets, SQL safety.
- **Persistence and setup:** declarative schema, parameterised queries, idempotent patches, schema whitelist.
- **Dependency injection:** constructor injection only, no ObjectManager in production code, proxies for heavy deps.
- **Controllers and CSRF:** HTTP interface compliance, form-key validation, GET idempotency, explicit authorisation.
- **Service contracts and APIs:** ACL on all exposed endpoints, anonymous access justified, no raw-array API types.
- **Registration sanity:** `registration.php`, `composer.json`, `etc/module.xml` — naming, constraints, autoload.

Note explicitly which Tier 2 and 3 areas were skipped. If any Critical or High finding appears, recommend a full review.

## Optional Parallel Review

Read `references/parallel-review.md` before delegating. Parallel review requires explicit user authorization.

## Severity

Use the shared five-point scale (Critical / High / Medium / Low / Info) defined in
`magento2-context/references/severity.md` — including its adjustment rules and the
suspected-but-unconfirmed handling. Every finding must include impact, evidence,
recommendation, and a verification or test suggestion. See `references/severity-examples.md`
for the Magento-specific calibration matrix.

## Reference Files

- `references/review-checklist.md`: full architecture and best-practice checklist (3 risk tiers).
- `references/phpdoc-code-style.md`: PHPDoc, comments, Magento code style, DRY/SOLID/KISS/SRP.
- `references/static-analysis-tools.md`: full tool command list and how to classify failures.
- `references/parallel-review.md`: subtask split, Claude Code agent guidance, model guidance.
- `references/severity-examples.md`: Magento severity calibration matrix.
- `references/evidence-citation.md`: citation rules for grep, XML, missing-file, and cross-file findings.
- `references/report-template.md`: Markdown report structure.
- `templates/report.html`: HTML report template (load only for HTML output).
- `${CLAUDE_SKILL_DIR}/scripts/emit-json.sh`: writes the findings JSON document per the shared schema
  (`magento2-context/references/findings-schema.md`).
- `${CLAUDE_SKILL_DIR}/scripts/emit-sarif.sh`: converts a JSON document to SARIF 2.1.0 for GitHub Code Scanning.
- `${CLAUDE_SKILL_DIR}/scripts/diff-scope.sh`: lists files changed in a module since a git ref (powers diff mode).
- `references/diff-mode.md`: invocation and algorithm for `--diff` mode.
- `references/tier3-checks.md`: WCAG, plugin/preference collision, PCI scope, GDPR data
  retention. Runs in full review; skipped in quick mode and with `--no-tier-3`.
