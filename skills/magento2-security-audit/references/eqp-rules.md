# Marketplace coding-standard checks

Adobe Commerce Marketplace gates extension publishing on its Extension Quality Program
(EQP). The publicly runnable part of EQP is the **Magento coding standard** — a PHP_CodeSniffer
ruleset — plus PHPStan/PHPMD. There is **no** single `magento-marketplace-eqp` or
`m2-coding-standard` binary; those names were fabricated in an earlier version of this doc.
The authoritative tooling is below.

Reference: <https://developer.adobe.com/commerce/php/coding-standards/> and the Marketplace
seller guides at <https://developer.adobe.com/commerce/marketplace/guides/sellers/>.

## Tool detection

Primary — the Magento coding standard via PHPCS (install `magento/magento-coding-standard`
as a dev dependency, which registers the `Magento2` standard):

```bash
{ctx.runner} vendor/bin/phpcs --standard=Magento2 {ctx.magento_root}/app/code/{Vendor}/{Module}
```

Complementary static analysis (run when present):

```bash
{ctx.runner} vendor/bin/phpstan analyse {ctx.magento_root}/app/code/{Vendor}/{Module}
{ctx.runner} vendor/bin/phpmd {ctx.magento_root}/app/code/{Vendor}/{Module} text cleancode,codesize
```

Note: the older `magento/marketplace-eqp` (MEQP2) standard is archived/deprecated — the
`Magento2` standard in `magento/magento-coding-standard` is its successor and the one
Marketplace uses today. If `vendor/bin/phpcs` and the `Magento2` standard are not installed,
skip this phase and report it (do not silently pass).

## Representative sniffs

These are real sniff codes from the `Magento2` standard. The list is representative, not
exhaustive — the authoritative set is whatever `vendor/bin/phpcs --standard=Magento2`
reports. Map each PHPCS message to a finding using its sniff code as the `subcategory`.

| Sniff code                                         | Catches                                                    | Typical severity |
|----------------------------------------------------|------------------------------------------------------------|------------------|
| `Magento2.Security.InsecureFunction`               | `eval`, `exec`, `system`, `passthru`, `shell_exec`         | Critical         |
| `Magento2.Security.LanguageConstruct.DirectOutput` | direct `echo`/`print` of unescaped data                    | High             |
| `Magento2.Security.Superglobal`                    | direct `$_GET`/`$_POST`/`$_REQUEST` access                 | High             |
| `Magento2.SQL.RawQuery`                            | raw SQL string instead of the query builder                | Critical         |
| `Magento2.Functions.DiscouragedFunction`           | `serialize`, `mt_rand`, `error_reporting`, `@` suppression | Medium           |
| `Magento2.Legacy.*`                                | Magento 1 / deprecated API usage                           | Medium           |
| `Magento2.CodeAnalysis.EmptyBlock`                 | empty catch/loop blocks                                    | Low              |

Severity is the PHPCS error/warning level adjusted to context per the shared severity
scale — do not treat the table above as fixed; calibrate (a raw query inside
`ResourceConnection::query()` is expected, not a finding).

## Mapping to findings schema

```json
{
  "id": "security-audit-2026-05-24-mcs-001",
  "severity": "critical",
  "category": "coding-standard",
  "subcategory": "Magento2.Security.InsecureFunction",
  "title": "Insecure function: eval() used",
  "evidence": [
    { "file": "Service/DynamicCallback.php", "line": 47 }
  ],
  "recommendation": "Replace eval() with a fixed-name callback registry; eval() is rejected by the Magento2 coding standard and by Marketplace EQP.",
  "verification": "Re-run vendor/bin/phpcs --standard=Magento2; the sniff should no longer report."
}
```

## Coding-standard vs general security findings

These findings are a subset of the security audit — they are the items Marketplace gates
publishing on. A module not aiming for Marketplace still benefits, because many sniffs catch
real defects.

## Suppressing false positives

Some sniffs over-trigger:

- `Magento2.Functions.DiscouragedFunction` for `@unlink()` in cleanup paths — sometimes the
  right answer. Suppress with `// phpcs:ignore Magento2.Functions.DiscouragedFunction` + a
  justification on the line.
- `Magento2.SQL.RawQuery` inside a resource model's `ResourceConnection::query()` — may be a
  false positive.

Suppression requires an inline `// phpcs:ignore <Sniff>` comment explaining why. Blanket
`phpcs:disable` of the whole standard is rejected.
