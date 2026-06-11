# Final Report Format

Use this file during Phase 7 to produce the implementation report. The report is a Markdown
document saved alongside the feature blueprint. It documents what was built, any deviations from
the approved plan, and the information a developer or reviewer needs to understand and maintain
the feature.

---

## File Path

Save the final report to:

```
.docs/{FeatureName}/report.md
```

Also print it to the conversation so the user can read it immediately.

---

## Required Sections

### Header

```markdown
# {Feature Name} — Implementation Report

Date: {YYYY-MM-DD}
Status: {Complete | Partial — see Known Limitations}
Implemented by: Claude Code using `magento2-feature-implement`
Blueprint: `.docs/{FeatureName}/blueprint.md`
```

---

### 1. Executive Summary

Two to four sentences. State what was built, whether it matches the approved blueprint, and
the overall risk posture (clean, minor gaps, or known risks). Include a one-line test result
(e.g. "All unit tests pass — 94% coverage across new modules").

---

### 2. Modules Implemented

A table listing every module created or modified:

| Module               | Status   | Surfaces                             | Files | Test coverage |
|----------------------|----------|--------------------------------------|-------|---------------|
| `{Vendor}_XyzCore`   | New      | core, persistence, service_contracts | 14    | 87%           |
| `{Vendor}_XyzAdmin`  | New      | core, admin_ui                       | 8     | 72%           |
| `{Vendor}_Existing*` | Modified | —                                    | +3    | —             |

For modified modules, list only the files changed in the "Files" column (use `+N` format).

---

### 3. Public API Index

A reference list of every interface and endpoint that external callers can use.

#### Service Contracts

| Interface                                     | Methods                                | Location           |
|-----------------------------------------------|----------------------------------------|--------------------|
| `{Vendor}\XyzCore\Api\XyzRepositoryInterface` | `save`, `getById`, `delete`, `getList` | `{Vendor}_XyzCore` |

#### REST Endpoints

| Method | Route                        | ACL                      | Handler                           |
|--------|------------------------------|--------------------------|-----------------------------------|
| `GET`  | `/V1/{vendor_lower}/xyz/:id` | `{Vendor}_XyzCore::view` | `XyzRepositoryInterface::getById` |

#### GraphQL (if applicable)

| Type  | Name      | Auth             |
|-------|-----------|------------------|
| Query | `acmeWidget` | Customer session |

#### Events Dispatched (if applicable)

| Event name              | Payload    | Dispatched in           |
|-------------------------|------------|-------------------------|
| `acme_widget_save_after` | `{entity}` | `WidgetRepository::save` |

---

### 4. Configuration Guide

List every admin configuration field added, with path, default, and purpose:

| Config path                 | Type   | Default | Purpose        |
|-----------------------------|--------|---------|----------------|
| `acme_widget/general/enabled` | Yes/No | 1       | Feature toggle |

Describe any required post-install steps:

- Commands to run (e.g. `setup:db-declaration:generate-whitelist`)
- Admin settings that must be configured before the feature is active
- Data patches that must be applied

---

### 5. Tradeoffs

Document every tradeoff decision made during implementation using the format from
`references/tradeoffs-catalog.md`. Include only tradeoffs that were actually encountered.

---

### 6. Deviations from Blueprint

List any differences between the approved blueprint and what was implemented. For each deviation:

```
- **{Deviation title}**
  Blueprint said: {what was planned}
  Implemented as: {what was actually built}
  Reason: {why it changed}
  Impact: {what the caller or admin needs to know}
```

If none: "No deviations from the approved blueprint."

---

### 7. Test Coverage Summary

| Module              | Unit tests | Coverage | Notes                              |
|---------------------|------------|----------|------------------------------------|
| `{Vendor}_XyzCore`  | 12         | 87%      | Service and Repository covered     |
| `{Vendor}_XyzAdmin` | 4          | 72%      | Controllers not covered (UI layer) |

State clearly if any module is below the 80% target and why it is acceptable (or what must be added).

Include the PHPUnit result: pass count, failure count, skipped count.

---

### 8. Known Limitations

Bullet list. Be specific — "Known limitation" entries that say only "may have edge cases" are not
acceptable.

Examples of good entries:

- `XyzRepository::getList` does not support filtering by `created_at`; callers must filter in PHP.
- The admin grid does not support inline edit — a full page reload is required to save changes.
- The cron job is not idempotent if interrupted mid-batch; re-running may duplicate records for
  the interrupted batch window.

If none: "No known limitations identified."

---

### 9. Recommended Next Steps

Ordered list of what to do after this implementation, with the highest-value item first:

1. Run `setup:db-declaration:generate-whitelist` for each new module with a persistence surface.
2. Run `magento2-module-review` for any module that received only a quick review during Phase 5.
3. Add integration tests for the REST endpoints.
4. Configure the feature in Admin > {section path}.
5. Run `magento2-deploy` to enable modules on staging.

---

### 10. Smoke Test Results

Summary of Phase 6B. The full per-iteration detail lives in `.docs/{FeatureName}/smoke/`.

#### Iteration summary

| Iteration | Date/time | New findings | Resolved | Decision |
|-----------|-----------|--------------|----------|----------|
| 1 | {ISO ts} | F1, F2, F3, F4 | — | FAIL — re-enter Phase 6 |
| 2 | {ISO ts} | — | F2 | FAIL — re-enter Phase 6 |
| 3 | {ISO ts} | — | F1, F3 | PASS |

Total iterations: {N} / 5.
Final decision: {PASS / ACCEPT-KNOWN-ISSUES / ABORT — set by user at halt}.

#### Suite outcomes (final iteration)

| Suite | Ran? | Pass? | Findings | Notes |
|-------|------|-------|----------|-------|
| S1 Baseline & probe | yes | yes | — | — |
| S2 REST scenarios | yes | yes | — | {N} endpoints × {N} scenarios |
| S3 Admin login | yes | yes | — | — |
| S4 Stores Config walk | yes | yes | — | {N} sections walked |
| S5 Admin grids | yes | yes | — | Customers, Catalog Products, Sales Orders + {new} |
| S6 New / changed routes | yes | yes | — | {N} routes covered |
| S7 Customer flows | yes | yes | — | Register / login / {N} My Account tabs |
| S8 Exception.log diff | yes | yes | — | 0 new lines |
| S9 Triage | yes | yes | — | — |

#### Findings (final state)

| ID | Severity | Category | Resolved in iter | Fix delegate | Notes |
|----|----------|----------|------------------|--------------|-------|
| F1 | Critical | rest_contract | 3 | magento2-bug-fix | ACL missing in webapi.xml |
| F2 | Critical | php_exception | 2 | magento2-debug → magento2-bug-fix | Class typo in di.xml |
| F3 | High | frontend | 3 | magento2-frontend-create | KO bind error in vehicle.js |
| F4 | Medium | performance | n/a | magento2-performance-audit | New grid 2.3s; target 2.0s |

#### Artifacts

- Per-iteration reports: `.docs/{FeatureName}/smoke/run-{1..N}.md`
- Consolidated findings: `.docs/{FeatureName}/smoke/findings.md`
- REST scenarios: `.docs/{FeatureName}/smoke/scenarios.md`
- Screenshots: `.docs/{FeatureName}/smoke/screenshots/run-{1..N}/`
- Raw S2 request/response: `.docs/{FeatureName}/smoke/raw/S2/`
- Exception log diff: `.docs/{FeatureName}/smoke/raw/S8/exception-diff.log`

If any Critical/High remains open due to `accept-known-issues`, state that explicitly here and
link the IDs to their entries in §8 Known Limitations.

---

## Formatting Rules

- Use Markdown tables for all structured data.
- Code and class names always in backticks.
- File paths relative to `src/app/code/` unless referencing config paths.
- No more than one level of nested bullets.
- Do not include raw tool output, grep results, or PHPCS logs in the report — summarise findings
  into the relevant sections above.
- The report has **ten** sections, not nine. Section 10 (Smoke Test Results) is mandatory in
  `feature` and `extend` modes, abbreviated in `hotfix` mode (a single paragraph + iteration
  count is acceptable), and omitted in `spike` mode.
