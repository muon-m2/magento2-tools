# Marketplace EQP Rules

Magento Marketplace's Extension Quality Program ships static rules every extension must
pass. The audit skill reuses them. See https://devdocs.magento.com/marketplace/eqp/ for
the canonical reference.

## Tool Detection

Preferred:
```bash
{ctx.runner} vendor/bin/magento-marketplace-eqp analyse {ctx.magento_root}/app/code/{Vendor}/{Module}
```

Fallback:
```bash
{ctx.runner} vendor/bin/m2-coding-standard {ctx.magento_root}/app/code/{Vendor}/{Module}
```

If neither is installed, skip Phase 5 and report it.

## Selected Rules

| Rule ID | Description | Severity |
|---------|-------------|---------|
| EQP-1   | Forbidden function (`eval`, `exec`, `system`, `passthru`) | Critical |
| EQP-2   | `goto` keyword used | High |
| EQP-3   | Direct DB query without prepared statement | Critical |
| EQP-4   | `file_get_contents` on user-controlled URL | High |
| EQP-5   | `curl_exec` without SSL verification | High |
| EQP-6   | `chmod 777` in setup script | High |
| EQP-7   | `serialize()` of user input | Critical |
| EQP-8   | `error_reporting(0)` | Medium |
| EQP-9   | Use of `@` error suppressor | Medium |
| EQP-10  | Missing `declare(strict_types=1)` | Low |
| EQP-11  | Module without `composer.json` | Medium |
| EQP-12  | `LICENSE.txt` missing | Low |
| EQP-13  | README missing | Low |
| EQP-14  | Module without unit tests | Medium |

## Mapping to Findings Schema

```json
{
  "id": "security-audit-2026-05-24-eqp-001",
  "severity": "critical",
  "category": "eqp",
  "subcategory": "EQP-1",
  "title": "Forbidden function: eval() used",
  "evidence": [
    { "file": "Helper/DynamicCallback.php", "line": 47 }
  ],
  "recommendation": "Replace eval() with a fixed-name callback registry; eval() in production is forbidden by EQP.",
  "verification": "Re-run audit; rule EQP-1 should no longer match."
}
```

## EQP vs General Security Findings

EQP findings are a subset of security findings — they're the items Magento explicitly
gates Marketplace publishing on. A module not aiming for Marketplace can still benefit
from EQP — many of the rules catch real defects.

## Suppressing False Positives

Some EQP rules over-trigger:

- EQP-9 (`@` operator): `@unlink()` in cleanup paths is sometimes the right answer.
  Suppress with a `// phpcs:ignore` comment + justification.
- EQP-3 (direct DB query): Magento's resource model uses raw SQL in places; if you're
  inside `ResourceConnection::query()`, the rule may false-positive.

Suppression requires an inline comment explaining why. Blanket disabling EQP is rejected.
