---
name: breeze-compat
version: 1.1.0
description: >-
  Read-only static audit of a Magento 2 module's compatibility with Swissup Breeze. Scans RequireJS,
  Knockout, jQuery-UI widgets, and mixins; emits ranked findings (Markdown, JSON, SARIF) and a
  verdict: compatible, needs Better Compatibility, or needs a manual adapter. Use to ask whether a
  module works with Breeze. Static only. Unlike magento2-tools:review (general quality), this is the
  Breeze dimension; generate the adapter with magento2-tools:breeze-adapt.
---

# Magento 2 Breeze Compatibility Audit

Static, read-only audit that tells you whether an existing module will work with a
[Swissup Breeze](https://breezefront.com/docs/better-compatibility) theme. Breeze replaces
RequireJS/Knockout/jQuery with a Cash-based stack, so modules that lean on those APIs need either
Breeze's "Better Compatibility" mode or a hand-written adapter.

## Core Rules

- **Static-first.** Default pass uses only the source tree — no runtime, no Magento CLI required.
- **Read-only.** Never modifies code. Findings route to `breeze-adapt` for fixes.
- **Breeze-aware.** Resolve `context`; read `theme.breeze`. If `installed` is `false`,
  note it (the audit still runs, but the verdict says "Breeze not installed").
- **Severity by user-facing breakage.** A Knockout checkout component is High; a `data-mage-init`
  hook Breeze already supports is Info.
- **Concrete remediation.** Every finding names the specific Breeze fix (port to a Cash `$.widget`,
  enable Better Compatibility, move CSS to `breeze/_default.less`) and whether
  `breeze-adapt` can scaffold it.
- **JSON + SARIF.** Same shape as `review` (`outputKind=compatibility`).

## Workflow

### Phase 0 — Context Resolution

Invoke `context`. Capture `theme.breeze`, `vendor`, `magento_root`.

### Phase 1 — Scope

- Single module → scan that module subtree.
- Multiple modules / site → scan each custom module under `app/code`.

### Phase 2 — Static Scan

Run `scripts/static-scan.sh <target>` per `references/breeze-compat-checklist.md`:

| Check | Pattern | Severity |
|-------|---------|----------|
| RequireJS config | `requirejs-config.js` present | Medium (High if `mixins`) |
| RequireJS mixins | `mixins` in `requirejs-config.js` | High |
| Knockout / uiComponent | `'uiComponent'`, `Magento_Ui/js/`, `data-bind` | High |
| jQuery widget | `$.widget(`, `$.mage.` | Medium |
| Inline require | `require([...])` in `.phtml` | Medium |
| mage-init | `data-mage-init`, `text/x-magento-init` | Info (Breeze supports) |
| No adapter yet | ships `view/frontend/web` but no `breeze_*`/`web/css/breeze` | Info |

### Phase 3 — Verdict & Emit

Run `scripts/build-findings.sh` to emit JSON + SARIF (and render the Markdown report).
Run it with `DOCS_ROOT=<output_root>` (the resolved `--docs-root` value, or `.docs` by
default) so both artifacts land under `{output_root}/breeze-compat/`. Classify:
- **Compatible out-of-box** — only Info findings (mage-init / no-adapter).
- **Needs Better Compatibility** — RequireJS/mixins/jQuery-widget findings, no Knockout.
- **Needs manual adapter** — Knockout/uiComponent findings present.

Point the user at `breeze-adapt` for the fix.

## Inputs

```
/breeze-compat <Vendor_Module> [--scope=module|site] [--docs-root=<path>]
```

## Outputs

Module scope (basename uses the underscore module name, e.g. `Acme_Foo`):
`{output_root}/breeze-compat/{Vendor}_{Module}-breeze-compat-{YYYY-MM-DD}.{json,sarif}`
Site scope: `{output_root}/breeze-compat/breeze-compat-{scope}-{YYYY-MM-DD}.{json,sarif}`
— plus a Markdown summary sharing the same basename. Findings follow
`context/references/findings-schema.md`. `{output_root}` defaults to `.docs`
(`{ctx.docs_root}`); see the `--docs-root`/`DOCS_ROOT` recipe in
`context/references/artifact-layout.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`context/references/artifact-layout.md`). When set, run the emitter with
`DOCS_ROOT=<path>` so artifacts land under `<path>/breeze-compat/`; otherwise they default
to `{ctx.docs_root}/breeze-compat/`. Orchestrators such as `feature`
pass this to collect a run's artifacts under one folder.

## Reference Files

- `references/breeze-compat-checklist.md` — the full check table with patterns, severities, and
  Breeze remediation per row.
- `context/references/severity.md` — the shared five-point severity scale the per-row
  severities calibrate against.
- `context/references/findings-schema.md` — JSON findings-document structure
  (`outputKind=compatibility`).

## Scripts

- `scripts/static-scan.sh` — emits the findings array for a module subtree.
- `scripts/build-findings.sh` — aggregates and emits JSON + SARIF via the shared emitters.

## Acceptance Criteria

- Produces `{Vendor}_{Module}-breeze-compat-{date}.json` (module scope; site scope:
  `breeze-compat-{scope}-{date}.json`) with `outputKind=compatibility`, `findings[]`,
  `scanner_errors[]`, and `.sarif`.
- Each finding has a severity, `file:line` evidence, and a concrete Breeze remediation.
- Emits a verdict (compatible / Better Compatibility / manual adapter).
- Never modifies the scanned module.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `context` |
| (sibling) | `review` for general architecture/quality |
| (fix) | `breeze-adapt` to generate the adapter |
| (theme) | `breeze-theme` for a new Breeze theme |
