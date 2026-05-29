# BC-Break Notification Format

When the upgrade introduces a BC break visible to callers of the module, document it in
`UPGRADE.md` at the module root.

## File Location

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/UPGRADE.md
```

One `UPGRADE.md` per module. Append to the existing file — never overwrite — so the
history of breaks across versions is preserved.

## Section Per Upgrade

```markdown
## 2.0.0 — 2026-05-24

### Breaking changes

- **Removed `OrderRepository::loadByIncrementId(string $id)`**
  - Reason: replaced by `OrderRepository::getByIncrementId(string $id): OrderInterface`.
  - Migration: rename calls; the new method throws `NoSuchEntityException` instead of
    returning null.

- **Changed return type of `Calculator::compute(float $price): float` → `Calculator::compute(float $price): Money`**
  - Reason: avoid float precision errors.
  - Migration: callers receive a `Money` value object. Use `$money->amount()` to get the
    underlying float, or update calling code to use `Money` arithmetic.

### Deprecations (will break in 3.0)

- `Service\OldThing::doStuff()` — use `Service\NewThing::doStuff()`. Will be removed in
  the next major version.

### Non-breaking improvements

- Added `--verbose` flag to `bin/magento {vendor}:{module}:export`.
- Performance: query count reduced from 1+N to 1 in the listing endpoint.
```

## Per-Break Required Fields

| Field | Required | Notes |
|-------|----------|-------|
| Title | Yes | What changed, in code-form |
| Reason | Yes | Why the break was necessary |
| Migration | Yes | How callers update their code |

Without all three, the BC break is not documented enough — callers can't act on it.

## Severity

Use the shared severity scale:
- **Critical / High** = breaking changes that affect every caller (removed methods,
  changed return types).
- **Medium** = deprecations with a long grace period.
- **Low / Info** = renames with backward-compatible aliases, internal-only changes.

## When NOT to Write a BC Break

Internal classes (not part of `@api`-tagged interfaces) don't require UPGRADE.md entries.
Magento's own deprecation policy says only `@api` is contract — everything else is
internal. If your module has no `@api` annotations, document fewer entries.

## Auto-Detection from Diff

The skill can suggest BC-break entries by:

1. Scanning the diff for removed public methods on `@api`-tagged interfaces.
2. Scanning the diff for changed return types on public methods.
3. Scanning the diff for changed required-arg signatures on public methods.

The user reviews each suggestion before committing.

## Composer Version Bump

A BC break requires a major version bump in `composer.json`. The skill flags this in the
final report: "BC breaks detected — bump module version from `1.x.x` → `2.0.0`."

If `composer.json` is not at major-version boundary after BC breaks, refuse to mark the
upgrade complete.
