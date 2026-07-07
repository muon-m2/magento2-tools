---
name: magento2-docs-generate
description:
    Generate or refresh a module's technical documentation from its own code — public
    @api surface, events, plugins, REST/GraphQL routes, DB schema, dependencies — plus
    a README, developer guide, user guide (when a user surface exists), REST API reference
    (when REST routes exist), GraphQL reference (when GraphQL ops exist), technical
    reference, and CHANGELOG scaffold with illustrative examples derived from the schema.
    Use for 'document this module' / 'generate module docs'. Read-only analysis; writes
    Markdown only. For an architecture/quality review use `magento2-module-review`.
---

# Magento 2 Docs Generate

Read-only skill — extracts a module's public surface from its own code and XML files,
then renders Markdown documentation. Unlike `magento2-module-review` (which performs an
architecture/quality review), this skill generates human-readable documentation artifacts.
It **never** modifies PHP or XML files.

## Core Rules

- **NEVER invent facts.** Every documented item is extracted from a real file on disk.
  Each entry in the generated docs cites its source file path.
- **`@api` marks the public contract.** Only classes and interfaces annotated `@api`
  appear in the API Surface section.
- **OMIT empty surfaces.** If a surface (events, plugins, REST routes, etc.) has no
  entries, that section is omitted entirely. No empty tables; no placeholder text.
- **Markdown only.** This skill never modifies PHP, XML, JSON, or any non-Markdown file.
  Output is the set of Markdown docs selected in Phase 1 (README, technical reference,
  developer/user guides, REST/GraphQL references, CHANGELOG scaffold — each produced only
  when applicable), plus a run report under `{output_root}/docs-generated/`.
- **Illustrative examples only.** JSON example blocks are generated from real DTO or
  GraphQL field types (names and types extracted from the schema). Every such block must
  carry the caption `> Example — illustrative, generated from the schema` immediately
  before the fenced block. Examples never assert actual runtime data or behaviour.
- **No screenshot embeds.** Image embeds (`![]()`) are never written. Instead, include
  a "Screenshots to capture" appendix that lists navigation paths and suggested
  `docs/screenshots/<name>.png` filenames so a human can supply the images later.
- **Mermaid from facts only.** Every Mermaid diagram is generated strictly from extracted
  facts (surfaces, dependencies, routes). No edges, nodes, or labels may be invented.
  See `${CLAUDE_SKILL_DIR}/references/doc-structure.md` for Mermaid recipes.
- **Derived error models.** Error envelopes and HTTP status mappings are derived from
  Magento conventions (REST: `{"message":"…","parameters":{}}` envelope + standard HTTP
  codes; GraphQL: `errors[].message` + `extensions.category`). They are never invented.
- **Source of truth.** Derive output only from the target module's own code plus templates, shared
  references, and baked-in Magento 2 knowledge (official Magento/Adobe docs live-fetched only when
  uncertain). Do NOT read or "study" *other* modules under `app/code`/`vendor/*`/Magento core to
  infer conventions. See `magento2-context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture
the JSON as `{ctx}`. Hard-stop with a clear message if:

- `{ctx.magento_root}` is unresolved (cannot locate module files without it).
- The target module directory does not exist under
  `{ctx.magento_root}/app/code/{Vendor}/{Module}` (and is not found in `vendor/`).

### Phase 1 — Scope

Determine:

1. **Which module** — from the user's request or via `--module=Vendor_Module`.
   Resolve the absolute module path.
2. **Which docs to produce** — any combination of:
   - `readme`               → `{module}/README.md`
   - `technical-reference`  → `{module}/docs/technical-reference.md`
   - `developer-guide`      → `{module}/docs/developer-guide.md`
   - `user-guide`           → `{module}/docs/user-guide.md`            (only if a user surface exists)
   - `api-reference`        → `{module}/docs/api-reference.md`         (only if REST routes exist)
   - `graphql-reference`    → `{module}/docs/graphql-reference.md`     (only if GraphQL operations exist)
   - `changelog`            → `{module}/CHANGELOG.md` (scaffold only; no history invented)
   Default: produce every applicable doc. Omit `user-guide` when no user surface is
   present, `api-reference` when no REST routes exist, and `graphql-reference` when no
   GraphQL operations are found.

### Phase 2 — Extract Surface (GATE)

Run `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` with the module path, which:

- Greps/parses each XML and PHP source file listed in
  `${CLAUDE_SKILL_DIR}/references/surface-extraction.md`.
- Emits a surface JSON: which surfaces exist, their entries, and source file paths.
- Is strictly READ-ONLY — it never mutates files and never installs anything.

From the surface JSON, present the **doc plan** to the user:

- Which docs will be written and why.
- Which surfaces were found: events: N, plugins: N, REST routes: N, api_methods: N,
  GraphQL ops: N, user surface: yes/no (breakdown: admin_config/admin_ui/storefront/emails).
- Which surfaces are absent and will be omitted.
- Which of the new docs (`developer-guide`, `user-guide`, `api-reference`,
  `graphql-reference`) will be produced or omitted, with the reason for each omission.

**WAIT for "proceed" before writing any files.**

### Phase 3 — Render

Fill the chosen templates with extracted facts:

- `${CLAUDE_SKILL_DIR}/templates/readme.md` → `{module}/README.md`
- `${CLAUDE_SKILL_DIR}/templates/technical-reference.md` → `{module}/docs/technical-reference.md`
- `${CLAUDE_SKILL_DIR}/templates/developer-guide.md` → `{module}/docs/developer-guide.md`
- `${CLAUDE_SKILL_DIR}/templates/user-guide.md` → `{module}/docs/user-guide.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/api-reference.md` → `{module}/docs/api-reference.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/graphql-reference.md` → `{module}/docs/graphql-reference.md` (conditional)
- `${CLAUDE_SKILL_DIR}/templates/changelog-scaffold.md` → `{module}/CHANGELOG.md`

Follow the section order, example-derivation rules, error-model conventions,
screenshot-appendix format, and Mermaid recipes defined in
`${CLAUDE_SKILL_DIR}/references/doc-structure.md`.

Each table row in the technical reference must include the source file path so readers
can verify the documentation against the code.

### Phase 4 — Verify

Before saving any file:

- No unsubstituted `{tokens}` remain in the output.
- Internal links (e.g. `[API Surface](#api-surface)`) resolve within the document.
- No section contains an empty table or placeholder text such as "N/A" or "fill me in".
- Confirm the skill has not written any `.php` or `.xml` file.
- Every JSON example block parses as valid JSON (mental parse or `jq` check).
- Every example block carries the caption `> Example — illustrative, generated from the schema`.
- Every ` ```mermaid ``` ` block is properly fenced, brace/arrow-balanced, and uses
  sanitized node ids (no spaces or special characters).
- No `![]` image embeds appear anywhere in the output.
- The `{DOCUMENTATION_LINKS}` token in `README.md` lists only the docs that were
  actually produced in this run (registered in
  `magento2-context/references/placeholder-schema.md`).

### Phase 5 — Report

Write a run report to
`{output_root}/docs-generated/{Vendor}_{Module}-{date}.md` listing:

- Module path documented.
- Docs produced (paths).
- New docs omitted (with reason, e.g. "user-guide omitted — no user surface found").
- Surface inventory: entries found per category.
- Surfaces omitted (not found in the module).
- Examples skipped due to unresolved types (list field names and the unresolved type).
- Skill version: `magento2-docs-generate@1.3.1`.

## Inputs

```
/magento2-docs-generate --module=Acme_OrderExport
/magento2-docs-generate --module=Acme_OrderExport --docs=readme,technical-reference
/magento2-docs-generate --module=Acme_OrderExport --docs=readme,developer-guide,api-reference
/magento2-docs-generate --module=Acme_OrderExport --docs=changelog
/magento2-docs-generate --module=Acme_OrderExport --docs=readme,technical-reference,developer-guide,user-guide,api-reference,graphql-reference,changelog
/magento2-docs-generate --module=Acme_OrderExport --docs-root=<path>
```

`--docs-root=<path>` — output-root override; see "Output root" below.

## Outputs

Written INSIDE the documented module:

```
{module}/README.md
{module}/docs/technical-reference.md
{module}/docs/developer-guide.md
{module}/docs/user-guide.md          (conditional — only when a user surface exists)
{module}/docs/api-reference.md       (conditional — only when REST routes exist)
{module}/docs/graphql-reference.md   (conditional — only when GraphQL operations exist)
{module}/CHANGELOG.md
```

Run report (project root, NOT inside the module):

```
{output_root}/docs-generated/{Vendor}_{Module}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or the module directory itself. See the **Artifact
location** rule in `magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/docs-generated/`; otherwise default to
`{ctx.docs_root}/docs-generated/`. `magento2-feature-implement` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/surface-extraction.md` — read-only grep/parse recipe
  for each surface: events, plugins, preferences, config paths, CLI commands, cron jobs,
  REST routes, GraphQL, DB schema, extension attributes, `@api` annotations, and
  `dispatch(` calls (events fired).
- `${CLAUDE_SKILL_DIR}/references/doc-structure.md` — canonical section order for the
  README and technical-reference documents.
- `magento2-context/references/naming.md` — shared naming conventions.
- `magento2-context/references/placeholder-schema.md` — token registry.
- `magento2-context/references/changelog-format.md` — canonical CHANGELOG structure and
  entry-category vocabulary rendered by `templates/changelog-scaffold.md`.
- `magento2-context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` — read-only module surface extractor;
  emits surface JSON (entries + source file paths). Never mutates files. Never installs.

## Templates

- `templates/readme.md` → `{module}/README.md`
- `templates/technical-reference.md` → `{module}/docs/technical-reference.md`
- `templates/developer-guide.md` → `{module}/docs/developer-guide.md`
- `templates/user-guide.md` → `{module}/docs/user-guide.md` (conditional)
- `templates/api-reference.md` → `{module}/docs/api-reference.md` (conditional)
- `templates/graphql-reference.md` → `{module}/docs/graphql-reference.md` (conditional)
- `templates/changelog-scaffold.md` → `{module}/CHANGELOG.md`

All tokens used in templates are registered in
`magento2-context/references/placeholder-schema.md`.

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `magento2-context` | Supplies `{ctx.magento_root}`, `{ctx.docs_root}` |
| `magento2-module-review` | Architecture/quality review — use when you want findings, not documentation |
| `magento2-module-create` | Scaffolds the module whose docs this skill generates |
| `magento2-release` | Consumes `CHANGELOG.md`; run after docs are in place |
