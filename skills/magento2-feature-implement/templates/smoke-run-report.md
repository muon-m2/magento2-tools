# Smoke Run — Iteration {N}

Feature: {FeatureName}
Date: {YYYY-MM-DDTHH:MM:SSZ}
Iteration: {N} / 5
Base URL: {url}
Triggered by: magento2-feature-implement Phase 6B

---

## Probe Summary (S1)

| Probe | Result |
|-------|--------|
| Base URL | {url} |
| Admin URL | {/admin or resolved fragment} |
| Admin user | {user} (password from {CLAUDE.md / env / prompt}) |
| HTTP client | curl {version} / php-curl / unavailable |
| Browser | playwright {ver} / puppeteer {ver} / google-chrome {ver} / unavailable |
| jq | {ver} / unavailable |
| `exception.log` size at baseline | {bytes} bytes |
| Production guard | {passed / overridden via CLAUDE.md} |

Skipped suites: {S2, S7, … with one-sentence reason each, or "none"}.

---

## S2 — REST API Scenarios

Total scenarios: {N} | Passed: {N} | Failed: {N}

| # | Endpoint | Scenario | Expect | Actual | Severity | Finding ID |
|---|----------|----------|--------|--------|----------|------------|
| 1 | POST /V1/{vendor}/xyz | Happy path | 200 | 200 | — | — |
| 2 | POST /V1/{vendor}/xyz | Missing auth | 401 | 200 | Critical | F1 |
| 3 | GET /V1/{vendor}/xyz/:id | Not found | 404 | 500 | Critical | F2 |

Raw request/response: `smoke/raw/S2/*.txt`.
Full scenarios: `smoke/scenarios.md`.

---

## S3 — Admin Login

- Outcome: {passed / failed}
- Response status: {200}
- Console errors: {none / list}
- Screenshot: `smoke/screenshots/run-{N}/admin-login.png`

---

## S4 — Stores → Configuration

| Section | Loaded | Field changed | Save status | Reverted | Severity |
|---------|--------|---------------|-------------|----------|----------|
| `{vendor}/general` | yes | `enabled` | 200 | yes | — |
| `{vendor}/api` | yes | `timeout_ms` | 500 | n/a | High |

---

## S5 — Admin Grids

| Grid | Rendered | Filter applied | Rows after filter | Cleared | Console errors | Severity |
|------|----------|----------------|-------------------|---------|----------------|----------|
| Customers | yes | name=Smith | 3 | yes | none | — |
| Catalog Products | yes | sku contains TEST | 12 | yes | none | — |
| Sales Orders | yes | status=processing | 5 | yes | 1 (KO bind) | Medium |
| {New grid added by feature} | yes | … | … | … | none | — |

---

## S6 — New / Changed Routes

| Route | Type | Render | Primary CTA clicked | Result | Console errors | Severity |
|-------|------|--------|---------------------|--------|----------------|----------|
| `/admin/{vendor}/xyz/index` | admin | 200 | New entity | 200 | none | — |
| `/{vendor}/xyz/account` | frontend | 200 | Update | 500 | 1 (uncaught) | Critical |

---

## S7 — Customer Storefront Flows

| Step | Result | Console errors | Severity |
|------|--------|----------------|----------|
| Registration | succeeded — id 1234 | none | — |
| Logout | succeeded | none | — |
| Login | succeeded | none | — |
| My Account → Account Information | rendered | none | — |
| My Account → Address Book | rendered | 1 (warn — ignored) | — |
| My Account → My Orders | rendered | none | — |
| My Account → {new tab added by feature} | failed to load | 1 (error) | High |

Throwaway customer: `smoke+a1b2c3@example.test` — cleaned up in S9.

---

## S8 — Exception Log Diff

- Baseline offset: {bytes} (captured S1)
- Live size at S8: {bytes}
- Diff size: {bytes}
- Rotated: {no / yes — note}

| Group | First line | Source path (best guess) | Matched allowlist? | Severity |
|-------|------------|--------------------------|--------------------|----------|
| 1 | `[2026-05-28 10:18:42] main.CRITICAL: Class ... not found` | `Vendor\Xyz\Controller\…` | no | Critical |

Diff file: `smoke/raw/S8/exception-diff.log`.

---

## S9 — Triage

### New findings this iteration

| ID | Severity | Category | Source suite | Summary | Fix delegate |
|----|----------|----------|--------------|---------|--------------|
| F1 | Critical | rest_contract | S2 | POST /V1/xyz returns 200 for unauthenticated request | magento2-bug-fix |
| F2 | Critical | rest_contract | S2 | GET 404 case throws 500 stack trace | magento2-bug-fix + magento2-debug |
| F3 | High | frontend | S7 | New My Account tab fails to load | magento2-frontend-create |
| F4 | Critical | php_exception | S8 | Controller class not found | magento2-debug → magento2-bug-fix |

### Recurring findings (same ID as prior iteration)

{None this iteration / list with iteration of first sighting}

### Outcome

- Critical: {N}   High: {N}   Medium: {N}   Low: {N}
- **Decision:** {PASS — proceed to Phase 7 / FAIL — fix Critical/High and re-enter Phase 6 / HALT — iteration cap reached}
- Next action: {description}

Iteration counter after this run: {N} / 5.
