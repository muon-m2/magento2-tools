---
name: magento2-docs-generate
description:
    Generate or refresh a module's technical documentation from its own code — public
    @api surface, events fired and observed, plugins, preferences, config paths, CLI
    commands, cron jobs, REST/GraphQL surface, DB schema, dependencies — plus a README
    and CHANGELOG scaffold. Use for 'document this module' / 'generate module docs'.
    Read-only analysis; writes Markdown only. For an architecture/quality review use
    `magento2-module-review`.
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
  Output is `{module}/README.md`, `{module}/docs/technical-reference.md`, and
  `{module}/CHANGELOG.md` (scaffold), plus a run report under `.docs/docs-generated/`.

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
   - `readme` → `{module}/README.md`
   - `technical-reference` → `{module}/docs/technical-reference.md`
   - `changelog` → `{module}/CHANGELOG.md` (scaffold only; no history invented)
   Default: produce all three.

### Phase 2 — Extract Surface (GATE)

Run `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` with the module path, which:

- Greps/parses each XML and PHP source file listed in
  `${CLAUDE_SKILL_DIR}/references/surface-extraction.md`.
- Emits a surface JSON: which surfaces exist, their entries, and source file paths.
- Is strictly READ-ONLY — it never mutates files and never installs anything.

From the surface JSON, present the **doc plan** to the user:

- Which docs will be written and why.
- Which surfaces were found (events: N, plugins: N, REST routes: N, …).
- Which surfaces are absent and will be omitted.

**WAIT for "proceed" before writing any files.**

### Phase 3 — Render

Fill the chosen templates with extracted facts:

- `${CLAUDE_SKILL_DIR}/templates/readme.md` → `{module}/README.md`
- `${CLAUDE_SKILL_DIR}/templates/technical-reference.md` → `{module}/docs/technical-reference.md`
- `${CLAUDE_SKILL_DIR}/templates/changelog-scaffold.md` → `{module}/CHANGELOG.md`

Follow the section order defined in
`${CLAUDE_SKILL_DIR}/references/doc-structure.md`.

Each table row in the technical reference must include the source file path so readers
can verify the documentation against the code.

### Phase 4 — Verify

Before saving any file:

- No unsubstituted `{tokens}` remain in the output.
- Internal links (e.g. `[API Surface](#api-surface)`) resolve within the document.
- No section contains an empty table or placeholder text such as "N/A" or "fill me in".
- Confirm the skill has not written any `.php` or `.xml` file.

### Phase 5 — Report

Write a run report to
`.docs/docs-generated/{Vendor}_{Module}-{date}.md` listing:

- Module path documented.
- Docs produced (paths).
- Surface inventory: entries found per category.
- Surfaces omitted (not found in the module).
- Skill version: `magento2-docs-generate@1.0.0`.

## Inputs

```
/magento2-docs-generate --module=Acme_OrderExport
/magento2-docs-generate --module=Acme_OrderExport --docs=readme,technical-reference
/magento2-docs-generate --module=Acme_OrderExport --docs=changelog
```

## Outputs

Written INSIDE the documented module:

```
{module}/README.md
{module}/docs/technical-reference.md
{module}/CHANGELOG.md
```

Run report (project root, NOT inside the module):

```
.docs/docs-generated/{Vendor}_{Module}-{date}.md
```

`.docs/` is anchored at the project root (`{ctx.docs_root}`), never under
`{ctx.magento_root}`, `app/code`, or the module directory itself. See the **Artifact
location** rule in `magento2-context/SKILL.md`.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/surface-extraction.md` — read-only grep/parse recipe
  for each surface: events, plugins, preferences, config paths, CLI commands, cron jobs,
  REST routes, GraphQL, DB schema, extension attributes, `@api` annotations, and
  `dispatch(` calls (events fired).
- `${CLAUDE_SKILL_DIR}/references/doc-structure.md` — canonical section order for the
  README and technical-reference documents.
- `magento2-context/references/naming.md` — shared naming conventions.
- `magento2-context/references/placeholder-schema.md` — token registry.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` — read-only module surface extractor;
  emits surface JSON (entries + source file paths). Never mutates files. Never installs.

## Templates

- `templates/readme.md` → `{module}/README.md`
- `templates/technical-reference.md` → `{module}/docs/technical-reference.md`
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
