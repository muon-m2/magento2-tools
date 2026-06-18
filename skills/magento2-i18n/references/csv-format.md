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

Magento's translation loader does **not** tolerate comments inside the CSV — every row is
a live translation key, so an in-file `"# OBSOLETE …"` fence row would be loaded as a real
(bogus) phrase. The skill therefore moves phrases that no longer appear in the code to a
**separate sibling file** `{locale}.obsolete.csv`, never into `{locale}.csv`:

```
i18n/de_DE.csv           # active translations only — loaded by Magento
i18n/de_DE.obsolete.csv  # phrases dropped from code, retained for reference; NOT loaded
```

`merge-csv.sh` performs this split automatically; the active `{locale}.csv` stays free of
any comment or fence rows.

## Sorting

`merge-csv.sh` **preserves the existing order** of the active `{locale}.csv` and appends
newly-discovered phrases at the end (it does not re-sort), so diffs stay minimal and review
is easy. Obsolete phrases live in the separate `{locale}.obsolete.csv` (see above), not
below a fence.

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
