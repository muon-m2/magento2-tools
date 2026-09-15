---
name: docs
version: 1.4.1
description:
    Generate or refresh a module's technical documentation from its own code — public
    @api surface, events, plugins, REST/GraphQL routes, DB schema, dependencies — plus
    a README, developer guide, user guide (when a user surface exists), REST API reference
    (when REST routes exist), GraphQL reference (when GraphQL ops exist), technical
    reference, and CHANGELOG scaffold with illustrative examples derived from the schema.
    For a module with `etc/webapi.xml` it also emits machine-readable API description
    artifacts under `{module}/docs/api/` — OpenAPI 3.1, a JetBrains `.http` file with a
    secret-free env, and a Postman v2.1 collection + environment — with no live-instance
    dependency. Use for 'document this module' / 'generate module docs'. Never modifies
    source. For an architecture/quality review use `magento2-tools:review`.
---

# Magento 2 Docs Generate

Read-only-with-respect-to-source skill — extracts a module's public surface from its own
code and XML files, then renders documentation from it: Markdown for humans, and (when the
module declares REST routes) OpenAPI/`.http`/Postman for machines. Unlike
`review` (which performs an architecture/quality review), this skill
generates documentation artifacts. It **never** modifies PHP, XML, or any other source file.

## Core Rules

- **NEVER invent facts.** Every documented item is extracted from a real file on disk.
  Each entry in the generated docs cites its source file path.
- **`@api` marks the public contract.** Only classes and interfaces annotated `@api`
  appear in the API Surface section.
- **OMIT empty surfaces.** If a surface (events, plugins, REST routes, etc.) has no
  entries, that section is omitted entirely. No empty tables; no placeholder text.
- **Never modifies source.** This skill never writes or modifies `.php`, `.xml`,
  `.phtml`, `.less`, `.js`, `.graphqls`, or any file outside `{module}/docs/`,
  `{module}/README.md`, `{module}/CHANGELOG.md`, and `{output_root}/docs-generated/`.
  Within `{module}/docs/` it may write `.md`, `.yaml`, `.json`, and `.http`
  documentation artifacts. Output is the set of docs selected in Phase 1 (README,
  technical reference, developer/user guides, REST/GraphQL references, CHANGELOG
  scaffold, and the API description artifacts — each produced only when applicable),
  plus a run report under `{output_root}/docs-generated/`.
- **No secrets, ever.** The API description artifacts are generated from static source
  and never from a live API, and the Phase 4 gate blocks any file that would carry a
  credential, a personal identifier, or a concrete hostname. The skill never generates
  `docs/api/http-client.private.env.json` — that is the JetBrains token store, and it
  sits beside the `.http` file rather than inside `.idea/`, so a stock `.gitignore`
  does not cover it.
- **`{module}/docs/api/`, never `{module}/api/`.** Every module with a REST surface
  already has `{module}/Api/`. On a case-insensitive filesystem — macOS by default,
  Windows, any unpacked `.zip` — `api/` and `Api/` are the same directory, so writing
  one corrupts the PSR-4 tree and breaks autoloading for the whole module.
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
  infer conventions. See `context/references/source-of-truth.md`.

## Workflow

### Phase 0 — Context Resolution

Invoke `context` (or run
`${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/resolve-context.sh`); capture
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
   - `openapi`              → `{module}/docs/api/openapi.yaml`               (only if REST routes exist)
   - `http-client`          → `{module}/docs/api/{slug}.http`
                            + `{module}/docs/api/http-client.env.json`       (only if REST routes exist)
   - `postman`              → `{module}/docs/api/postman/{slug}.postman_collection.json`
                            + `{module}/docs/api/postman/{slug}.postman_environment.json`
                                                                             (only if REST routes exist)
   Default: produce every applicable doc. Omit `user-guide` when no user surface is
   present; omit `api-reference`, `openapi`, `http-client` and `postman` when no REST
   routes exist; omit `graphql-reference` when no GraphQL operations are found.

   `http-client.env.json` is emitted if and only if `{slug}.http` is.
   `{slug}` is derived in `references/doc-structure.md` → *REST API Description
   Artifacts*; it is what a consumer already sees in the URL, so the spec file, the
   collection and the endpoint stay greppable by one string.

   **GraphQL has no derivative artifact.** `etc/schema.graphqls` is already
   machine-readable and already checked in; generating a second copy of it would only
   create something to drift.

### Phase 2 — Extract Surface (GATE)

Run `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` with the module path, which:

- Greps/parses each XML and PHP source file listed in
  `${CLAUDE_SKILL_DIR}/references/surface-extraction.md`.
- Emits a surface JSON: which surfaces exist, their entries, and source file paths.
- Prints that JSON's path. With `SURFACE_FILE` unset it creates a new temp file that outlives the
  script; the caller owns it and removes it when the run is done.
- Is strictly READ-ONLY — it never mutates files and never installs anything.

From the surface JSON, present the **doc plan** to the user:

- Which docs will be written and why.
- Which surfaces were found: events: N, plugins: N, REST routes: N, api_methods: N,
  GraphQL ops: N, user surface: yes/no (breakdown: admin_config/admin_ui/storefront/emails).
- Which surfaces are absent and will be omitted.
- Which of the new docs (`developer-guide`, `user-guide`, `api-reference`,
  `graphql-reference`) will be produced or omitted, with the reason for each omission.
- Which API description artifacts (`openapi`, `http-client`, `postman`) will be
  produced, with their target paths — or the reason they are omitted.
- **Every entry in the surface JSON's `rest_warnings`, as a WARNING**, one per line, in
  the form `WARNING  {file}:{line} — \`{annotation}\`` followed by the recorded message.
  These are bare `array`/`mixed` annotations in the `Api/` graph reachable from the
  routes. They are a warning, not a stop — the emitted spec is still useful and the
  affected property simply degrades to `{}` — but they must be loud, because
  `Magento\Framework\Reflection\TypeProcessor` refuses a bare `array` and one offending
  annotation anywhere in the graph takes `GET /rest/<store>/schema` down with HTTP 500
  for **every** service on the installation, not just this module. Fixing them is a
  human's job (or `lint`'s); this skill is read-only w.r.t. source.

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

**API description artifacts** are not composed by hand. Run
`${CLAUDE_SKILL_DIR}/scripts/emit-api-artifacts.sh` with `MODULE_PATH`, the
`SURFACE_FILE` from Phase 2, and `FORMATS` set to the selected subset of
`openapi,http-client,postman`. It fills these five templates:

- `${CLAUDE_SKILL_DIR}/templates/openapi.yaml` → `{module}/docs/api/openapi.yaml`
- `${CLAUDE_SKILL_DIR}/templates/http-client.http` → `{module}/docs/api/{slug}.http`
- `${CLAUDE_SKILL_DIR}/templates/http-client.env.json` → `{module}/docs/api/http-client.env.json`
- `${CLAUDE_SKILL_DIR}/templates/postman-collection.json` → `{module}/docs/api/postman/{slug}.postman_collection.json`
- `${CLAUDE_SKILL_DIR}/templates/postman-environment.json` → `{module}/docs/api/postman/{slug}.postman_environment.json`

The script — not the model — owns this rendering because the artifacts must be
**byte-identical across runs** (that is what makes them reviewable in a PR, and why the
Postman collection id is a UUIDv5 derived from `{Vendor}_{Module}` rather than random).
It runs the Phase 4 secret/privacy gate itself and returns a JSON report naming what it
wrote, what it blocked and why, and the `rest_warnings` it carried through. Its exit
code is `0` for a clean run, `2` when at least one artifact was blocked, `1` on a hard
error. Generation rules per format are in `references/doc-structure.md` → *REST API
Description Artifacts*.

Each table row in the technical reference must include the source file path so readers
can verify the documentation against the code.

### Phase 4 — Verify

Before saving any file:

- No unsubstituted `{tokens}` remain in the output.
- Internal links (e.g. `[API Surface](#api-surface)`) resolve within the document.
- No section contains an empty table or placeholder text such as "N/A" or "fill me in".
- Confirm the skill has not written or modified any `.php`, `.xml`, `.phtml`, `.less`,
  `.js` or `.graphqls` file, nor anything outside `{module}/docs/`,
  `{module}/README.md`, `{module}/CHANGELOG.md`, and `{output_root}/docs-generated/`.
- Every JSON example block parses as valid JSON (mental parse or `jq` check).
- Every example block carries the caption `> Example — illustrative, generated from the schema`.
- Every ` ```mermaid ``` ` block is properly fenced, brace/arrow-balanced, and uses
  sanitized node ids (no spaces or special characters).
- No `![]` image embeds appear anywhere in the output.
- The `{DOCUMENTATION_LINKS}` token in `README.md` lists only the docs that were
  actually produced in this run (registered in
  `context/references/placeholder-schema.md`).
- `openapi.yaml` parses as YAML and every `.json` artifact parses as JSON.

#### Secret and privacy gate (blocking)

`emit-api-artifacts.sh` enforces these before writing. **Any hit blocks the write for
that file and is reported**; the other artifacts still ship. Confirm the reported
`blocked` list is empty, and that the run did not silently skip the gate.

| # | Assertion |
|---|---|
| 1 | No generated file matches `(?i)(bearer\s+[A-Za-z0-9._-]{8,}\|api[_-]?key\s*[:=]\s*\S\|secret\s*[:=]\s*\S\|password\s*[:=]\s*\S)` |
| 2 | No value matches a JWT shape `eyJ[A-Za-z0-9_-]{6,}\.` |
| 3 | No AWS-style key `(AKIA\|ASIA)[0-9A-Z]{16}`, and no `X-Amz-Signature=` / `X-Amz-Credential=` — a presigned URL **is** a bearer credential |
| 4 | Every variable named `*token*`, `*secret*`, `*key*`, `*password*`, `*credential*` has an empty string value |
| 5 | `servers[].url` and `baseUrl` contain no host outside `{host}`-template form or the documented `magento.test` default — no production hostname, no client domain, no private store host |
| 6 | No `_postman_exported_by` / `_postman_exported_using` key; no email address anywhere (`[\w.+-]+@[\w-]+\.\w+`) |
| 7 | No `docs/api/http-client.private.env.json` was written |
| 8 | No `{module}/api/` (lowercase) directory was created |
| 9 | Examples derive only from schema types. The skill must not read `var/log/`, `.env`, `app/etc/env.php`, `auth.json`, or any live HTTP response to build them |

Rule 9 is the structural one; the other eight are backstops. Examples come from the
Example-Derivation Table, which yields `"string"` and `0` — synthetic by construction. A
real order increment id, customer email, bucket name or object key can only appear if
someone widened the input, so widening the input is what is forbidden.

### Phase 5 — Report

Write a run report to
`{output_root}/docs-generated/{Vendor}_{Module}-{date}.md` listing:

- Module path documented.
- Docs produced (paths).
- New docs omitted (with reason, e.g. "user-guide omitted — no user surface found").
- Surface inventory: entries found per category.
- Surfaces omitted (not found in the module).
- Examples skipped due to unresolved types (list field names and the unresolved type).
- API description artifacts produced (paths), or the reason each was omitted.
- Any artifact **blocked** by the Phase 4 gate, naming the assertion and the matched text.
- Every `rest_warnings` entry, in the Phase 2 WARNING form.
- **Required follow-up** when a `.http` file was written: *add
  `docs/api/http-client.private.env.json` to the module `.gitignore` before committing.*
  The JetBrains HTTP Client writes your bearer token there and it sits beside the `.http`
  file, not inside `.idea/`, so a stock `.gitignore` does not cover it.
- Skill version: `docs@1.4.1`.

## Inputs

```
/docs --module=Acme_OrderExport
/docs --module=Acme_OrderExport --docs=readme,technical-reference
/docs --module=Acme_OrderExport --docs=readme,developer-guide,api-reference
/docs --module=Acme_OrderExport --docs=changelog
/docs --module=Acme_OrderExport --docs=readme,technical-reference,developer-guide,user-guide,api-reference,graphql-reference,changelog
/docs --module=Acme_OrderExport --docs=openapi
/docs --module=Acme_OrderExport --docs=api-reference,openapi,http-client,postman
/docs --module=Acme_OrderExport --docs-root=<path>
```

`--docs` accepts `openapi`, `http-client` and `postman` alongside the Markdown values.
There is no separate flag. Default behaviour is unchanged in spirit — *produce every
applicable doc* — so a module with REST routes now gets all three artifacts by default,
and an existing user re-running the skill will see new untracked files appear under
`{module}/docs/api/`.

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

API description artifacts, all under `{module}/docs/api/` and all conditional on a
non-empty `rest_routes` surface (never `{module}/api/` — see the Core Rules):

```
{module}/docs/
├── api-reference.md                              (prose, for humans)
└── api/
    ├── openapi.yaml                              OpenAPI 3.1
    ├── {slug}.http                               JetBrains HTTP Client
    ├── http-client.env.json                      public env — NO secret values
    └── postman/
        ├── {slug}.postman_collection.json        Collection v2.1
        └── {slug}.postman_environment.json       placeholders only
```

`{module}/docs/api/http-client.private.env.json` is **never** generated — see the
Core Rules and the Phase 5 follow-up.

Run report (project root, NOT inside the module):

```
{output_root}/docs-generated/{Vendor}_{Module}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or the module directory itself. See the **Artifact
location** rule in `context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/docs-generated/`; otherwise default to
`{ctx.docs_root}/docs-generated/`. `feature` passes this so a feature
run's reports collect under its folder.

## Reference Files

- `${CLAUDE_SKILL_DIR}/references/surface-extraction.md` — read-only grep/parse recipe
  for each surface: events, plugins, preferences, config paths, CLI commands, cron jobs,
  REST routes, GraphQL, DB schema, extension attributes, `@api` annotations, and
  `dispatch(` calls (events fired).
- `${CLAUDE_SKILL_DIR}/references/doc-structure.md` — canonical section order for the
  README and technical-reference documents, plus the per-format generation rules for the
  API description artifacts.
- `${CLAUDE_SKILL_DIR}/references/search-criteria-params.md` — the fixed query-parameter
  set substituted for a `SearchCriteriaInterface` route parameter, which the module-local
  DTO walker cannot resolve.
- `context/references/naming.md` — shared naming conventions.
- `context/references/placeholder-schema.md` — token registry.
- `context/references/changelog-format.md` — canonical CHANGELOG structure and
  entry-category vocabulary rendered by `templates/changelog-scaffold.md`.
- `context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/extract-surface.sh` — read-only module surface extractor;
  emits surface JSON (entries + source file paths). Never mutates files. Never installs.
- `${CLAUDE_SKILL_DIR}/scripts/emit-api-artifacts.sh` — deterministic renderer for the
  API description artifacts. Reads the surface JSON plus the module's `composer.json`,
  enforces the Phase 4 secret/privacy gate, and writes only under `{module}/docs/api/`.
  Never reads a live API. Exit `0` clean, `2` blocked, `1` hard error.

## Templates

- `templates/readme.md` → `{module}/README.md`
- `templates/technical-reference.md` → `{module}/docs/technical-reference.md`
- `templates/developer-guide.md` → `{module}/docs/developer-guide.md`
- `templates/user-guide.md` → `{module}/docs/user-guide.md` (conditional)
- `templates/api-reference.md` → `{module}/docs/api-reference.md` (conditional)
- `templates/graphql-reference.md` → `{module}/docs/graphql-reference.md` (conditional)
- `templates/changelog-scaffold.md` → `{module}/CHANGELOG.md`
- `templates/openapi.yaml` → `{module}/docs/api/openapi.yaml` (conditional)
- `templates/http-client.http` → `{module}/docs/api/{slug}.http` (conditional)
- `templates/http-client.env.json` → `{module}/docs/api/http-client.env.json` (conditional)
- `templates/postman-collection.json` → `{module}/docs/api/postman/{slug}.postman_collection.json` (conditional)
- `templates/postman-environment.json` → `{module}/docs/api/postman/{slug}.postman_environment.json` (conditional)

All tokens used in templates are registered in
`context/references/placeholder-schema.md`.

## Related Skills

| Skill | Relationship |
|-------|-------------|
| `context` | Supplies `{ctx.magento_root}`, `{ctx.docs_root}` |
| `review` | Architecture/quality review — use when you want findings, not documentation |
| `module-create` | Scaffolds the module whose docs this skill generates |
| `release` | Consumes `CHANGELOG.md`; run after docs are in place |
| `test-generate` | Owns the `webapi.xml` ↔ `openapi.yaml` parity test — a PHPUnit `.php` file, which this skill may not write |
| `lint` | Fixes the bare `array`/`mixed` annotations this skill only warns about |
