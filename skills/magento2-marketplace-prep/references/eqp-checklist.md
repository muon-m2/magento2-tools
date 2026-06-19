# EQP Submission Checklist

Checklist for Adobe Commerce Marketplace Extension Quality Program (EQP) submission.
This document covers the **structural and metadata** requirements assessed by
`magento2-marketplace-prep`. For **EQP static code rules** (phpcs Magento2 coding
standard, security patterns), see
`magento2-security-audit/references/eqp-rules.md` — those rules are delegated
to `magento2-security-audit` rather than duplicated here.

## Tier Definitions

| Tier | Meaning | Action |
|------|---------|--------|
| **blocker** | Must-fix to pass EQP; submission will be rejected without it | Fix before submitting |
| **warning** | Strongly recommended; may cause rejection or low score | Fix before submitting |
| **info** | Best practice; improves quality score and developer experience | Fix if time allows |

## 1. Composer Metadata

| # | Check | Tier | Notes |
|---|-------|------|-------|
| M1 | `composer.json` present | blocker | Required for Marketplace packaging |
| M2 | `name` matches `{vendor}/{module-*}` pattern (lowercase, hyphen-separated) | blocker | EQP rejects non-conforming package names |
| M3 | `type` is `magento2-module` | blocker | EQP identifies extension type by this field |
| M4 | `version` field present (semver) | blocker | Marketplace requires a declared version |
| M5 | `license` field present | blocker | Must match the LICENSE file contents |
| M6 | `require` includes `magento/framework` | blocker | Extension must declare its framework dependency |
| M7 | `require` includes a PHP version constraint | blocker | Marketplace validates PHP compat |
| M8 | PSR-4 `autoload` configured | blocker | Module classes must be autoloadable |
| M9 | No `dev-*`, `@dev`, or `*` wildcard version constraints in `require` | blocker | Marketplace rejects non-stable dependency constraints |
| M10 | `description` field present | warning | Displayed on Marketplace listing |
| M11 | `authors` field present with at least one entry | warning | Required for attribution |
| M12 | `keywords` field present | info | Improves discoverability |

## 2. Licensing

| # | Check | Tier | Notes |
|---|-------|------|-------|
| L1 | `LICENSE` or `LICENSE.txt` file present | blocker | EQP requires a license file |
| L2 | License is OSI-approved (e.g. MIT, Apache-2.0, GPL-3.0) OR proprietary EULA if commercial | blocker | Marketplace accepts specific license types |
| L3 | Copyright/license header present in PHP source files | warning | EQP best practice; some plans require it |
| L4 | License in composer.json matches LICENSE file | warning | Inconsistency flags for manual EQP review |

## 3. Module Structure

| # | Check | Tier | Notes |
|---|-------|------|-------|
| S1 | `registration.php` present | blocker | Required for module registration |
| S2 | `etc/module.xml` present | blocker | Required for module declaration |
| S3 | Module name in `registration.php` matches `etc/module.xml` | blocker | Name mismatch causes install failure |
| S4 | `setup_version` absent from `etc/module.xml` (Magento 2.3+) | warning | Deprecated; use data patches instead |

## 4. Testing

| # | Check | Tier | Notes |
|---|-------|------|-------|
| T1 | MFTF functional tests present under `Test/Mftf/` | warning | Marketplace evaluates functional test coverage |
| T2 | Unit or integration tests present under `Test/Unit/` or `Test/Integration/` | info | Improves overall quality score |

## 5. Documentation

| # | Check | Tier | Notes |
|---|-------|------|-------|
| D1 | `README.md` present | warning | Required for Marketplace listing quality |
| D2 | README includes installation section | warning | Reviewers check for install instructions |
| D3 | README includes configuration/usage section | info | Improves developer experience score |
| D4 | `CHANGELOG.md` or release notes present | info | Versioning transparency |

## 6. Packaging Hygiene

| # | Check | Tier | Notes |
|---|-------|------|-------|
| P1 | No dev artifacts in source (`.DS_Store`, `node_modules/`, `.env`, `*.log`) | warning | Dev artifacts inflate package size and confuse reviewers |
| P2 | `.gitignore` present | info | Signals hygiene awareness |
| P3 | `composer.json` `archive.exclude` configured to omit test/dev files from package | info | Reduces package size; see `references/packaging.md` |

## EQP Static Code Rules (Delegated)

The coding-standard portion of EQP (phpcs Magento2 standard, security patterns, DI
conventions) is **not duplicated here**. Those checks are covered by:

- `magento2-security-audit` Phase 5 — Marketplace coding-standard checks
- `magento2-security-audit/references/eqp-rules.md` — the authoritative EQP rule map

When running `magento2-marketplace-prep`, Phase 2 **delegates** to `magento2-security-audit`'s
EQP scan and incorporates those findings. This ensures a single implementation and avoids
rule drift.

## Submission Readiness Verdict

See `references/readiness-scoring.md` for the score formula and PASS/FAIL/CONDITIONAL
verdict definitions.

A module may submit to Marketplace only when:
1. All **blocker** findings are resolved (score on those = 0).
2. Overall readiness score ≥ 70 (recommended ≥ 85 for first-attempt approval).
