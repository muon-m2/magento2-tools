---
name: magento2-breeze-compat-audit
description:
    Read-only static audit of a Magento 2 module's compatibility with Swissup Breeze. Scans for
    RequireJS config, Knockout/uiComponent usage, jQuery-UI/$.mage widgets, RequireJS mixins,
    inline require([...]), and data-mage-init/x-magento-init, then emits severity-ranked findings
    (Markdown + JSON outputKind=compatibility + SARIF, via the shared emitters) plus a verdict —
    compatible out-of-box, needs Better Compatibility, or needs a manual adapter. Use when the user
    asks whether a module works with Breeze or wants a pre-launch Breeze compatibility check. Static
    only — no running instance needed. Detects Breeze via magento2-context (theme.breeze). Unlike
    magento2-module-review (general architecture/quality), this is the Breeze frontend dimension; to
    actually generate the adapter use magento2-breeze-module-adapt; for a new theme use
    magento2-breeze-child-theme.
---

# Magento 2 Breeze Compatibility Audit

Static, read-only audit that tells you whether an existing module will work with a
[Swissup Breeze](https://breezefront.com/docs/better-compatibility) theme. Breeze replaces
RequireJS/Knockout/jQuery with a Cash-based stack, so modules that lean on those APIs need either
Breeze's "Better Compatibility" mode or a hand-written adapter.

## Core Rules

- **Static-first.** Default pass uses only the source tree — no runtime, no Magento CLI required.
- **Read-only.** Never modifies code. Findings route to `magento2-breeze-module-adapt` for fixes.
- **Breeze-aware.** Resolve `magento2-context`; read `theme.breeze`. If `installed` is `false`,
  note it (the audit still runs, but the verdict says "Breeze not installed").
- **Severity by user-facing breakage.** A Knockout checkout component is High; a `data-mage-init`
  hook Breeze already supports is Info.
- **Concrete remediation.** Every finding names the specific Breeze fix (port to a Cash `$.widget`,
  enable Better Compatibility, move CSS to `breeze/_default.less`) and whether
  `magento2-breeze-module-adapt` can scaffold it.
- **JSON + SARIF.** Same shape as `magento2-module-review` (`outputKind=compatibility`).

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `theme.breeze`, `vendor`, `magento_root`.

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

Run `scripts/build-findings.sh` to emit JSON + SARIF (and render the Markdown report). Classify:
- **Compatible out-of-box** — only Info findings (mage-init / no-adapter).
- **Needs Better Compatibility** — RequireJS/mixins/jQuery-widget findings, no Knockout.
- **Needs manual adapter** — Knockout/uiComponent findings present.

Point the user at `magento2-breeze-module-adapt` for the fix.

## Inputs

```
/magento2-breeze-compat-audit <Vendor_Module> [--scope=module|site]
```

## Outputs

`{ctx.docs_root}/breeze-compat/breeze-compat-{scope}-{YYYY-MM-DD}.{json,sarif}` plus a Markdown
summary. Findings follow `magento2-context/references/findings-schema.md`.

## Reference Files

- `references/breeze-compat-checklist.md` — the full check table with patterns, severities, and
  Breeze remediation per row.

## Scripts

- `scripts/static-scan.sh` — emits the findings array for a module subtree.
- `scripts/build-findings.sh` — aggregates and emits JSON + SARIF via the shared emitters.

## Acceptance Criteria

- Produces `breeze-compat-{scope}-{date}.json` (with `outputKind=compatibility`, `findings[]`,
  `scanner_errors[]`) and `.sarif`.
- Each finding has a severity, `file:line` evidence, and a concrete Breeze remediation.
- Emits a verdict (compatible / Better Compatibility / manual adapter).
- Never modifies the scanned module.

## Related Skills

| Phase | Skill |
|-------|-------|
| 0 | `magento2-context` |
| (sibling) | `magento2-module-review` for general architecture/quality |
| (fix) | `magento2-breeze-module-adapt` to generate the adapter |
| (theme) | `magento2-breeze-child-theme` for a new Breeze theme |
