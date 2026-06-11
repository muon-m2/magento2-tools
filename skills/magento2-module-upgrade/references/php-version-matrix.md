# PHP Version BC-Break Matrix

Key BC breaks introduced between PHP versions that the upgrade scanner should detect.

## 8.0 → 8.1

- `Magento\Framework\Filesystem\Io\File::checkAndCreateFolder()` — null-byte injection
  protected; passes that relied on previous lenient validation now fail.
- Internal classes implementing `Magento\Framework\Stdlib\StringUtils` must declare
  return types or trigger deprecation.
- `enum` keyword reserved (enums introduced in 8.1).
- `readonly` properties introduced.

  (Note: implicitly nullable parameters are NOT deprecated here — that deprecation lands
  in 8.4. See below.)

## 8.1 → 8.2

- Dynamic properties deprecated; classes setting `$this->foo = 'x'` on an undeclared
  property trigger `Deprecated`. Add `#[AllowDynamicProperties]` or declare the property.
- `${name}` string interpolation deprecated; use `{$name}`.
- `utf8_encode` / `utf8_decode` deprecated.
- New `readonly` class keyword.

## 8.2 → 8.3

- `#[Override]` attribute available — encourages explicit override declaration.
- Typed class constants — many Magento `const` declarations can now be typed.
- `mt_rand()` is **not** removed and remains fully available; prefer `random_int()` /
  `random_bytes()` only for security-sensitive values (tokens, nonces, password resets).
- Negative array-key auto-increment behaviour change; readonly amendments via
  `__clone` (`readonly` props may be reinitialised inside `__clone`).

## 8.3 → 8.4

- Property hooks (`get { ... } set { ... }`) available.
- Implicitly nullable parameter types **deprecated** (E_DEPRECATED only — NOT an error,
  NOT removed): `function foo(int $x = null)` → `function foo(?int $x = null)`. Removal is
  targeted for PHP 9.0. This is the first version where the deprecation fires.
- `new` without parentheses in expressions allowed; several `mb_*` and `round()` changes.

## Detection Patterns

```yaml
- php_version: 8.2
  pattern: '\$this->\w+\s*=' # rough — needs AST narrowing
  break_type: dynamic_property_deprecation
  remediation: |
    Declare the property with the correct type in the class, OR add
    #[AllowDynamicProperties] on the class if dynamic properties are intentional.
```

The real implementation uses Rector + PHPStan to detect these; this matrix lists the
"what" so a manual review can spot what tools miss.

## Strategy

| Break                        | Auto-fix?                                              |
|------------------------------|--------------------------------------------------------|
| Implicit nullable params     | Rector — yes                                           |
| Dynamic property deprecation | Rector — partial (can add `#[AllowDynamicProperties]`) |
| `${name}` interpolation      | Rector — yes                                           |
| Removed functions            | Manual — replacement is context-dependent              |
| `enum` keyword conflict      | Manual — class/var rename                              |

## Composer Constraint

After upgrading PHP target, update `composer.json`:

```json
{
  "require": {
    "php": "~8.3.0"
  }
}
```

Run `composer validate` after the bump.
