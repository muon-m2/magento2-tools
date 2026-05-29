# Magento Version BC-Break Matrix

Key BC breaks introduced in each Magento version that the upgrade scanner should detect.

## 2.4.6

- `Magento\Framework\Indexer\AbstractProcessor::reindexRow()` removed; use `reindexRow()`
  on the specific indexer.
- `Magento\Framework\View\Element\AbstractBlock::_toHtml()` signature unchanged but more
  strictly enforced — child class returning non-string triggers a fatal.
- New `Magento\Framework\HTTP\AsyncClientInterface` — old `Magento\Framework\HTTP\Client`
  deprecated for outbound HTTP.

## 2.4.7

- `Magento\Sales\Model\Order\Email\Sender::send()` strict-type tightened.
- `Magento\Customer\Model\AccountManagement::changePassword()` requires non-null current
  password (was nullable).
- `Magento\Catalog\Helper\Image::init()` now requires `ProductInterface` (was generic
  product object).

## 2.4.8

- PHP 8.2 minimum.
- `Magento\Framework\App\Config\ScopeConfigInterface::isSetFlag()` returns strict bool.
- `Magento\Quote\Api\CartManagementInterface::placeOrder()` may now throw
  `LocalizedException` instead of `\Exception` — narrower catch handles.

## 2.5.0 (Speculative)

- PHP 8.3 minimum.
- Removed `Magento\Framework\App\Request\Http::getCookie()` (use `CookieReader`).
- Removed `Magento\Framework\App\ResourceConnection::getConnectionByName()` for
  non-default connection names — use explicit connection factory.

## Detection Patterns

Per breaking item, the scanner needs a grep / AST pattern. Example:

```yaml
- version: 2.4.8
  api: Magento\Framework\App\Config\ScopeConfigInterface::isSetFlag
  grep: 'isSetFlag\s*\('
  break_type: strict_return_type
  replacement: |
      Cast the result with `(bool)` or update callers to handle bool strictly.
```

The `deprecation-map.md` reference encodes these patterns at a more granular level.

## Strategy by Break Severity

| Severity | Action |
|----------|--------|
| Removed class/method | Manual fix required; cannot auto-rewrite |
| Strict-type tightening | Auto-fix if Rector rule exists; else manual |
| Signature change (added arg with default) | Usually no action; calling code unchanged |
| Signature change (added required arg) | Manual fix at every call site |

## Source

Adobe Security Bulletins + Magento DevDocs migration guides. When a version isn't listed
here, fall back to `vendor/bin/m2-coding-standard` or Rector's Magento rule set output.

The matrix is curated, not exhaustive — always pair scanner output with manual review of
release notes for the target version.
