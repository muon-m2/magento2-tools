# REST API Scenarios

Generated from blueprint §3 (Public API) and §6 (REST endpoints) at the start of Phase 6B.
Re-executed on every Phase 6 iteration. Only the **Actual** and **Pass** columns change between
iterations — the scenario set itself is stable for the whole feature.

Each endpoint gets at minimum: happy path, missing-auth, wrong-ACL, validation error, not-found
(for GET/PUT/DELETE), pagination (for list endpoints). Additional scenarios may be added per
endpoint based on documented behaviour in the blueprint.

---

## Endpoint: {METHOD} {/V1/{vendor_lower}/{route}}

ACL: `{Vendor}_{Module}::{permission}`
Handler: `{Vendor}\{Module}\Api\{Interface}::{method}`
Blueprint reference: §6 row {N}

### Scenarios

| # | Scenario | Auth | Body | Query | Expect status | Expect body match | Actual | Pass |
|---|----------|------|------|-------|---------------|-------------------|--------|------|
| 1 | Happy path | admin token | `{"name":"smoke-1"}` | — | 200 | `.id != null` | — | — |
| 2 | Missing auth | none | `{"name":"smoke-1"}` | — | 401 | — | — | — |
| 3 | Wrong ACL | customer token | `{"name":"smoke-1"}` | — | 403 | — | — | — |
| 4 | Validation error — missing required | admin token | `{}` | — | 400 | `.message contains "required"` | — | — |
| 5 | Validation error — bad type | admin token | `{"name":123}` | — | 400 | `.message contains "string"` | — | — |
| 6 | Not found | admin token | — | `id=99999999` | 404 | — | — | — |
| 7 | Pagination — first page | admin token | — | `searchCriteria[pageSize]=2&searchCriteria[currentPage]=1` | 200 | `.items \| length == 2` | — | — |
| 8 | Pagination — past last page | admin token | — | `searchCriteria[currentPage]=99999` | 200 | `.items \| length == 0` | — | — |

### Notes

- `Expect body match` uses jq path syntax when jq is available, falling back to regex.
- `customer token` references the throwaway customer created in S7 (`smoke+{uuid}@example.test`).
  S2 creates this customer inline if S7 has not yet run.
- Scenarios may be added for endpoint-specific behaviour (e.g. quote merging, attribute filtering).
  Do not delete the six baseline scenarios above unless the endpoint genuinely cannot exhibit that
  behaviour — document the omission in a `Skipped:` line under the table.

---

## Endpoint: {METHOD} {/V1/...}

{repeat the section above per endpoint}
