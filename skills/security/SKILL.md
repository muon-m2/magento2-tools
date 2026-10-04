---
name: security
version: 2.0.0
description: >-
  Site-wide and per-module security audit for Magento 2. Use for a security review, pre-release
  security check, dependency CVE or secret-leakage audit, or Marketplace EQP scan. Produces
  severity-ranked findings (Markdown, JSON, SARIF) from a live composer audit, Adobe patch-state
  verdicts, secret scanning, EQP static rules, and cross-module patterns. Cross-module,
  dependency-level, repo-wide depth; for per-module security findings within a general quality
  review use magento2-tools:review.
---

# Magento 2 Security Audit

Deep security audit beyond what `review` does. Adds:

- Live `composer audit` for **dependency advisories** (no shipped advisory data)
- **Adobe patch-state verdicts** via `vendor/bin/patch-status` (is APSB-XX applied?)
- **Marketplace EQP** (Extension Quality Program) static rules
- **Secret scanning** across the repo
- **Magento-specific patterns** beyond Tier 1 review (anti-CSRF tokens, session
  security, cookie flags, etc.)
- **Cross-module collision** detection

`review` continues to handle per-module security findings. This skill is
**broader** (cross-module, dependency-level, repo-level).

## Core Rules

- **No prod credential prompts.** This skill never asks for production secrets. Secret
  scanning is read-only.
- **No shipped advisory data.** Dependency advisories come from a live `composer audit`
  and Adobe's own `vendor/bin/patch-status`; when either source is unavailable the run
  says so in `scanner_errors` ("advisories were NOT checked") instead of silently
  passing. Offline runs therefore cover secrets/EQP/patterns only — stated in the report.
- **JSON + SARIF always.** Output the shared findings schema (see
  `context/references/findings-schema.md`). SARIF for GitHub Code Scanning.
- **Tool-agnostic.** Falls back to regex-based secret detection when `gitleaks` /
  `trufflehog` are unavailable.
- **Severity calibrated to PCI/GDPR impact.** A finding that elevates PCI scope or
  exposes PII is Critical or High by default.

## Workflow

### Phase 0 — Context Resolution

Invoke `context`. Capture Magento version, PHP version, edition, and
`{ctx.runner}` — the runner is not optional here, see Phase 2.

### Phase 1 — Scope

- Default: all custom modules under `{vendor_lower}/`.
- Optional: include `vendor/` (third-party-module scan).
- Optional: include Magento core (CVE-matching only; no source-edit recommendations).

### Phase 2 — Dependency Audit

| Check | Source |
|-------|--------|
| `composer audit` | Composer's built-in advisory database (Packagist + FriendsOfPHP; live, needs network) |
| Roave Security Advisories | `roave/security-advisories` package |
| Per-advisory patch state | `vendor/bin/patch-status`, when the store ships it — see below |

Findings include CVE ID, severity, affected package, fixed version, upgrade path. Both
sources are live: nothing is matched against data shipped inside this skill, so results
are current by construction. The cost is stated honestly — an offline run checks no
advisories, and `scanner_errors` carries the "advisories were NOT checked" line.

#### Patch state, and why `RUNNER` matters

Adobe decoupled "is this fixed" from "what version am I": isolated patches and hotfixes
carry security fixes with **no version bump**, so `composer.lock` cannot see patch state
and an in-range version does not prove vulnerability. `advisory-scan.sh` resolves this
with **`vendor/bin/patch-status`** — Adobe's own verdict tool. It ships *inside* the
security patches and consults Adobe's advisory registry, so it answers the question
directly for every advisory in that registry: `VULNERABLE` becomes a finding,
`PROTECTED` and `NOT_APPLICABLE` are nothing-to-do by Adobe's own definition, `UNKNOWN`
carries no information worth a finding.

**Pass `RUNNER={ctx.runner}`.** The tool is PHP and shells out to `patch(1)`, so on a
Dockerised stack it only runs inside the app container. Existence is probed on the
**host** (`vendor/` is bind-mounted); execution goes through the runner.

Two traps worth knowing when reading the output:

- **The tool's exit code is not a success signal** — without `patch(1)` it prints an
  error and still exits 0. Validity is decided by parsing the JSON, never by `$?`. A
  present-but-unusable tool leaves an explanatory line in `scanner_errors`.
- `PATCH_STATUS=0` opts out entirely, for operators who would rather the scanner not
  execute a binary from the tree it is scanning (`CVE_PATCH_STATUS` is honoured as a
  legacy alias).

### Phase 3 — Secret Scan

| Check | Pattern |
|-------|---------|
| API keys in code/config | Provider-specific patterns (AWS, Stripe, etc.) |
| Encrypted-keyless secrets in `etc/config.xml` defaults | Sensitive paths with non-empty defaults |
| `.env` committed | git history check |
| Auth tokens in logs | Token formats in `var/log/` |
| Hardcoded passwords | Pattern match `define('PASSWORD'...)` |

Tooling: prefer `gitleaks` or `trufflehog` if available; fall back to regex pack from
`references/secret-patterns.md`. Script: `${CLAUDE_SKILL_DIR}/scripts/secret-scan.sh`.

### Phase 4 — Magento Static Pattern Pass

Beyond review's Tier 1 — see `references/security-checklist.md` for the full catalogue.

| Check | Pattern |
|-------|---------|
| Public REST endpoints with `anonymous` ACL | `webapi.xml` resource=`anonymous` |
| Admin controllers missing form key validation on POST | grep + AST |
| `<preference>` rewriting core security-sensitive classes | DI graph walk |
| Insecure cookie flags | `setSecure(false)`, `setHttpOnly(false)` |
| Session writes in observers | Risk of session fixation |
| Cron jobs running as web user (not magento user) | crontab.xml ownership |
| ACL resource using wildcards | `*` in ACL ID |
| GraphQL resolvers without auth check on mutations | Static check on resolver class |

### Phase 5 — Marketplace coding-standard checks

Run the Magento coding standard — the publicly runnable part of the Marketplace Extension
Quality Program (there is no `m2-coding-standard` / `magento-marketplace-eqp` binary):

- `{ctx.runner} vendor/bin/phpcs --standard=Magento2 {target}` (install `magento/magento-coding-standard`)
- optionally `vendor/bin/phpstan analyse {target}` and `vendor/bin/phpmd {target} text cleancode,codesize`

If `phpcs` / the `Magento2` standard is not installed, skip this phase and report it
(do not silently pass). Map findings to the shared severity scale per
`references/eqp-rules.md` (subcategory = the PHPCS sniff code).

### Phase 6 — Cross-Module Pattern Pass

Cross-cutting checks — see `${CLAUDE_SKILL_DIR}/scripts/cross-module-scan.sh`.

| Check | Pattern |
|-------|---------|
| Two custom modules both `<preference>` the same interface | di.xml walk |
| Module dependency cycle | composer.json + module.xml graph |
| Disabled modules referenced as `<sequence>` | Status check |
| Multiple modules registering same cron job name | crontab.xml walk |

### Phase 7 — Report

The skill produces **two automation artifacts** and **one LLM deliverable**:

1. **JSON** (automated). Built by `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh`, which aggregates the
   scanners and invokes the shared `context/scripts/emit-findings.sh` pipeline with
   `SKILL_NAME=security` and `OUTPUT_KIND=security`. Run
   `build-findings.sh` with `DOCS_ROOT=<output_root>` (the resolved `--docs-root` value,
   or `.docs` by default) so the JSON/SARIF land under `{output_root}/audits/`, and with
   `RUNNER={ctx.runner}` so the advisory scanner can reach `vendor/bin/patch-status`
   (Phase 2 — without it, Adobe patch-state verdicts are unavailable and the run says so
   in `scanner_errors`).
2. **SARIF** (automated). The same `build-findings.sh` invocation also produces
   SARIF via the shared `context/scripts/emit-findings.sh` pipeline. No separate caller step is
   required.
3. **Markdown summary** (LLM deliverable, NOT automated). The Markdown report is
   written by the skill in the conversation, with these sections:
   - Magento + PHP + edition + dependencies summary
   - Critical/High findings (top of report)
   - Per-module breakdown
   - Advisory summary (with upgrade paths) — and, when advisory sources were skipped
     (offline, composer missing, patch-status absent), a "Skipped advisory checks" note
     naming what was NOT checked
   - Secret-scan summary (with remediation steps)
   - EQP findings
   - Cross-module findings
   - Skipped checks and `scanner_errors`
   The Markdown is saved as `{output_root}/audits/{Vendor}_{Module}-security-{date}.md`
   (module scope; site/vendor scope: `security-{scope}-{date}.md`) by the LLM, not
   by a script. It is intended as a human-readable narrative on top of the JSON/SARIF
   artifacts.

## Reference Files

- `references/security-checklist.md` — full audit catalogue.
- `references/secret-patterns.md` — provider-specific secret patterns + regex pack.
- `references/eqp-rules.md` — Marketplace EQP rule map.
- `references/pci-context.md` — when findings are PCI-scope-elevating.
- `references/severity-security.md` — calibration anchors (shared scale + security adds).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/secret-scan.sh` — `gitleaks` / `trufflehog` wrapper + regex pack fallback.
- `${CLAUDE_SKILL_DIR}/scripts/advisory-scan.sh` — live `composer audit` + Adobe
  patch-state verdicts from `vendor/bin/patch-status`. Honours `RUNNER` and
  `PATCH_STATUS` (Phase 2). Degrades loudly into `scanner_errors` when offline.
- `${CLAUDE_SKILL_DIR}/scripts/cross-module-scan.sh` — di.xml + composer.json graph walker.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — assemble per-phase findings into a single JSON array.

## Inputs

```
/security [--scope=module|site|vendor] [--include-magento-core] [--format=markdown|json|sarif] [--docs-root=<path>] [<Vendor>_<Module>...]
```

## Outputs

Module scope (basename uses the underscore module name, e.g. `Acme_OrderExport`):
```
{output_root}/audits/{Vendor}_{Module}-security-{date}.json    # automation artifact (build-findings.sh)
{output_root}/audits/{Vendor}_{Module}-security-{date}.sarif   # automation artifact (build-findings.sh)
{output_root}/audits/{Vendor}_{Module}-security-{date}.md      # LLM deliverable, written in Phase 7
```
Site/vendor scope:
```
{output_root}/audits/security-{scope}-{date}.json
{output_root}/audits/security-{scope}-{date}.sarif
{output_root}/audits/security-{scope}-{date}.md
```
`{output_root}` defaults to `.docs` (`{ctx.docs_root}`); see the `--docs-root`/`DOCS_ROOT`
recipe in `context/references/artifact-layout.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`context/references/artifact-layout.md`). When set, run the emitter with
`DOCS_ROOT=<path>` so artifacts land under `<path>/audits/`; otherwise they default
to `{ctx.docs_root}/audits/`. Orchestrators such as `feature`
pass this to collect a run's artifacts under one folder.

## Execution Mode

Default: **auto** — `agents` when the plugin's context-budget hook reports this conversation
above its threshold, `inline` otherwise. In `agents` mode (`--agents` flag, or `execution_mode` in
`.claude/m2.json` surfaced as `{ctx.execution_mode}` — selection contract in
`context/references/execution-modes.md`) the judgement
passes of this skill are dispatched to the read-only `reviewer` agent with a security
dimension brief, and this skill owns synthesis. The scripted scanners
(`scripts/build-findings.sh`) are deterministic and run identically in both modes.

## Severity Calibration

Use the shared five-point scale (`context/references/severity.md`) with the
security-specific anchors **and the PCI / GDPR severity bumps** in
`references/severity-security.md` (the authoritative calibration matrix for this skill).

## Acceptance Criteria

- Identifies every committed `.env` style file or `define('SECRET'...)` line.
- Identifies CVEs in `composer.lock` with severity, affected version, fixed version.
- Cross-module collision report is complete (no missed dual `<preference>`).
- Output is SARIF-compatible for GitHub Code Scanning ingestion.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `context` |
| (optional, on CVE fix) | `upgrade` |
