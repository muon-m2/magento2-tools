# Tier 3 Checks

Additional review categories beyond Tier 1 (security) and Tier 2 (architecture). Tier 3
runs by default in full review; quick review skips it.

## WCAG / Accessibility (category: `wcag`)

For modules with `frontend_ui` surface (templates, layout XML).

| Check | Severity |
|-------|---------|
| Missing `alt` on `<img>` | Medium |
| `<button>` with empty text and no `aria-label` | Medium |
| Form input without `<label>` | Medium |
| Color contrast in LESS variables (heuristic) | Low |
| `<a>` with `href="#"` and no `role="button"` | Low |
| Heading-level skip (h1 → h3, missing h2) | Low |
| Missing `lang` attribute on `<html>` (theme-level) | Medium |
| Auto-play media without controls | High |
| Click handler on a non-interactive element (div, span) | Medium |
| Missing focus indicators (LESS without `:focus`) | Low |

Detection patterns: grep + AST over `.phtml`, `.html`, `_*.less`.

When the module declares any of `view/frontend/templates/*.phtml`,
`view/frontend/web/template/*.html`, or `view/frontend/web/css/source/*.less`, run WCAG.

## Plugin / Preference Collision (category: `preference-collision`)

Cross-module checks; see `magento2-security-audit/scripts/cross-module-scan.sh` for the
authoritative implementation. The module-review version runs in single-module scope and
flags:

| Check | Severity |
|-------|---------|
| Another custom module declares `<preference for="X"/>` for X this module also targets | High |
| Two custom modules register the same cron job name | Medium |
| Plugin without `sortOrder` on a target with multiple plugins | Medium |

## PCI Scope (category: `pci`)

For modules touching payment data; flagged when the module:
- Has files under `Model/Method/`
- Touches `quote_payment` / `sales_order_payment` tables
- Implements `Magento\Payment\Gateway\*` interfaces
- Receives card data via REST/GraphQL

| Check | Severity |
|-------|---------|
| Card number stored in plain (regex `\b4\d{15}\b` etc. in DB columns) | Critical |
| Logging full PAN | Critical |
| Plugin on a payment class without documented purpose | High |
| Custom encryption (not Magento Crypt) on cardholder data | High |
| Hardcoded merchant API key in source | Critical |

The PCI tier elevates other findings: see
`magento2-security-audit/references/pci-context.md` for the severity-bump rules.

## GDPR Data Retention (category: `gdpr`)

For modules touching customer PII (email, address, phone, IP).

| Check | Severity |
|-------|---------|
| PII stored without encryption | High |
| PII logged in plain text | High |
| No documented retention policy for new tables holding PII | Medium |
| Customer data sent to third party without consent flow | High |
| Right-to-erasure: module's tables don't honor `customer_delete` event | Medium |
| Customer data accessible in admin without role check | High |

PII detection patterns: column names matching `email`, `phone`, `ip`, `tax_id`,
`date_of_birth`, `gender`, `customer_id` (in tables outside customer module).

## Reporting

These checks emit findings with the same shape as Tier 1/2. Categories:
`wcag`, `preference-collision`, `pci`, `gdpr`.

Findings respect the shared findings schema
(`magento2-context/references/findings-schema.md`).

## When to Skip Tier 3

Quick review mode skips Tier 3. Full review runs all three. The user can disable with
`--no-tier-3`.

## False-Positive Suppression

Use the inline comment:

```
// @review-ignore reason="..."
```

Above the line that triggers the false positive. Reason text is required.

## Acceptance Criteria

- Tier 3 runs when any qualifying surface is present.
- Each finding cites a specific `file:line`.
- Severities match the calibration anchors above.
- JSON output includes the `tier: 3` tag for filtering.
