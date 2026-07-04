# Documentation Guide (Step 6)

Step 6 is the **documentation step**: it produces the module's documentation set so it reflects the
code as actually generated, **before** Step 7 writes the report. A module is not "done" until its
docs exist on disk and are current — documentation is a required deliverable, not an optional extra.

Because this skill **works without a running Magento instance**, the documentation set is
**code-derived / static**: every artifact is generated from the files just created, not from a live
system. Where an artifact genuinely needs a running instance (screenshots), insert a clearly marked
placeholder that names the screen to capture post-deploy — never fabricate it.

Step 6 is **full** in a normal create, **reduced** in Quick Create Mode (README + CHANGELOG +
`docs/technical-reference.md`), and **refresh-only** in `--mode=augment` (update the docs the new
surfaces touch).

---

## Format and location

In-module documentation is **Markdown**, consistent with this module's `README.md`, `CHANGELOG.md`,
and the `magento2-docs-generate` output. The set lives **inside the module**:

| Artifact | Scope | Location | Required when |
|----------|-------|----------|---------------|
| `README.md` | Overview | `{module}/README.md` | Always (minimal stub in Step 2; regenerated in full here via `magento2-docs-generate`) |
| `CHANGELOG.md` | History scaffold | `{module}/CHANGELOG.md` | Always |
| `docs/technical-reference.md` | Technical | `{module}/docs/technical-reference.md` | Always (delegate to `magento2-docs-generate`) |
| `docs/developer-guide.md` | Developer | `{module}/docs/developer-guide.md` | When the module exposes a public surface (service contracts, REST/GraphQL, events, plugins) |
| `docs/user-guide.md` | User / admin | `{module}/docs/user-guide.md` | When the module declares `admin_config`, `admin_ui`, or `frontend_ui` |
| `docs/screenshots/` | User / admin | `{module}/docs/screenshots/` | When an admin/storefront UI surface is declared |
| `docs/api-examples/` | Developer | `{module}/docs/api-examples/` | When `rest_api` or `graphql` is declared |
| `docs/artifacts/` | Helpful extras | `{module}/docs/artifacts/` | As the module's surfaces warrant |

---

## Per-scope content

The full module documentation set — `README.md`, `CHANGELOG.md`, `docs/technical-reference.md`,
`docs/developer-guide.md` (when the module exposes a public surface), and `docs/user-guide.md`
(when a UI/config surface is declared) — is **delegated in full** to `magento2-docs-generate` for
the module just created:

```
Skill: magento2-docs-generate
Args: --module={Vendor}_{ModuleName}
```

Re-running it is how every artifact in the set stays **current** after any later change.
`magento2-docs-generate` owns the section structure, per-surface omission rules, and content
derivation for each artifact — see its `references/doc-structure.md`. This skill does not
hand-write README, CHANGELOG, technical-reference, developer-guide, or user-guide content; the
extracted public `@api` surface, events, plugins, preferences, config paths, CLI commands, cron
jobs, REST/GraphQL routes, and DB schema all come from `magento2-docs-generate`'s own extraction.

---

## Screenshots

Screenshots are required wherever the module declares an admin or storefront UI surface.

1. **When a running instance is available** (the module has been deployed for a smoke check, or the
   user supplies one): capture each significant admin/storefront screen and save to
   `docs/screenshots/`. Reference each with a relative path and a one-line caption.
2. **When no instance is available** (the default for this skill): insert a clearly marked
   placeholder in the user guide naming the exact screen to capture — e.g.
   `<!-- SCREENSHOT: Admin → Stores → Configuration → {Section} (config form) -->` — and list these
   under a "Screenshots to capture after deploy" heading. Do **not** fabricate images.

---

## API request / response payload examples

Include payload examples only when the module declares a `rest_api` or `graphql` surface.

- Derive the examples from the **contract** — `etc/webapi.xml` routes + the `Api/Data` DTO shapes
  (or `schema.graphqls` for GraphQL). Mark them **representative** (contract-derived), since this
  skill has no running instance to capture live traffic.
- Save one file per endpoint/operation under `docs/api-examples/` and reference them from the
  developer guide.
- For each: method + route (or query/mutation name), required auth/ACL, a representative request
  body, and the corresponding success response. Add one error response (validation or auth) where
  it clarifies the contract.
- Use placeholder values; never embed real secrets, tokens, or PII.

---

## Other helpful artifacts

Add what the module's surfaces warrant, under `docs/artifacts/`:

- A **Postman collection** (or `.http` file) derived from `etc/webapi.xml`.
- An **ER diagram** (Mermaid `erDiagram`) derived from `etc/db_schema.xml` when persistence exists.
- A **sequence diagram** for a non-obvious flow (e.g. a queue consumer or plugin chain).

Omit any artifact that does not apply — do not create empty placeholder files.

---

## Per-mode scope

| Mode | Step 6 scope |
|------|--------------|
| Normal create | Full set via one `magento2-docs-generate` delegation call: README, CHANGELOG, technical reference, developer guide (when a public surface exists), user guide + screenshots (when a UI surface exists); plus API examples (when REST/GraphQL) and applicable artifacts, written separately by this skill. |
| Quick Create | Reduced: `README.md` + `CHANGELOG.md` + `docs/technical-reference.md` — matches what `magento2-docs-generate` always produces for a surface-less module. State that the rest of the full doc set (developer/user guides, API examples) is generated when surfaces are added. |
| `--mode=augment` | Refresh-only: re-run `magento2-docs-generate` (refreshes README/CHANGELOG/technical-reference/developer-guide/user-guide) and refresh the API examples for the surfaces the augment added. Never leave a doc describing the pre-augment module. |

---

## Completeness checklist (the Step 6 gate)

Step 7 may not start until, **for the current mode's scope**, all of the following hold:

- [ ] `magento2-docs-generate` has been run for the module; `README.md`, `CHANGELOG.md`, and
      `docs/technical-reference.md` exist with no unfilled `{placeholders}`.
- [ ] `docs/developer-guide.md` exists when the module exposes a public surface.
- [ ] `docs/user-guide.md` exists when a UI/config surface is declared.
- [ ] Screenshots (or named placeholders) exist for every admin/storefront screen the user guide
      references.
- [ ] If `rest_api`/`graphql` is declared, `docs/api-examples/` holds a request+response example per
      endpoint/operation, with secrets/PII redacted.
- [ ] Every document reflects the code as generated — nothing describes a surface that was not created.
