# Placeholder Rules

Magento uses `%1`, `%2`, `%3`, ... as positional placeholders in translatable strings.

## Source vs Target

```
Source: "Hello %1, you have %2 items"
French: "Bonjour %1, vous avez %2 articles"   # OK
German: "Hallo %1, Sie haben Artikel"          # MISMATCH — missing %2
```

The skill detects mismatch by counting placeholder occurrences in both strings.

## Allowed Placeholders

- `%1`, `%2`, `%3`, ... numeric
- `%s` — legacy; Magento's `Phrase` class translates `%s` to `%1`. Avoid `%s` in new code.

## Reordering

Translations may reorder placeholders:

```
EN: "%1 / %2 items"
DE: "%2 von %1 Artikeln"
```

Both placeholders present; order differs. This is correct and accepted.

## Repeated Placeholders

A placeholder may appear multiple times in the same string:

```
EN: "Please confirm %1, then click OK on %1's profile"
```

The skill counts UNIQUE placeholders, not occurrences. The translation must include
the same set:

```
DE: "Bitte bestätigen Sie %1, dann klicken Sie OK auf dem Profil von %1"  # OK
DE: "Bitte bestätigen Sie %1"                                              # MISMATCH
```

## Mismatch Findings

| Mismatch | Severity |
|----------|----------|
| Target uses fewer placeholders than source | Medium |
| Target uses more placeholders than source | Medium |
| Target uses different placeholders (e.g. %1 source, %3 target) | Medium |

A mismatch causes runtime errors in Magento's `Phrase` rendering when an arg isn't
substituted; severity is Medium because it's user-visible.

## Per-Locale Placeholder Quirks

Some locales need extra placeholders for grammatical reasons (gendered articles, plural
forms). Magento doesn't natively support gender/plural variants beyond `%1`. For
language-specific complexity, use:

```
__('%1 item|%1 items', $count)  // Magento doesn't support this; explicit branching needed
```

Currently the skill flags `|` in source strings as a potential issue — Magento doesn't
parse it.

## Validation Algorithm

```python
import re
def placeholders(s):
    return set(re.findall(r'%(\d+|s)', s))

def check(source, target):
    src_set = placeholders(source)
    tgt_set = placeholders(target)
    if src_set != tgt_set:
        return f"mismatch: source has {sorted(src_set)}, target has {sorted(tgt_set)}"
    return None
```

The skill runs this for every row in every target CSV.
