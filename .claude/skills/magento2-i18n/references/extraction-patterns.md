# Extraction Patterns

Patterns that mark text as translatable in Magento 2.

## PHP

```php
__('Translatable string')
__('String with %1 placeholder', $value)
__("Double-quoted")
```

Regex (rough; AST is more precise):

```
__\(\s*['"](.+?)['"]\s*[,)]
```

## XML (layout, system config, UI components)

```xml
<label translate="true">Translatable label</label>
<title translate="true">Translatable title</title>
<argument name="label" translate="true" xsi:type="string">Translatable</argument>
<item name="label" translate="true">Translatable</item>
```

Regex:

```
<(label|title)[^>]*translate=["']true["'][^>]*>([^<]+)</\1>
<(argument|item)[^>]+translate=["']true["'][^>]*>([^<]+)</\3>
```

## JavaScript

```js
$.mage.__('Translatable string')
$t('Translatable string')      // mage/translate
```

Regex:

```
(?:\$\.mage\.__|\$t)\(\s*['"](.+?)['"]\s*\)
```

## HTML (KO templates)

```html
<span data-bind="i18n: 'Translatable'"></span>
<span data-bind="text: $t('Translatable')"></span>
```

Regex:

```
data-bind="[^"]*i18n:\s*['"](.+?)['"]
data-bind="[^"]*\$t\(['"](.+?)['"]\)
```

## Phtml

`.phtml` files use PHP rules. Look for both:
- `<?= __('...') ?>`
- `<?php echo __('...'); ?>` (legacy)
- Inline JS as above

## What NOT to Extract

- Strings inside SQL queries (typically column names, not user-visible)
- Strings inside `Logger::info()` / `error_log()` calls
- Class names, FQCNs
- Static config paths

The skill applies a heuristic: only extract `__()` arguments that contain at least one
letter (skips numeric-only and punctuation-only).

## Multi-Line Strings

```php
__('Long text
 spanning multiple
 lines')
```

Magento joins multi-line strings into one. The regex must handle the newlines —
extraction should canonicalize to a single line for the CSV.

## Concatenation

```php
__('Hello ') . $name . __('!')
```

Each fragment is extracted separately. Discourage this pattern — use placeholders
instead:

```php
__('Hello %1!', $name)
```

The skill emits a Low-severity finding when concatenation is detected.

## Phrase Object

Magento's `__()` returns a `Phrase` object. Storing as a string then translating breaks
the framework. Always pass to `Phrase` methods or stringify at the LAST moment:

```php
$phrase = __('Hello');
// Don't: (string) $phrase early
// Do: pass $phrase around; stringify on render.
```

The skill flags `(string) __('...')` patterns at extraction time.

## False Positives

`__construct` is NOT a translation call. The regex filters by requiring a string-literal
argument, not bare `__(`.
