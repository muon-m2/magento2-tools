# Feature Blueprint Format

A feature blueprint must be complete before any code is written. Load this file during Phase 2 to
validate that every required section is present before saving the blueprint.

---

## Required Sections

Every blueprint must contain all twelve sections below. A section may not be omitted — use "None"
or "N/A" with a brief justification when a section genuinely does not apply.

### 1. Problem Statement

One to three sentences describing the business or technical problem this feature solves.
Avoid solution language — describe only the gap or pain point.

### 2. Solution Overview

High-level description of the approach. Explain the main concept without listing files or classes.
Mention which Magento area (catalog, checkout, customer, order, inventory, EAV, etc.) the feature
touches and why.

### 3. Public API Surface

List every interface, service contract, REST endpoint, and GraphQL type that external callers
(including other modules) will depend on. For each item specify:

- Interface or endpoint path
- Method signatures (parameters + return types, no implementation detail)
- ACL resource ID
- Whether it is new or modifying an existing contract

If no public API is exposed, state "No public API" and justify why (e.g. internal-only cron job).

### 4. Data Model

Describe every database table affected:

- New tables: name (following `{vendor_lower}_{module_lower}_{entity}` convention), columns,
  indexes, foreign keys
- Modified tables: which columns are added, removed, or changed and why
- Data patches: what seed data is needed and in which order

If no database changes, state "No schema changes".

### 5. Admin Configuration

List every `system.xml` section, group, and field required:

- Config path (`{vendor_lower}_{module_lower}/{group}/{field}`)
- Type (text, select, obscure, etc.)
- Default value (must be production-safe)
- ACL resource protecting the section

If no admin config, state "No admin configuration".

### 6. REST and GraphQL Endpoints

For REST: method, route, handler interface, ACL resource, request/response DTO types.
For GraphQL: query or mutation name, schema type, resolver class, auth requirements.

If neither is needed, state "No API endpoints".

### 7. Events and Observers

List every Magento event this feature dispatches or observes:

- Event name (dispatched: new; observed: existing Magento event)
- Observer class
- Purpose and data passed in the event

If none, state "No events".

### 8. Cron and Queue Jobs

For cron: job name, schedule, idempotency guarantee, what it does if interrupted.
For queue: topic name, consumer class, message schema, error handling strategy.

If none, state "No async jobs".

### 9. Security Considerations

Address each point explicitly (do not skip any):

- Input validation: which inputs are validated and how
- Output escaping: where user-controlled data appears in templates
- ACL: which admin/REST resources protect which operations
- CSRF: which POST actions are protected
- Sensitive data: any secrets, tokens, or PII handled — how they are stored
- SQL: confirm parameterised queries only

### 10. Performance Implications

Address each point:

- N+1 query risk: list any loops that load entities and mitigation
- Cache impact: which Magento caches are affected; are invalidations targeted?
- Indexer impact: are new indexers needed or existing ones affected?
- Expected data volume: approximate row counts and growth rate for new tables

### 11. Dependencies

List every module (Magento core and project modules) this feature depends on:

- Module name (`Vendor_Module`)
- Whether the dependency is `require` (hard) or `suggest` (soft)
- Which class or interface triggers the dependency

### 12. Open Questions

Unresolved design decisions that the user must answer before implementation. Each entry:

- Question text
- Impact of each possible answer on scope or architecture
- Default assumption if user does not answer (mark clearly as ASSUMPTION)

---

## Completeness Checklist

Before saving the blueprint, verify:

- [ ] All 12 sections present (no section omitted without explicit justification)
- [ ] Public API section lists full method signatures, not just class names
- [ ] Table names follow `{vendor_lower}_{module_lower}_{entity}` convention
- [ ] Every REST route has an ACL resource specified
- [ ] Security section addresses all 6 sub-points
- [ ] No open questions remain unresolved that would block Phase 3 (module schema)

---

## Blueprint File Path and Status Line

Save every blueprint to:

```
.docs/{FeatureName}/blueprint.md
```

This path is anchored at the **project working directory** (`{ctx.docs_root}` =
`{project_root}/.docs`), per the **Artifact location** rule in `magento2-context/SKILL.md`.
Never write it under `{ctx.magento_root}` (e.g. `src/`), `app/code`, or a module directory.

**Save before present.** The blueprint must be written to disk and confirmed to exist *before*
it is shown to the user — never present a blueprint that lives only in the chat. The user
reviews the file. After saving, cite the path in the message.

Add a status line as the first line of the file (before the title):

```
Status: Awaiting Approval | Approved | In Progress | Complete
```

Update the status line as the feature progresses through phases.

---

## Size Guidance

- Minimum viable blueprint: 400–600 words across all sections.
- Complex features (3+ modules, REST + GraphQL, queue): expect 800–1500 words.
- Do not pad — each section should contain only what is needed to make Phase 3 decisions.
