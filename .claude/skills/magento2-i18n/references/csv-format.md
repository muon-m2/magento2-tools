# Magento CSV Format

Magento translation files use a simple two-column CSV.

## File Location

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/i18n/{locale}.csv
```

Where `{locale}` is the IETF tag (e.g. `en_US`, `de_DE`, `fr_FR`, `ja_JP`).

## Row Format

```csv
"Original phrase","Translated phrase"
"Hello %1","Bonjour %1"
"Items in cart: %1","Articles dans le panier : %1"
```

Two columns:
1. Source phrase (exactly as it appears in `__()`).
2. Translated phrase.

## Quoting Rules

- ALWAYS quote both fields with double quotes.
- Escape an embedded double quote by doubling it: `"He said ""hi"""`.
- Embedded newlines are NOT supported — phrases must be single-line.

## Encoding

UTF-8 without BOM. Magento's loader rejects UTF-16 and BOM-prefixed files.

## Comments / Obsolete Phrases

Magento doesn't natively support comments. The skill uses a fenced section at the end:

```csv
"Active phrase","Active translation"
...
"# OBSOLETE — last seen in commit abc123",""
"Removed phrase","Old translation"
```

The `# OBSOLETE` line is a regular row; readers know to ignore everything below.

## Sorting

The skill keeps active rows alphabetically by source phrase. Obsolete rows sit below
the fence.

## Missing Translations

A row with empty translation is allowed:

```csv
"Untranslated phrase",""
```

Magento falls back to the source phrase when translation is empty.

## Multi-Module CSVs

Each module has its own CSV. The Magento i18n loader merges across modules at runtime;
the last-loaded module wins on conflict. To override a Magento core phrase, copy it to
your module's CSV with the new translation.

## Validation

The skill validates:
- File is UTF-8
- No BOM
- Each row has exactly 2 fields
- Fields are properly quoted
- No embedded newlines in unquoted fields

A validation failure surfaces as a Medium finding.

## Common Mistakes

- Editing CSV in Excel: Excel re-encodes to UTF-16 or adds BOM. Use a plain-text editor.
- Mixing comma + tab delimiters: Magento uses comma; tabs are rejected.
- Single quotes: Magento expects double quotes; single fails.
- Trailing whitespace inside quoted fields: visible as a different phrase.
