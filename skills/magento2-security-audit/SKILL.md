---
name: magento2-security-audit
description:
    Site-wide and per-module security audit for Magento 2. Use when the user requests a
    security review, a pre-release security check, an audit covering dependency CVEs or
    secret leakage, or a Marketplace EQP scan. Produces findings ranked by the shared
    severity scale in Markdown, JSON, and SARIF. Combines composer audit, known-Magento-CVE
    matching, secret scanning, Marketplace EQP static rules, and cross-module pattern
    detection. This is cross-module, dependency-level, and repo-wide depth; for per-module
    security findings within a general architecture/quality review use magento2-module-review.
---

# Magento 2 Security Audit

Deep security audit beyond what `magento2-module-review` does. Adds:

- `composer audit` and CVE database scan for **dependencies**
- Known **Magento CVE** matching for the resolved Magento version
- **Marketplace EQP** (Extension Quality Program) static rules
- **Secret scanning** across the repo
- **Magento-specific patterns** beyond Tier 1 review (anti-CSRF tokens, session
  security, cookie flags, etc.)
- **Cross-module collision** detection

`magento2-module-review` continues to handle per-module security findings. This skill is
**broader** (cross-module, dependency-level, repo-level).

## Core Rules

- **No prod credential prompts.** This skill never asks for production secrets. CVE
  matching uses cached Adobe Security Bulletins; secret scanning is read-only.
- **JSON + SARIF always.** Output the shared findings schema (see
  `magento2-context/references/findings-schema.md`). SARIF for GitHub Code Scanning.
- **Tool-agnostic.** Falls back to regex-based secret detection when `gitleaks` /
  `trufflehog` are unavailable.
- **Severity calibrated to PCI/GDPR impact.** A finding that elevates PCI scope or
  exposes PII is Critical or High by default.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture Magento version, PHP version, edition.

### Phase 1 — Scope

- Default: all custom modules under `{vendor_lower}/`.
- Optional: include `vendor/` (third-party-module scan).
- Optional: include Magento core (CVE-matching only; no source-edit recommendations).

### Phase 2 — Dependency Audit

| Check | Source |
|-------|--------|
| `composer audit` | Composer's built-in advisory database |
| Magento CVE list | Cached Adobe Security Bulletins (`references/magento-cve-database.md`) |
| Roave Security Advisories | `roave/security-advisories` package |
| Direct vendor CVE check | OSV.dev API (optional, requires network) |

Findings include CVE ID, severity, affected package, fixed version, upgrade path.

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
   scanners and invokes the shared `magento2-module-review/scripts/emit-json.sh` with
   `SKILL_NAME=magento2-security-audit` and `OUTPUT_KIND=security`.
2. **SARIF** (automated). The same `build-findings.sh` invocation now also produces
   SARIF via `magento2-module-review/scripts/emit-sarif.sh`. No separate caller step is
   required.
3. **Markdown summary** (LLM deliverable, NOT automated). The Markdown report is
   written by the skill in the conversation, with these sections:
   - Magento + PHP + edition + dependencies summary
   - Critical/High findings (top of report)
   - Per-module breakdown
   - CVE summary (with upgrade paths) — including `magento_core_cve_status` if non-live
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
- `references/magento-cve-database.md` — cached Adobe Security Bulletin index.
- `references/secret-patterns.md` — provider-specific secret patterns + regex pack.
- `references/eqp-rules.md` — Marketplace EQP rule map.
- `references/pci-context.md` — when findings are PCI-scope-elevating.
- `references/severity-security.md` — calibration anchors (shared scale + security adds).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/secret-scan.sh` — `gitleaks` / `trufflehog` wrapper + regex pack fallback.
- `${CLAUDE_SKILL_DIR}/scripts/cve-scan.sh` — `composer audit` + OSV.dev wrapper.
- `${CLAUDE_SKILL_DIR}/scripts/cross-module-scan.sh` — di.xml + composer.json graph walker.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — assemble per-phase findings into a single JSON array.

## Inputs

```
/magento2-security-audit [--scope=module|site|vendor] [--include-magento-core] [--format=markdown|json|sarif] [<Vendor>_<Module>...]
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
recipe in `magento2-context/references/artifact-layout.md`.

## Severity Calibration

Use the shared five-point scale (`magento2-context/references/severity.md`) with the
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
| 0 | `magento2-context` |
| (optional, on CVE fix) | `magento2-module-upgrade` |
