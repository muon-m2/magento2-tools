Status: Awaiting Approval

# {Feature Name} — Feature Blueprint

Date: {YYYY-MM-DD}
Requested by: {user or team}
Skill versions:

- magento2-feature-implement@2.10.1
- magento2-context@1.7.0

---

## 1. Problem Statement

{One to three sentences describing the business or technical problem. No solution language.}

---

## 2. Solution Overview

{High-level description of the approach. Name the Magento areas touched (catalog, checkout, customer,
order, inventory, EAV, etc.) and explain why this approach fits the problem.}

---

## 3. Public API Surface

| Type | Identifier | Methods / Route | ACL | New / Modified |
|------|-----------|-----------------|-----|----------------|
| Interface | `{Vendor}\{Module}\Api\{Entity}RepositoryInterface` | `save`, `getById`, `delete`, `getList` | `{Vendor}_{Module}::view` | New |
| REST | `GET /V1/{vendor_lower}/{route}/:id` | — | `{Vendor}_{Module}::view` | New |

---

## 4. Data Model

### New Tables

| Table | Purpose |
|-------|---------|
| `{vendor_lower}_{module}_{entity}` | {description} |

#### `{vendor_lower}_{module}_{entity}`

| Column | Type | Nullable | Index | Notes |
|--------|------|----------|-------|-------|
| `entity_id` | int unsigned | No | PK, AI | |
| `{field}` | varchar(255) | No | | |
| `created_at` | timestamp | No | | |
| `updated_at` | timestamp | No | | |

### Modified Tables

Omit this section entirely if no existing tables are modified.

| Table | Change | Reason |
|-------|--------|--------|
| `{existing_table}` | Add column `{col}` | {reason} |

### Data Patches

| Patch class | Purpose | Depends on |
|-------------|---------|------------|
| `Setup\Patch\Data\{Name}` | {purpose} | `{OtherPatch}` or none |

---

## 5. Admin Configuration

| Config path | Type | Default | Sensitive | Purpose |
|-------------|------|---------|-----------|---------|
| `{vendor_lower}_{module}/general/enabled` | Yes/No | 1 | No | Feature toggle |

ACL resource for all sections: `{Vendor}_{Module}::config`

---

## 6. REST and GraphQL Endpoints

### REST

| Method | Route | Handler | ACL | Request DTO | Response DTO |
|--------|-------|---------|-----|-------------|--------------|
| `GET` | `/V1/{vendor_lower}/{route}/:id` | `{Interface}::getById` | `{Vendor}_{Module}::view` | — | `{Entity}Interface` |
| `POST` | `/V1/{vendor_lower}/{route}` | `{Interface}::save` | `{Vendor}_{Module}::manage` | `{Entity}Interface` | `{Entity}Interface` |

### GraphQL

| Type | Name | Resolver | Auth |
|------|------|----------|------|
| Query | `{vendor_lower}{Entity}` | `Model\Resolver\{Entity}` | Customer session |

---

## 7. Events and Observers

| Event name | Dispatched / Observed | Observer class | Data payload |
|------------|----------------------|----------------|--------------|
| `{vendor_lower}_{module}_{entity}_save_after` | Dispatched | — | `{entity}` object |
| `{magento_event}` | Observed | `Observer\{Name}` | {relevant keys} |

---

## 8. Cron and Queue Jobs

### Cron

| Job name | Schedule | Module | Idempotent? |
|----------|----------|--------|-------------|
| `{vendor_lower}_{module}_{description}` | `0 2 * * *` | `{Vendor}_{Module}` | Yes — skips already-processed records |

### Queue

| Topic | Consumer | Message schema | Retry strategy |
|-------|----------|---------------|----------------|
| `{vendor_lower}.{module}.{topic}` | `Model\Consumer\{Name}` | `{Entity}Interface` | Reject + dead letter after 3 attempts |

---

## 9. Security Considerations

- **Input validation:** {which inputs validated and how}
- **Output escaping:** {where user-controlled data appears in templates; escaper method used}
- **ACL:** {which resources protect which operations}
- **CSRF:** {which POST actions have form key validation}
- **Sensitive data:** {tokens/PII handled — storage method}
- **SQL:** {confirm parameterised queries only, or explain any exception}

---

## 10. Performance Implications

- **N+1 risk:** {list loops that load entities and mitigation, or "None identified"}
- **Cache impact:** {which caches are invalidated; are invalidations targeted or full?}
- **Indexer impact:** {new indexers or existing indexers affected, or "None"}
- **Data volume:** {expected row counts and growth rate for new tables, or "N/A"}

---

## 11. Dependencies

| Module | Type | Reason |
|--------|------|--------|
| `Magento_Catalog` | require | Uses `ProductRepositoryInterface` |
| `{Vendor}_Core` | require | Inherits base config patterns |

---

## 12. Open Questions

| # | Question | Impact | Default assumption |
|---|----------|--------|-------------------|
| 1 | {Question text} | {What changes if answered differently} | ASSUMPTION: {default} |

