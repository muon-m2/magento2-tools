# Scanner Tools

Tool probe catalogue for Phase 2 (scan).

## Required-or-Recommended Tools

| Tool | Purpose | Required for | Fallback |
|------|---------|--------------|----------|
| `vendor/bin/rector` | Auto-fix deprecations | Auto-fix mode | Report all as manual-fixable |
| `vendor/bin/phpstan` | Type errors at the new PHP level | All upgrades | Skip; report unavailable |
| `vendor/bin/m2-coding-standard` | Magento-specific lints | Magento target upgrades | Skip; rely on Rector + manual |
| `vendor/bin/phpcs` | PHPCS Magento2 standard | All upgrades | Skip |
| Semgrep | Cross-cutting pattern scan | Optional | Skip |

## Tool Detection

Use `magento2-context`'s `tools` map. If a tool's path is `null`, skip its scanner pass.
Record what was skipped in the scan report.

## Custom AST Scan

For deprecation patterns not covered by Rector, use a custom AST walk via `nikic/php-parser`:

```bash
{ctx.runner} php -r '
require "vendor/autoload.php";
$parser = (new PhpParser\ParserFactory)->createForNewestSupportedVersion();
$ast = $parser->parse(file_get_contents($argv[1]));
// Walk and detect patterns from deprecation-map.md
' src/app/code/{Vendor}/{Module}/{File}.php
```

Or use a simple grep-based pre-scan (faster, less precise) to identify candidate files
before AST inspection.

## Composer Constraint Scanner

```bash
{ctx.runner} composer why-not magento/framework {target_version}
```

Reports which dependencies block the target. If any module's composer.json constrains
`magento/framework` below the target, that constraint must be loosened.

## PHP Compat Scanner

```bash
{ctx.runner} vendor/bin/phpcs --standard=PHPCompatibility \
    --runtime-set testVersion {target_php_version} \
    src/app/code/{Vendor}/{Module}
```

Requires `phpcompatibility/php-compatibility` installed. Reports PHP-version-specific
incompatibilities.

## Order of Scanners

1. PHPStan first — catches type-level errors.
2. Rector dry-run — identifies auto-fixable issues.
3. Custom AST / grep — fills gaps in Rector coverage.
4. PHPCompatibility — PHP-version specific.
5. m2-coding-standard — Magento-specific deprecations.

Stop at the first hard failure (e.g. composer constraint blocks the target) — there's
no point scanning further.

## Caching Scanner Output

The scanner is slow. Cache output to `.docs/upgrades/{module}-{target}-scan.json` keyed
by the module's last-modified mtime. Re-running within the same module state reuses the
cache.

Invalidate cache when:
- Module files change (mtime check)
- Target version changes
- `--no-cache` flag set
