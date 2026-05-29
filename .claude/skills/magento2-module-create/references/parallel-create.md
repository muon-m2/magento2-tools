# Parallel Create

Parallel creation requires explicit user authorization. Offer it when the module meets the threshold
(≥ 4 declared surfaces or ≥ 30 estimated PHP files) and wait for confirmation before spawning agents.
For smaller modules, sequential generation is simpler and avoids coordination overhead.

The main skill owns final synthesis: merge shared files, verify naming consistency across agents, and
ensure no compliance gaps appear at the seams between agents.

---

## When to Use Parallel Create

Authorize parallel create when:
- Module has ≥ 4 declared surfaces
- Estimated PHP file count ≥ 30
- The user explicitly requests parallel or concurrent generation
- Surfaces are largely independent (e.g., REST API + admin UI have minimal shared files)

Do NOT use parallel create when:
- Module is a simple 1–2 surface module
- Surfaces share heavy DI wiring (agents would race on `di.xml`)
- The user wants to review each surface incrementally

---

## Agent Split

| Agent | Surfaces assigned | Model | Primary files |
|---|---|---|---|
| **The Architect** | `persistence`, `service_contracts` | Opus | `Api/`, `Api/Data/`, `Model/`, `Model/ResourceModel/`, `etc/db_schema.xml` |
| **The Builder** | `admin_config`, `rest_api`, `graphql` | Sonnet | `etc/webapi.xml`, `etc/schema.graphqls`, `Model/Resolver/`, `etc/adminhtml/system.xml`, `etc/config.xml` |
| **The Sentinel** | `admin_ui` (controllers + ACL) | Opus | `Controller/Adminhtml/`, `etc/acl.xml`, `etc/adminhtml/routes.xml` |
| **The Presenter** | `admin_ui` (templates), `frontend_ui` | Sonnet | `view/`, layout XML, `ViewModel/`, `etc/frontend/routes.xml` |
| **The Scribe** | tests, i18n, docs | Sonnet | `Test/Unit/`, `i18n/en_US.csv`, `README.md`, `CHANGELOG.md` |

---

## Ownership Rules

- **Shared files are owned by the main skill**, not delegated:
  `registration.php`, `etc/module.xml`, `composer.json`, `etc/di.xml`.
- When agents need DI entries (preferences, plugins, proxies), they return XML `<type>` or `<preference>`
  fragments. The main skill merges these into `etc/di.xml` after all agents complete.
- `etc/acl.xml` is owned by **The Sentinel**. Other agents reference ACL IDs but do not create or edit
  `acl.xml`.
- No agent reads or writes a file owned by another agent.

---

## Agent Prompt Requirements

Each agent prompt must be self-contained. Include:
- `{module_path}`, `{Vendor}`, `{ModuleName}`, `{module_lower}`
- Assigned surfaces and the exact file list from `references/surfaces.md`
- Entity names, service method signatures, and config paths (resolved in Step 2)
- Relevant sections from `references/creation-checklist.md` for assigned categories
- Naming rules from `references/naming-conventions.md`
- Model selection (see below)
- Output format: return completed file content wrapped in `--- FILE: {relative/path} ---` markers

Agents must not assume context from the parent conversation — every piece of information needed must
appear in the prompt.

---

## Model Selection

Use the model IDs current in your environment's CLAUDE.md or system context. As of 2026-05:
- `claude-opus-4-7` → The Architect, The Sentinel (architecture, DI wiring, security patterns)
- `claude-sonnet-4-6` → The Builder, The Presenter, The Scribe (implementation, templates, tests)

Check CLAUDE.md for updated IDs before spawning agents — model names change across Claude generations.

---

## Post-Merge Verification

After collecting all agent outputs:
1. Run `scripts/verify-created.sh` on the merged module path.
2. Check `etc/di.xml` for duplicate type/preference entries from multiple agents.
3. Verify all controller `ADMIN_RESOURCE` values match the ACL IDs in `etc/acl.xml`.
4. Verify all `webapi.xml` handler FQCNs reference interfaces in `Api/` (not concrete classes).
5. Verify DTO extension-attribute PHPDoc matches between `Api/Data/` interface and `Model/` implementation.

---

## Conflict Resolution

When two agents produce overlapping content for the same file:
1. **The more specific file wins.** `etc/adminhtml/di.xml` takes precedence over `etc/di.xml` for
   admin-only DI entries.
2. **Merge don't replace for XML configuration.** Combine `<type>`, `<preference>`, and `<plugin>`
   entries from all agents into one coherent file; check for duplicates by `name` attribute.
3. **Naming conflicts**: use `references/naming-conventions.md` as the tiebreaker — the compliant name
   wins regardless of which agent generated it.
4. **Escalate unresolvable conflicts**: if two agents produce structurally incompatible approaches
   (e.g., different table schemas for the same entity), report both to the user and ask for a decision
   before finalising.
