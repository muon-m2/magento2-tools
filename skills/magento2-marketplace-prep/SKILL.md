---
name: magento2-marketplace-prep
description:
    Assess an existing Magento 2 module's readiness for Adobe Marketplace / EQP submission
    — composer metadata completeness, license headers, MFTF test presence,
    version-constraint sanity, support docs, packaging, and EQP static rules — and emit a
    tiered, scored readiness report (Markdown + JSON + SARIF). Read-only. For the deep
    CVE/secret/EQP security scan use `magento2-security-audit`; to actually version/tag/publish
    a release use `magento2-release`.
---

# Magento 2 Marketplace Prep

Assess an existing module's readiness for **Adobe Commerce Marketplace / EQP submission**
and emit a tiered, scored readiness report. This is a **read-only** audit skill — it never
modifies code, never packages or uploads anything. Submission remains the vendor's manual step.

## Core Rules

- **READ-ONLY.** Never modifies source files, never runs `composer archive`, never uploads.
  All checks are purely file-inspection or non-mutating CLI probes.
- **REUSE EQP static rules.** Phase 2 delegates EQP coding-standard checks to
  `magento2-security-audit`'s EQP scan rather than duplicating its rule list. See
  `references/eqp-checklist.md` for the cross-reference.
- **Tiered findings.** Every finding is classified as one of:
  - **blocker** — must-fix to pass EQP; maps to `critical` or `high` on the shared severity
    scale.
  - **warning** — Marketplace convention; strongly recommended; maps to `medium`.
  - **info** — best-practice advice; maps to `low` or `info`.
  See `references/readiness-scoring.md` and `magento2-context/references/severity.md`.
- **Readiness score.** A 0–100 score is computed from weighted findings. A **PASS** verdict
  requires 0 blockers. See `references/readiness-scoring.md`.
- **Honest gaps.** A missing tool or file is reported as a finding; it is never invented as
  present.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx}`. Hard-stop if the target module directory does
not exist.

### Phase 1 — Scope

Identify the target module `{Vendor}_{Module}` and its path. If not supplied, infer from
composer.json or the directory tree (first custom module found).

### Phase 2 — Readiness Checks

Run **two** complementary checks:

1. **Marketplace-specific checks** (`${CLAUDE_SKILL_DIR}/scripts/check-readiness.sh`).
   Covers: composer metadata completeness, LICENSE file, license headers in PHP files,
   `registration.php` + `etc/module.xml` presence and consistency, MFTF test presence,
   README / user-docs presence, packaging hygiene, and no dev version constraints.
   See `references/eqp-checklist.md` for the full checklist.

2. **EQP static rules** — delegate to `magento2-security-audit`'s Phase 5 (the Magento
   coding-standard / EQP static pass). Do **not** re-implement EQP rules here; incorporate
   the `magento2-security-audit` EQP findings into the combined findings list. If
   `magento2-security-audit` is not available, skip this sub-check and record a
   `scanner_errors` entry.

### Phase 3 — Report

Produce three deliverables:

1. **Markdown readiness report** (LLM deliverable, NOT automated). Written as:
   `.docs/marketplace/{Vendor}-{Module}-readiness-{date}.md`
   Sections: module identity + summary, readiness score + verdict, blockers, warnings, info,
   EQP static summary, skipped checks / scanner errors, recommended next steps.

2. **JSON + SARIF** (automated via `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh`). The
   automated basename converts underscores in the module name to hyphens (e.g.
   `Acme_OrderExport` → `Acme-OrderExport-readiness-{date}`):
   ```
   .docs/marketplace/{Vendor}-{Module}-readiness-{date}.json   # OUTPUT_KIND=marketplace
   .docs/marketplace/{Vendor}-{Module}-readiness-{date}.sarif
   ```
   The script aggregates findings from check-readiness.sh — plus the delegated
   `magento2-security-audit` EQP findings when `EQP_FINDINGS_FILE` is provided (Phase 2.2)
   — and invokes the shared `magento2-module-review/scripts/emit-json.sh` with
   `OUTPUT_KIND=marketplace`.

## Marketplace-Specific Checks (check-readiness.sh)

| Check | EQP tier |
|-------|----------|
| `composer.json` `name` matches `{vendor}/{module-*}` pattern | blocker |
| `composer.json` `type: magento2-module` | blocker |
| `composer.json` `version` present | blocker |
| `composer.json` `license` present | blocker |
| `composer.json` `require` includes `magento/framework` | blocker |
| `composer.json` `require` includes a PHP constraint | blocker |
| `composer.json` PSR-4 autoload configured | blocker |
| No `dev-`/`@dev`/wildcard `*` version constraints | blocker |
| LICENSE file present | blocker |
| Copyright/license header present in PHP files | warning |
| `registration.php` present | blocker |
| `etc/module.xml` present | blocker |
| Module name in `registration.php` matches `etc/module.xml` | blocker |
| MFTF tests present under `Test/Mftf/` | warning |
| README / user documentation present | warning |
| No dev artifacts committed (`.DS_Store`, `node_modules/`, etc.) | warning |
| `.gitignore` present | info |

## Reference Files

- `references/eqp-checklist.md` — full EQP submission checklist (cross-references
  `magento2-security-audit/references/eqp-rules.md` for static code rules).
- `references/readiness-scoring.md` — tiering, severity mapping, score formula, verdict.
- `references/packaging.md` — composer package structure, exclusions, validation.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/check-readiness.sh` — runs all marketplace-specific
  read-only checks and outputs a findings JSON array conforming to
  `magento2-context/references/findings-schema.md`.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — aggregates check-readiness output and
  emits via the shared `magento2-module-review/scripts/emit-json.sh` /
  `magento2-module-review/scripts/emit-sarif.sh` pipeline.
  `OUTPUT_KIND=marketplace`, `SKILL_NAME=magento2-marketplace-prep`.

## Inputs

```
/magento2-marketplace-prep [--module=<Vendor>_<Module>] [--format=markdown|json|sarif]
```

## Outputs

Artifact basenames convert underscores in the module name to hyphens
(`Acme_OrderExport` → `Acme-OrderExport`):

```
.docs/marketplace/{Vendor}-{Module}-readiness-{date}.md     # LLM deliverable (Phase 3)
.docs/marketplace/{Vendor}-{Module}-readiness-{date}.json   # automated (build-findings.sh)
.docs/marketplace/{Vendor}-{Module}-readiness-{date}.sarif  # automated (build-findings.sh)
```

## Severity Calibration

Use the shared five-point scale (`magento2-context/references/severity.md`).
The EQP tier → severity mapping is:
- **blocker** → `critical` (blocks EQP pass) or `high` (likely blocks)
- **warning** → `medium`
- **info** → `low` or `info`

See `references/readiness-scoring.md` for the per-check mapping.

## Acceptance Criteria

- 0 blockers → PASS verdict. Any blocker → FAIL with blockers listed first.
- Readiness score emitted in the JSON document as `readiness_score` (0–100) and in the
  Markdown summary.
- Every finding carries file evidence and a concrete fix recommendation.
- `scanner_errors` accurately reflects any skipped sub-check.

## Related Skills

| Concern | Skill |
|---------|-------|
| Deep CVE / secret / EQP static scan | `magento2-security-audit` |
| Version bump, changelog, tag, publish | `magento2-release` |
| Context resolution (Phase 0) | `magento2-context` |
| Generate MFTF / API tests (if gaps found) | `magento2-test-generate` |
