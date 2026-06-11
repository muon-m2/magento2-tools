# Scanner Tools

Tool probe catalogue for Phase 2 (scan).

## Required-or-Recommended Tools

| Tool                                   | Purpose                                                    | Required for            | Fallback                                          |
|----------------------------------------|------------------------------------------------------------|-------------------------|---------------------------------------------------|
| `vendor/bin/uct upgrade:check`         | Adobe Upgrade Compatibility Tool — first-party compat scan | Recommended first pass  | Skip; rely on Rector + phpcs + manual (see below) |
| `vendor/bin/rector`                    | Auto-fix deprecations                                      | Auto-fix mode           | Report all as manual-fixable                      |
| `vendor/bin/phpstan`                   | Type errors at the new PHP level                           | All upgrades            | Skip; report unavailable                          |
| `vendor/bin/phpcs --standard=Magento2` | Magento-specific lints (`magento/magento-coding-standard`) | Magento target upgrades | Skip; rely on Rector + manual                     |
| `vendor/bin/phpcs`                     | PHPCS Magento2 standard                                    | All upgrades            | Skip                                              |
| Semgrep                                | Cross-cutting pattern scan                                 | Optional                | Skip                                              |

### Adobe Upgrade Compatibility Tool (UCT) — recommended first-party path

`magento/upgrade-compatibility-tool` is Adobe's canonical tool for exactly this job.
Prefer it over ad-hoc scanning when available:

```bash
{ctx.runner} vendor/bin/uct upgrade:check
```

It is **edition-gated**: UCT requires an Adobe Commerce / authenticated context to fetch
its compatibility data. Gate the scanner pass on `ctx.edition` — skip it for plain Open
Source installs that lack the authenticated context, and fall back to Rector + phpcs +
the deprecation-map scan.

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
' {ctx.magento_root}/app/code/{Vendor}/{Module}/{File}.php
```

Or use a simple grep-based pre-scan (faster, less precise) to identify candidate files
before AST inspection.

## Composer Constraint Scanner

```bash
# Community edition:
{ctx.runner} composer why-not magento/product-community-edition {target_version}
# Commerce edition:
{ctx.runner} composer why-not magento/product-enterprise-edition {target_version}
```

Check against the **product metapackage**, not `magento/framework` — the framework is
versioned independently (e.g. `103.x`), so `composer why-not magento/framework 2.4.8`
is meaningless. Use the metapackage that carries the `2.4.x` version (e.g.
`magento/product-community-edition 2.4.8`).

Reports which dependencies block the target. If any module's composer.json constrains
the metapackage (or `magento/framework`) below the target, that constraint must be
loosened.

## PHP Compat Scanner

```bash
{ctx.runner} vendor/bin/phpcs --standard=PHPCompatibility \
    --runtime-set testVersion {target_php_version} \
    {ctx.magento_root}/app/code/{Vendor}/{Module}
```

Requires `phpcompatibility/php-compatibility` installed. Reports PHP-version-specific
incompatibilities.

## Order of Scanners

1. UCT (`uct upgrade:check`) first when the edition gate allows — first-party compat report.
2. PHPStan — catches type-level errors.
3. Rector dry-run — identifies auto-fixable issues.
4. Custom AST / grep — fills gaps in Rector coverage.
5. PHPCompatibility — PHP-version specific.
6. `phpcs --standard=Magento2` — Magento-specific deprecations.

Stop at the first hard failure (e.g. composer constraint blocks the target) — there's
no point scanning further.

## Caching Scanner Output

The scanner is slow. Cache output to `.docs/upgrades/{module}-{target}-scan.json` keyed
by a **content hash** of the module's source files (e.g. a hash of `git ls-files` output
plus each file's blob, or a `find … -type f | sort | xargs sha256sum` digest). Do **not**
key on file mtime — git rewrites mtimes on checkout/clone, so an mtime key produces false
cache hits and misses. Re-running within the same content state reuses the cache.

Invalidate cache when:

- Module file contents change (content-hash mismatch)
- Target version changes
- `--no-cache` flag set
