# Breeze Compatibility Checklist

Reference for `magento2-breeze-compat-audit`. Source: https://breezefront.com/docs/better-compatibility

Breeze runs [Cash](https://github.com/fabiospampinato/cash) + its own `$.widget` factory instead of
RequireJS + jQuery (UI) + Knockout. A module is compatible out-of-box when it relies only on shared
page structure, layout, templates, and `data-mage-init`/`x-magento-init`. The checks below flag the
patterns that need Breeze's "Better Compatibility" mode or a manual adapter.

## Checks

| Check | Pattern (scanner) | Severity | Breeze remediation | Auto-scaffold? |
|-------|-------------------|----------|--------------------|----------------|
| RequireJS config | `requirejs-config.js` present | Medium | Port registered components to Breeze widgets, or enable Better Compatibility. | Yes (module-adapt) |
| RequireJS mixins | `mixins` key in `requirejs-config.js` | High | Breeze does not load Luma mixins by default — re-implement as a Breeze widget or enable Better Compatibility. | Partial |
| Knockout / uiComponent | `'uiComponent'`, `Magento_Ui/js/`, `data-bind=` | High | Breeze has no Knockout — rewrite as DOM + Cash or enable Better Compatibility (KO-heavy checkout). | Partial |
| jQuery-UI widget | `$.widget(` | Medium | Convert to a Breeze `$.widget` on Cash, or enable Better Compatibility. | Yes |
| jQuery mage widget | `$.mage.` | Medium | Convert to a Breeze widget or enable Better Compatibility. | Yes |
| Inline RequireJS | `require([...])` in `.phtml` | Medium | Move into a Breeze widget or enable Better Compatibility. | Partial |
| mage-init | `data-mage-init`, `text/x-magento-init` | Info | Breeze honors these — usually works as-is; verify the component resolves. | N/A |
| No adapter yet | ships `view/frontend/web` but no `breeze_*` layout / `web/css/breeze` | Info | Generate a Breeze companion module. | Yes |

## Verdict

- **Compatible out-of-box** — only Info findings. Ship as-is; verify on a Breeze page.
- **Needs Better Compatibility** — RequireJS/mixins/jQuery-widget findings but no Knockout. Enable
  Better Compatibility (globally, per-module via the `breeze.js` `better_compatibility` array, or
  for testing with `?breeze=1&compat=1`).
- **Needs manual adapter** — Knockout/uiComponent findings. Generate a companion module with
  `magento2-breeze-module-adapt` and port (or Better-Compatibility-wrap) the affected surfaces.

## Notes

- The scan is heuristic (regex over source), so findings are emitted with
  `confidence: candidate`. Confirm on a running Breeze store with debug mode
  (`?breeze=1&compat=1`) — Better Compatibility logs the modules it activates to the console.
- "Excluded from Better Compatibility" (a Breeze admin setting) is the escape hatch for the rare
  file path that breaks under compatibility mode.
