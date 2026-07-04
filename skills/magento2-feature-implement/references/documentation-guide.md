# Documentation Guide (Phase 7A)

Phase 7A is the **documentation step**: it produces — or refreshes — the feature's complete
documentation set so it reflects the code as actually built, **before** Phase 7B writes the final
report. It runs after Phase 6 (tests + smoke) and gates Phase 7B.

Phase 7A is **mandatory** in `feature` mode, **reduced** in `hotfix` / `extend` modes, and
**skipped** in `spike` mode (see `modes.md`). Documentation is a required deliverable, not an
optional extra — a feature is not "done" until its docs exist on disk and are current.

---

## The Documentation Set

Every required artifact maps to a scope. The set spans three scopes — **technical**, **developer**,
and **user** — plus screenshots and (when the feature has an API) request/response payload examples.

| Artifact | Scope | Location | Required when |
|----------|-------|----------|---------------|
| `{module}/README.md` + `{module}/docs/technical-reference.md` + `{module}/CHANGELOG.md` | Technical (per-module) | Inside each created/modified module | Always (one set per module) |
| `spec.md` | Technical (cross-module) | `.docs/{FeatureName}/spec.md` | `feature` mode; `extend` when a new surface changes the design |
| `guides/developer-guide.html` | Developer | `.docs/{FeatureName}/guides/` | `feature` / `extend` |
| `user-docs/user-guide.html` | User / admin | `.docs/{FeatureName}/user-docs/` | `feature` / `extend` |
| `user-docs/screenshots/` | User / admin | `.docs/{FeatureName}/user-docs/screenshots/` | When the feature has an admin or storefront UI |
| `api-examples/` | Developer | `.docs/{FeatureName}/api-examples/` | When the feature exposes a REST or GraphQL surface |
| `artifacts/` | Helpful extras | `.docs/{FeatureName}/artifacts/` | As the module's scope warrants |

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under `{ctx.magento_root}`,
`app/code`, or a module directory — see the **Artifact location** rule in `magento2-context/SKILL.md`.

---

## Per-scope content

### Technical — per-module reference

Delegate to `magento2-docs-generate` for every module created or modified. It extracts the
public `@api` surface, events fired/observed, plugins, preferences, config paths, CLI commands,
cron jobs, REST/GraphQL routes, DB schema, and dependencies straight from the module's own code,
and renders `README.md`, `docs/technical-reference.md`, and a `CHANGELOG.md` scaffold.

```
Skill: magento2-docs-generate
Args: --module={Vendor}_{Module} --docs-root=.docs/{FeatureName}
```

Because it reads from code, re-running it is how docs stay **current** after each change. The
`{module}/README.md`, `{module}/docs/technical-reference.md`, and `CHANGELOG.md` scaffold are
written inside the module as usual; the run's own report now lands under
`.docs/{FeatureName}/docs-generated/` instead of the global `.docs/docs-generated/`, per the
**One artifact home** Core Rule and `magento2-context/references/artifact-layout.md`.

### Technical — cross-module spec

`spec.md` is the feature-level technical reference that no single module owns: the architecture,
the data model, how the modules interact, the extension points, and sequence/flow diagrams. All
diagrams are **Mermaid** (per the Core Rules). Keep it factual — link to the per-module
technical references rather than restating them.

### Developer guide

`guides/developer-guide.html` — how a developer **integrates with and extends** the feature:

- Service contracts and DTOs they call, with signatures.
- Events they can observe and plugins/preferences they can attach.
- DI wiring and configuration knobs that affect behaviour.
- Worked code examples (the smallest real snippet that demonstrates each integration point).
- When the feature exposes a REST/GraphQL surface: request/response payload examples (see below).

### User guide

`user-docs/user-guide.html` — how an **admin or end user** configures and uses the feature:

- Admin configuration: where the settings live (Stores → Configuration path), what each does.
- End-user / storefront workflows, step by step.
- **Screenshots** of each significant screen (see below).

Both HTML guides must apply the feature's shared CSS color schema inline (primary, secondary,
background, text, accent), defined once for the feature and identical across every HTML file —
per the **Guides and user docs are HTML** Core Rule.

---

## Screenshots

Screenshots are required wherever the feature has an admin or storefront UI.

1. **Reuse Phase 6B captures first.** Phase 6B (S6 routes, S3 admin login, S7 customer flows)
   already writes screenshots to `.docs/{FeatureName}/smoke/screenshots/run-{N}/`. Copy the
   relevant ones into `user-docs/screenshots/` and embed them in the user guide.
2. **Capture fresh ones for gaps.** If a screen the user guide needs was not exercised by smoke,
   capture it with the smoke browser driver (`${CLAUDE_SKILL_DIR}/scripts/smoke-browser.mjs`)
   against the same Base URL/credentials the S1 probe resolved.
3. Reference each image with a relative path and a one-line caption stating what the reader is
   looking at.

---

## API request / response payload examples

When — and only when — the feature exposes a REST or GraphQL surface, include real payload
examples. Module scope decides whether this section exists at all.

- **Reuse the smoke raw captures.** Phase 6B S2 saves real request/response pairs under
  `.docs/{FeatureName}/smoke/raw/S2/`. Use those as the basis so the examples match the running
  contract rather than the design intent.
- Save curated, redacted examples under `api-examples/` (one file per endpoint or operation),
  and reference them from the developer guide.
- For each endpoint/operation document: method + route (or query/mutation name), required auth/ACL,
  a representative request body, and the corresponding success response. Add one error response
  (validation or auth) where it clarifies the contract.
- Redact secrets, tokens, and PII before saving.

---

## Other helpful artifacts

Add what the module's scope warrants, under `artifacts/`:

- A **Postman collection** (or `.http` file) for the REST surface.
- An **ER diagram** (Mermaid `erDiagram`) when the feature adds persistence.
- A **sequence diagram** for a non-obvious multi-module flow.
- **Sample data / fixtures** referenced by the guides.

Omit any artifact that does not apply — do not create empty placeholder files.

---

## Updated, not stale

The documents **must be current**. On a resume or `extend` run, **refresh** existing documents to
match the final code — never leave a previously generated doc describing an earlier design:

- Re-run `magento2-docs-generate` for every module touched this run.
- Update `spec.md`, the developer guide, and the user guide for any surface that changed.
- Re-capture any screenshot whose screen changed.

A doc that describes code that no longer exists is a defect, not documentation.

---

## Per-mode scope

| Mode | Phase 7A scope |
|------|----------------|
| `feature` | Full set: per-module docs via `magento2-docs-generate`, `spec.md`, developer + user HTML guides with screenshots, API payload examples when a REST/GraphQL surface exists, plus applicable artifacts. |
| `extend` | Update the affected module's docs; refresh the developer/user guide sections the new surface touches; add API examples if the surface is REST/GraphQL. `spec.md` only if the design changed. |
| `hotfix` | Reduced: refresh the touched module's `technical-reference.md` + add a `CHANGELOG.md` note. No full guide set unless the hotfix changed admin/API behaviour a user or developer relies on. |
| `spike` | Skipped. The promotion checklist must list "generate full documentation in `feature` mode" as a merge prerequisite. |

---

## Completeness checklist (the Phase 7A gate)

Phase 7B may not start until, **for the current mode's scope**, all of the following hold:

- [ ] `magento2-docs-generate` has been run for **every** module created or modified this run, and
      the output exists on disk.
- [ ] `spec.md` exists and its diagrams are Mermaid (when required for the mode).
- [ ] `guides/developer-guide.html` and `user-docs/user-guide.html` exist (when required), share the
      feature's CSS color schema, and contain no unfilled placeholder text.
- [ ] Screenshots exist for every admin/storefront screen the user guide references.
- [ ] If the feature exposes a REST/GraphQL surface, `api-examples/` holds a request+response
      example per endpoint/operation, with secrets/PII redacted.
- [ ] Every document reflects the **final** code — nothing describes a superseded design.
