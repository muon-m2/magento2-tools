# {Feature Name} — Implementation Report

Date: {YYYY-MM-DD}
Status: Complete
Implemented by: Claude Code using `magento2-feature-implement`
Blueprint: `.docs/{FeatureName}/blueprint.md`
Skill versions:

- magento2-feature-implement@2.8.0
  - magento2-module-create@1.7.1
  - magento2-module-review@2.3.1
- magento2-context@1.6.1

---

## Executive Summary

{Two to four sentences. State what was built, whether it matches the approved blueprint, and
the overall risk posture. Include a one-line test result.}

Example: "The {Feature Name} feature was implemented across two new modules and one modified module,
matching the approved blueprint with one documented deviation. All unit tests pass with 91% average
coverage across new modules. No Critical or High findings were identified during module review."

---

## Modules Implemented

| Module | Status | Surfaces | Files | Test coverage |
|--------|--------|----------|-------|---------------|
| `{Vendor}_{ModuleA}` | New | core, persistence, service_contracts | {N} | {N}% |
| `{Vendor}_{ModuleB}` | New | core, admin_ui | {N} | {N}% |
| `{Vendor}_{Existing}` | Modified | — | +{N} | — |

---

## Public API Index

### Service Contracts

| Interface | Methods | Module |
|-----------|---------|--------|
| `{Vendor}\{ModuleA}\Api\{Entity}RepositoryInterface` | `save`, `getById`, `delete`, `getList` | `{Vendor}_{ModuleA}` |

### REST Endpoints

| Method | Route | ACL | Handler |
|--------|-------|-----|---------|
| `GET` | `/V1/{vendor_lower}/{route}/:id` | `{Vendor}_{ModuleA}::view` | `{Entity}RepositoryInterface::getById` |
| `POST` | `/V1/{vendor_lower}/{route}` | `{Vendor}_{ModuleA}::manage` | `{Entity}RepositoryInterface::save` |

### GraphQL (if applicable)

| Type | Name | Auth |
|------|------|------|
| Query | `{vendor_lower}{Entity}` | Customer session |

### Events Dispatched (if applicable)

| Event name | Payload | Module |
|------------|---------|--------|
| `{vendor_lower}_{module}_{entity}_save_after` | `entity` | `{Vendor}_{ModuleA}` |

---

## Configuration Guide

| Config path | Type | Default | Purpose |
|-------------|------|---------|---------|
| `{vendor_lower}_{module}/general/enabled` | Yes/No | 1 | Feature toggle |

### Post-Install Steps

1. Generate schema whitelist for modules with persistence surfaces:
   ```bash
   {magento} setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleA}
   ```
2. Configure the feature in Admin > Stores > Configuration > {Section}.
3. {Any other required steps.}

---

## Tradeoffs

### {Tradeoff Title}

Chosen: {option selected}

Why: {one to three sentences}

Alternative considered: {other option and why not chosen}

Risk: {what could go wrong and how it is mitigated}

---

## Deviations from Blueprint

- **{Deviation title}**
  Blueprint said: {planned}
  Implemented as: {actual}
  Reason: {why it changed}
  Impact: {what caller or admin needs to know}

---

## Test Coverage Summary

| Module | Unit tests | Coverage | Notes |
|--------|------------|----------|-------|
| `{Vendor}_{ModuleA}` | {N} | {N}% | Service and Repository covered |
| `{Vendor}_{ModuleB}` | {N} | {N}% | {notes} |

PHPUnit result: {N} passed, {N} failed, {N} skipped.

---

## Known Limitations

- {Specific limitation with concrete impact. No vague "edge cases" entries.}
- {Another limitation.}


---

## Recommended Next Steps

1. Run `setup:db-declaration:generate-whitelist` for each new module with a persistence surface.
2. Run `magento2-module-review` for any module reviewed only quickly during Phase 5.
3. Add integration tests for REST endpoints.
4. Configure the feature in Admin > {path}.
5. Run `magento2-deploy` to enable modules on staging.

---

## Smoke Test Results

(Mandatory in `feature` and `extend` modes. In `hotfix` mode a single paragraph + iteration
count is acceptable. Omit entirely in `spike` mode.)

### Iteration summary

| Iteration | Date/time | New findings | Resolved | Decision |
|-----------|-----------|--------------|----------|----------|
| 1 | {ISO ts} | {ids or —} | {ids or —} | {PASS / FAIL — re-enter Phase 6 / HALT} |

Total iterations: {N} / 5.
Final decision: {PASS / ACCEPT-KNOWN-ISSUES / ABORT}.

### Suite outcomes (final iteration)

| Suite | Ran? | Pass? | Findings | Notes |
|-------|------|-------|----------|-------|
| S1 Baseline & probe | yes | yes | — | — |
| S2 REST scenarios | {yes/skipped} | {yes/no} | {ids} | {N endpoints × N scenarios} |
| S3 Admin login | {yes/skipped} | {yes/no} | {ids} | — |
| S4 Stores Config walk | {yes/skipped} | {yes/no} | {ids} | {N sections walked} |
| S5 Admin grids | {yes/skipped} | {yes/no} | {ids} | Customers, Catalog Products, Sales Orders + {new grids} |
| S6 New / changed routes | {yes/skipped} | {yes/no} | {ids} | {N routes covered} |
| S7 Customer flows | {yes/skipped} | {yes/no} | {ids} | Register / login / {N} My Account tabs |
| S8 Exception.log diff | yes | yes | — | 0 new lines |
| S9 Triage | yes | yes | — | — |

### Findings (final state)

| ID | Severity | Category | Resolved in iter | Fix delegate | Notes |
|----|----------|----------|------------------|--------------|-------|
| F1 | Critical | rest_contract | 3 | magento2-bug-fix | ACL missing in webapi.xml |

### Artifacts

- Per-iteration reports: `.docs/{FeatureName}/smoke/run-{1..N}.md`
- Consolidated findings: `.docs/{FeatureName}/smoke/findings.md`
- REST scenarios: `.docs/{FeatureName}/smoke/scenarios.md`
- Screenshots: `.docs/{FeatureName}/smoke/screenshots/run-{1..N}/`
- Raw S2 request/response: `.docs/{FeatureName}/smoke/raw/S2/`
- Exception log diff: `.docs/{FeatureName}/smoke/raw/S8/exception-diff.log`
