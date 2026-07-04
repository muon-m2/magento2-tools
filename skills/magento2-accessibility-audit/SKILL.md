---
name: magento2-accessibility-audit
description:
    Audit a Magento 2 module's/theme's storefront templates for WCAG accessibility issues
    — missing alt text, unlabelled form controls, ARIA misuse, heading-order breaks,
    keyboard/tab-index problems, and LESS color-contrast heuristics — and emit ranked
    findings (Markdown + JSON + SARIF). Static-first (no running instance needed); optional
    opt-in pa11y runtime pass. For building accessible frontend assets use
    `magento2-frontend-create`; for general module quality use `magento2-module-review`.
---

# Magento 2 Accessibility Audit

Audit a module's or theme's storefront templates for **WCAG 2.1 Level AA** accessibility
issues and emit ranked findings. This is a **read-only, static-first** audit skill — it
never modifies templates and does not require a running Magento instance.

## Core Rules

- **STATIC-FIRST.** The default pass analyzes `.phtml` / `.html` templates and
  `.less` / `.css` files with no running Magento, no Docker, no credentials. See
  `references/wcag-rules.md` for the static check catalog.
- **RUNTIME OPT-IN.** The pa11y pass is strictly opt-in (`--runtime`). It requires (1)
  a storefront URL the user provides, and (2) `pa11y` present in `{ctx.tools}`. When
  either is absent the runtime pass is skipped with an honest "runtime pass unavailable"
  note in `scanner_errors` — the result is **never invented**. See
  `references/runtime-pa11y.md`.
- **THEME-AWARE.** Resolve the active theme via `magento2-context` (`{ctx.theme}`).
  Hyva projects (Tailwind + Alpine `x-*`) and Luma projects (RequireJS/Knockout
  `data-bind`) produce different template patterns; the scan adapts. See
  `references/theme-discovery.md`.
- **READ-ONLY.** Never modifies templates, never installs packages, never uploads.
- **WCAG CRITERION MAPPING.** Every finding records the WCAG 2.1 success criterion it
  violates (e.g. `1.1.1`, `4.1.2`) as a `subcategory` or tag.
- **SHARED SEVERITY SCALE.** Calibrate to `magento2-context/references/severity.md`.
  Missing alt on a product image = `high`; color-contrast heuristic = `medium`; purely
  advisory structural suggestion = `low`/`info`.
- **HONEST GAPS.** If no templates are found, state so. If the runtime pa11y pass is
  unavailable, record a `scanner_errors` entry — never emit fabricated findings.

## Severity Calibration (a11y-specific)

| Severity | A11y example                                                         |
|----------|----------------------------------------------------------------------|
| High     | `<img>` missing `alt`; form input with no label/`aria-label`        |
| High     | `<a>`/`<button>` with no accessible text                            |
| Medium   | Heading order skip (h1→h3); positive `tabindex`; missing skip-link  |
| Medium   | ARIA role misuse (e.g. `role="button"` on `<div>` without keyboard) |
| Medium   | Color-contrast heuristic flag in LESS/CSS (1.4.3 — heuristic only)  |
| Low      | Missing `lang` attribute on root `<html>`                           |
| Low      | Missing `<title>` on partial layouts                                |
| Info     | Runtime pa11y pass skipped (no URL or pa11y absent)                 |

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `{ctx}` including `{ctx.theme}`, `{ctx.tools}`, and
`{ctx.magento_root}`. Hard-stop if the target module or theme directory cannot be
resolved.

### Phase 1 — Scope

Determine the audit target:

- **Module scope** (`--module=<Vendor>_<Module>`): scan
  `{magento_root}/app/code/{Vendor}/{Module}/view/frontend/templates/**/*.phtml` and any
  `app/design/frontend/**/{Vendor}_{Module}/**`.
- **Theme scope** (`--theme=<Vendor>/<Theme>`): scan
  `{magento_root}/app/design/frontend/{Vendor}/{Theme}/**`.
- **Default**: infer the first custom module or the active `{ctx.theme}` path.

See `references/theme-discovery.md` for template location rules.

### Phase 2 — Static Scan

Run `${CLAUDE_SKILL_DIR}/scripts/scan-templates.sh`:

- Scans `.phtml` and `.html` for the WCAG check catalog in `references/wcag-rules.md`.
- Scans `.less` and `.css` for color-contrast heuristics (WCAG 1.4.3 — heuristic only;
  note this cannot fully verify contrast without rendering).
- Outputs a JSON array of finding objects conforming to
  `magento2-context/references/findings-schema.md`. Each finding's `category` is one of
  the documented buckets (`alt-text`, `aria`, `semantic-html`, `keyboard`, `contrast`,
  `forms`) so findings summarize by bucket.
- Adapts to Hyva vs. Luma template patterns via `{ctx.theme}`.
- For **module scope**, pass any resolved theme-override roots (e.g.
  `app/design/frontend/{ctx.theme}/{Vendor}_{Module}/templates`, per
  `references/theme-discovery.md`) via `EXTRA_SCAN_ROOTS` (os.pathsep- or newline-separated)
  so the single scan covers both the module's own templates and the overrides that render.

### Phase 3 — Optional Runtime pa11y Pass (OPT-IN)

Skipped by default. Only runs when **all** of:
1. `--runtime` flag is passed.
2. The user provides a `--url=<storefront-url>`.
3. `pa11y` is present in `{ctx.tools}`.

When conditions are met, run `pa11y <url>` (or `pa11y-ci`) and merge runtime findings
with static findings. See `references/runtime-pa11y.md` for the merge strategy.

When any condition is unmet, add a `scanner_errors` entry:
```json
{"scanner": "pa11y", "stderr": "runtime pass skipped — <reason>"}
```
Never invent runtime findings.

### Phase 4 — Report

Produce three deliverables:

1. **Markdown audit report** (LLM deliverable, NOT automated):
   `{output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.md` (module scope;
   theme/site scope: `a11y-{scope}-{date}.md`).
   Sections: target identity + scope summary, findings by WCAG criterion (Critical/High/Medium/Low/Info),
   static-only caveat, runtime pass status, skipped checks, recommended next steps (each
   naming the executing skill: `magento2-frontend-create` for template fixes).

2. **JSON + SARIF** (automated via `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh`). The
   automated basename uses the underscore module name (e.g. `Acme_Storefront` →
   `Acme_Storefront-a11y-{date}`):
   ```
   {output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.json   # OUTPUT_KIND=accessibility
   {output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.sarif
   ```

## WCAG Checks (Summary)

See `references/wcag-rules.md` for the full static check catalog.

| Rule | WCAG SC | Severity |
|------|---------|----------|
| `<img>` missing `alt` | 1.1.1 | high |
| Form input without label/`for`/`aria-label` | 1.3.1, 4.1.2 | high |
| `<a>` / `<button>` with no accessible text | 2.4.4, 4.1.2 | high |
| Heading-order skip (e.g. h1→h3) | 1.3.1 | medium |
| Missing `lang` on `<html>` | 3.1.1 | low |
| Invalid or abused ARIA roles / `aria-*` | 4.1.2 | medium |
| Positive `tabindex` / keyboard traps | 2.4.3 | medium |
| Missing skip-link | 2.4.1 | medium |
| Color-contrast heuristic in LESS/CSS | 1.4.3 | medium |

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/scan-templates.sh` — read-only static scan; outputs a
  JSON array of findings conforming to `magento2-context/references/findings-schema.md`.
- `${CLAUDE_SKILL_DIR}/scripts/build-findings.sh` — aggregates scan output and emits
  via the shared `magento2-module-review/scripts/emit-json.sh` /
  `magento2-module-review/scripts/emit-sarif.sh` pipeline.
  `OUTPUT_KIND=accessibility`, `SKILL_NAME=magento2-accessibility-audit`.

## Reference Files

- `references/wcag-rules.md` — static check catalog, each mapped to a WCAG SC.
- `references/theme-discovery.md` — template location rules; Luma vs. Hyva differences;
  how to use `{ctx.theme}`.
- `references/runtime-pa11y.md` — the OPT-IN runtime pa11y pass specification.
- `magento2-context/references/severity.md` — shared severity scale.
- `magento2-context/references/findings-schema.md` — JSON document structure and
  finding object shape.
- `magento2-context/references/theme-detection.md` — `{ctx.theme}` resolution algorithm.

## Inputs

```
/magento2-tools:magento2-accessibility-audit [--module=<Vendor>_<Module>]
    [--theme=<Vendor>/<Theme>]
    [--runtime --url=<storefront-url>]
    [--format=markdown|json|sarif]
    [--scope=module|theme]
```

## Outputs

Module scope (basename uses the underscore module name, e.g. `Acme_Storefront`):
```
{output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.md    # LLM deliverable (Phase 4)
{output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.json  # automated (build-findings.sh)
{output_root}/accessibility/{Vendor}_{Module}-a11y-{date}.sarif # automated (build-findings.sh)
```
Theme/site scope:
```
{output_root}/accessibility/a11y-{scope}-{date}.md
{output_root}/accessibility/a11y-{scope}-{date}.json
{output_root}/accessibility/a11y-{scope}-{date}.sarif
```
`{output_root}` defaults to `.docs` (`{ctx.docs_root}`); see the `--docs-root`/`DOCS_ROOT`
recipe in `magento2-context/references/artifact-layout.md`.

## Related Skills

| Concern | Skill |
|---------|-------|
| Build accessible frontend templates / components | `magento2-frontend-create` |
| General module quality/architecture review | `magento2-module-review` |
| Context resolution (Phase 0) | `magento2-context` |
| Deep static-analysis gate (phpcs, phpstan) | `magento2-static-analysis` |
