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

**Installable and supported are different things — do not conflate them.** The composer
constraint decides whether the release will *install*; Adobe's docs decide what they will
*support in production*. They diverge (2.4.9 installs on PHP 8.3 but Adobe designates 8.3
upgrade-only), so both columns are listed and the gate you want depends on the question:

- *"Will it install?"* → **Installable**. Verified from `require.php` in `composer.json` at
  each git tag — the code itself, not a docs page.
- *"Should we run it?"* → **Adobe-supported**. From Adobe's release notes / system
  requirements.

| Magento | Installable (composer `require.php`) | Min installable | Adobe-supported | Supported col. status |
|---------|--------------------------------------|-----------------|-----------------|----------------------|
| 2.4.4   | 7.4, 8.1                             | 7.4             | 7.4, 8.1        | illustrative         |
| 2.4.5   | 7.4, 8.1                             | 7.4             | 8.1             | illustrative         |
| 2.4.6   | 8.1, 8.2                             | 8.1             | 8.1, 8.2        | illustrative         |
| 2.4.7   | 8.1, 8.2, 8.3                        | 8.1             | 8.1, 8.2, 8.3   | illustrative         |
| 2.4.8   | 8.2, 8.3, 8.4                        | 8.2             | 8.3, 8.4        | illustrative         |
| 2.4.9   | 8.3, 8.4, 8.5                        | 8.3             | 8.4, 8.5        | **live**             |

**Installable / Min installable: `status: live` for every row** — read directly from
`raw.githubusercontent.com/magento/magento2/{tag}/composer.json` on 2026-07-16.

**Adobe-supported is `status: live` for 2.4.9 only**, confirmed against the [2.4.9 release
notes][rn249]. The 2.4.4–2.4.8 values in that column are **inherited from the previous
revision of this file and NOT independently verified** — and that file is known to have
carried false rows (see the tombstone below), so treat them as candidates and confirm
against Adobe's system-requirements page before gating anything on them. They are listed
because a stale hint beats a silent gap, not because they are trustworthy.

Raw constraints, for reference:

| Tag   | `require.php`                  |
|-------|--------------------------------|
| 2.4.4 | `~7.4.0\|\|~8.1.0`             |
| 2.4.5 | `~7.4.0\|\|~8.1.0`             |
| 2.4.6 | `~8.1.0\|\|~8.2.0`             |
| 2.4.7 | `~8.1.0\|\|~8.2.0\|\|~8.3.0`   |
| 2.4.8 | `~8.2.0\|\|~8.3.0\|\|~8.4.0`   |
| 2.4.9 | `~8.3.0\|\|~8.4.0\|\|~8.5.0`   |

Notes, each of which contradicts a plausible assumption:

- **2.4.8 did NOT drop PHP 8.2.** It dropped only 8.1; 8.2 remains installable across the
  whole line (`2.4.8` through `2.4.8-p5` all declare `~8.2.0||~8.3.0||~8.4.0` — verified
  tag by tag). Adobe's system-requirements page lists 2.4.8-p5 as 8.3/8.4 because 8.2 has
  reached its own upstream EOL — that is a *support* statement, not a constraint change.
  **PHP 8.2 is dropped in 2.4.9**, not 2.4.8.
- **2.4.5 still installs on PHP 7.4** — same constraint as 2.4.4. Adobe supported only 8.1.
- **2.4.9 installs on PHP 8.3, but do not target it.** Release notes: "PHP 8.3 is allowed
  for upgrade purposes only (not recommended for production)" and "Adobe Commerce 2.4.9 now
  supports PHP 8.5 and PHP 8.4". Treat 8.3 as a stepping stone, 8.4 as the production floor.
- **PHP 8.5 first appears in 2.4.9.**

> **REGRESSION TOMBSTONE.** Before 2026-07-16 this table claimed 2.4.8 required a minimum
> of PHP 8.3 and that it "dropped PHP 8.1 and 8.2", marked `status: live` — the marker that
> authorizes confirmed findings. Both claims were false against the tag. It also listed
> 2.4.5 as 8.1-only. Verify this table against `composer.json` at the tag, not against
> prose in a release note, and never mark a row `live` on a docs page alone.

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

- *(status: live)* **PHP 8.1 dropped; minimum 8.2** (8.2, 8.3, 8.4 installable). 8.2 is
  NOT dropped here — see the table notes above.
- *(status: illustrative)* `Magento\Framework\App\Config\ScopeConfigInterface::isSetFlag()`
  returns strict bool — confirm before acting.
- *(status: illustrative)* `Magento\Quote\Api\CartManagementInterface::placeOrder()` may
  now throw `LocalizedException` instead of `\Exception` — narrower catch handles. Confirm
  against release notes.

## 2.4.9

GA **2026-05-12**. The largest dependency shift since 2.4.0 — a module can compile against
2.4.8 and fail hard on 2.4.9 without touching any Magento API, because the change is mostly
*underneath* the framework.

Sources: [release notes][rn249] (Adobe), [BIC highlights][bic] (Adobe), and the
`composer.json` / `lib/web` trees at tags `2.4.8` and `2.4.9` (verified 2026-07-16).

[rn249]: https://experienceleague.adobe.com/en/docs/commerce-operations/release/notes/adobe-commerce/2-4-9
[bic]: https://developer.adobe.com/commerce/php/development/backward-incompatible-changes/highlights/

### Platform

- *(status: live)* **PHP 8.2 dropped.** Installable on 8.3, 8.4, 8.5; Adobe supports 8.4
  and 8.5, and allows 8.3 "for upgrade purposes only (not recommended for production)".
- *(status: live)* **PHPUnit 10.5 → 12.0** (`require-dev`). A two-major jump: generated and
  existing tests must target PHPUnit 12.

### Dependency removals — the high-risk surface

- *(status: live)* **`laminas/laminas-mvc` REMOVED** (was `^3.6`). Replaced by a native MVC
  implementation: *"Adobe Commerce has introduced a native MVC implementation, replacing the
  legacy Laminas MVC, to ensure long-term compatibility and stability beyond PHP 8.5."*
  Any module type-hinting or extending `Laminas\Mvc\*` breaks with a class-not-found error.
- *(status: live)* **`magento/magento-zf-db` REMOVED** (was `^3.21`). `php-db/phpdb ^0.4` is
  added in its place.
- *(status: live)* **Laminas is NOT gone.** `laminas/*` package count went **17 → 19** —
  `laminas-server`, `laminas-session` and `laminas-view` were *added*. Only `laminas-mvc`
  was removed. Do not scan for "any `Laminas\` usage" and call it a break.

### Dependency upgrades that break subclasses

- *(status: live)* **Symfony `^6.4` → `^7.4` LTS**, across all Symfony packages.
  Per the BIC page: *"Custom classes that extend Symfony core classes must have updated type
  declarations and method signatures aligned with Symfony 7.4."*
- *(status: live)* **Zend_Cache → `symfony/cache ^7.4`** (newly added). Adobe calls the swap
  *"transparent and backward compatible"* for cache commands, but *"extensions depending on
  Zend_Cache classes must be updated to use Symfony cache APIs"*. Reported as 30–50% faster
  with reduced Redis load.
- *(status: live)* Also newly required: `predis/predis ^2.0`, `stomp-php/stomp-php ^5.1`,
  `spomky-labs/aes-key-wrap ^7.0`.

### Frontend

- *(status: live)* **TinyMCE → HugeRTE.** `lib/web/tiny_mce_6` is **removed** and
  `lib/web/hugerte` **added** (verified against the trees, not the prose — note the real
  directory is `tiny_mce_6`, not `tinymce`). Adobe's reason: *"Due to the end of support for
  TinyMCE 5 and 6 and licensing incompatibilities with TinyMCE 7, the Adobe Commerce WYSIWYG
  editor has been migrated to the open-source HugeRTE editor."* Affects custom WYSIWYG admin
  fields, CMS/Page Builder workflows, and any custom TinyMCE plugin.

### GraphQL input limits — new runtime rejections

Both are configurable at **Stores > Configuration > Services > Magento Web API > GraphQL
Input Limits**. Generated queries must stay under them:

- *(status: live)* **Max 10 aliases per request.** *"Validation was added to limit the number
  of aliases in GraphQL requests to ten."*
- *(status: live)* **Query length limit, default 1,048,576 characters (~1 MB).** Queries over
  the limit are rejected before processing.

### REFUTED — do not encode these

Each sounds plausible and each is false against the 2.4.9 tree. They are recorded here so
the next refresh does not "rediscover" them:

- **jQuery was NOT removed.** `lib/web/jquery` and `lib/web/jquery.js` are both present at
  2.4.9. Only *upgrades* shipped (jQuery UI 1.14.1, jQuery Validate 1.21.0).
- **RequireJS was NOT removed.** `lib/web/requirejs` is present at 2.4.9. `knockoutjs` and
  `prototype` are present too.
- **`carlos-mg89/oauth` was NOT removed in 2.4.9.** It is absent from *both* 2.4.8 and
  2.4.9, so there is no 2.4.9 change here.
- **Elasticsearch was NOT dropped.** `elasticsearch/elasticsearch ^8.15` is required at both
  2.4.8 and 2.4.9, even though Adobe's system-requirements page stops listing ES for 2.4.9.
  The two primary sources disagree; the constraint is the harder evidence. Do not report ES
  as removed.

### Not verified

Declarative-schema changes, module-structure changes, core adoption of PHP 8.4/8.5
attributes, and UI-component structural changes are **not mentioned in any primary source**
checked. Treat as no-change until proven otherwise.

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

The 2.4.9 removals are the most reliably detectable breaks in the matrix — a removed class
is a hard grep, not a judgement call:

```yaml
- version: 2.4.9
  api: Laminas\Mvc
  grep: 'Laminas\\Mvc\\'
  break_type: removed_dependency
  replacement: |
      laminas/laminas-mvc is removed in 2.4.9 (native MVC). Port to the framework's own
      MVC classes. NOTE: scope the pattern to `Laminas\Mvc\` — other laminas/* packages
      remain (the count went 17 -> 19), so a bare `Laminas\` match is a false positive.

- version: 2.4.9
  api: Zend_Cache
  grep: 'Zend_Cache'
  break_type: removed_dependency
  replacement: |
      Replaced by symfony/cache. Cache commands are backward compatible, but classes
      depending on Zend_Cache must move to the Symfony cache APIs.

- version: 2.4.9
  api: tinymce
  grep: 'tiny_mce_6|tinymce|TinyMCE'
  break_type: removed_asset
  replacement: |
      lib/web/tiny_mce_6 is removed; the WYSIWYG editor is HugeRTE (lib/web/hugerte).
      Port custom editor plugins and any adminhtml field wiring the TinyMCE adapter.
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
`magento/magento-coding-standard`; on Mage-OS the fork is `mage-os/magento-coding-standard`,
pinned in lockstep with core).

The matrix is curated, not exhaustive — always pair scanner output with manual review of
release notes for the target version.

### How to refresh it (and how this file got two false rows)

Prose and constraints disagree, and prose loses. Adobe's own pages contradicted each other
on 2.4.9's PHP support, and the PHP table here carried a wrong `status: live` row for 2.4.8
that came from reading a release note instead of the tag. So:

1. **Read the constraint from the tag, not from a docs page.** One command settles PHP
   support, and it is the same thing composer will enforce:
   ```bash
   curl -s https://raw.githubusercontent.com/magento/magento2/2.4.9/composer.json \
     | python3 -c 'import json,sys; print(json.load(sys.stdin)["require"]["php"])'
   ```
2. **Diff the trees for removals**, rather than trusting a changelog's framing. Comparing
   `require`/`require-dev` and `lib/web` across two tags surfaces removals the notes omit —
   `magento/magento-zf-db` was missing from every summary consulted — and refutes ones they
   imply.
3. **Only mark `status: live` for something confirmed against a primary source**, and record
   *which*. A docs page alone is not enough for a constraint claim.
4. **Record refutations, not just facts.** "jQuery was removed in 2.4.9" is plausible,
   widely repeated, and false; without a tombstone the next refresh re-adds it.

Mage-OS tracks these same breaks downstream on its own version line (Mage-OS 3.x is based on
Magento 2.4.9). Resolve a Mage-OS store's base version before using this matrix — see
`magento2-context/references/version-resolution.md`.
