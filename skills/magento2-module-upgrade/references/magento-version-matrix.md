# Magento Version BC-Break Matrix

Key BC breaks introduced in each Magento version that the upgrade scanner should detect.

## Status markers

Each BC-break entry below carries a status marker (mirroring the convention the
`magento2-security-audit` skill uses for CVE data):

- **`status: live`** — independently confirmed against Adobe release notes / DevDocs. The
  scanner may surface it as a confirmed finding.
- **`status: illustrative`** — plausible example that has **not** been confirmed against a
  primary source (or is known to be approximate). Treat as a candidate only; verify against
  the target version's release notes before acting. Unmarked entries default to
  `illustrative`.

## Supported PHP per Magento (Open Source / Commerce)

Cross-checked against Adobe Commerce system-requirements docs. Use the **minimum** column
to gate a PHP upgrade and the **supported** column to pick a target.

| Magento | Supported PHP | Minimum |
|---------|---------------|---------|
| 2.4.4   | 7.4, 8.1      | 7.4     |
| 2.4.5   | 8.1           | 8.1     |
| 2.4.6   | 8.1, 8.2      | 8.1     |
| 2.4.7   | 8.1, 8.2, 8.3 | 8.1     |
| 2.4.8   | 8.3, 8.4      | 8.3     |

Note: 2.4.8 **dropped** PHP 8.1 and 8.2 — an upgrade to 2.4.8 requires moving to PHP 8.3+.

## 2.4.6

- *(status: illustrative)* Indexer processors: prefer calling `reindexRow()` /
  `reindexList()` on the specific indexer rather than relying on a generic abstract
  processor. Confirm the exact class/method against the target release before treating any
  removal as fact.
- *(status: illustrative)* `Magento\Framework\View\Element\AbstractBlock::_toHtml()`
  signature unchanged but assumed more strictly enforced — a child class returning
  non-string may trigger a type error. Verify against release notes.
- *(status: illustrative)* `Magento\Framework\HTTP\AsyncClientInterface` exists but
  **predates 2.4.6** — it is not introduced in this version. Listed here only as an example
  of preferring async/PSR HTTP clients over older clients; do not treat as a 2.4.6 change.

## 2.4.7

*(status: illustrative — confirm each against 2.4.7 release notes before acting)*

- `Magento\Sales\Model\Order\Email\Sender::send()` strict-type tightened.
- `Magento\Customer\Model\AccountManagement::changePassword()` requires non-null current
  password (was nullable).
- `Magento\Catalog\Helper\Image::init()` now requires `ProductInterface` (was generic
  product object).

## 2.4.8

- *(status: live)* PHP 8.3 minimum (8.4 supported; 8.1 and 8.2 dropped).
- *(status: illustrative)* `Magento\Framework\App\Config\ScopeConfigInterface::isSetFlag()`
  returns strict bool — confirm before acting.
- *(status: illustrative)* `Magento\Quote\Api\CartManagementInterface::placeOrder()` may
  now throw `LocalizedException` instead of `\Exception` — narrower catch handles. Confirm
  against release notes.

## 2.5.0 (Speculative)

*(status: illustrative — no 2.5.0 release exists at time of writing; entries are
hypothetical placeholders, not confirmed BC breaks)*

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
here, fall back to the Adobe Upgrade Compatibility Tool (`vendor/bin/uct upgrade:check`,
edition-gated) and `vendor/bin/phpcs --standard=Magento2` (requires
`magento/magento-coding-standard`).

The matrix is curated, not exhaustive — always pair scanner output with manual review of
release notes for the target version.
