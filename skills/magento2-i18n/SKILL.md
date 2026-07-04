---
name: magento2-i18n
description:
    Translation extraction and management for Magento 2 modules. Use when the user wants
    to extract translatable phrases, add a new locale, sync existing CSV with current
    code, or validate placeholder consistency across locales. Produces or updates
    {Module}/i18n/{locale}.csv files. Optionally machine-translates new locales.
---

# Magento 2 i18n

Translation extraction + merge for a module.

## Core Rules

- **Never overwrite existing translations.** Sync adds new phrases, preserves existing
  values. Removed phrases move to a commented "obsolete" section, NOT deleted.
- **Placeholder consistency.** `%1`, `%2` count in source must match each target locale.
  Mismatches surface as findings.
- **CSV validity always.** Output CSVs are UTF-8 and parseable by Magento's translation
  loader.
- **Magento CLI preferred.** Use `bin/magento i18n:collect-phrases` when available;
  regex fallback otherwise.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture Magento CLI availability.

### Phase 1 — Scope

Ask:

- Modules to extract from (default: all custom modules under `{vendor_lower}/`).
- Target locale(s) (default: `en_US` + all existing locale CSVs).
- Behaviour for missing translations:
    - Leave empty (default)
    - Copy English string
    - Machine-translate (requires API key in env)

### Phase 2 — Extract

If Magento CLI available:

```
{ctx.magento_cli} i18n:collect-phrases {ctx.magento_root}/app/code/{Vendor}/{Module}/ -o /tmp/extract.csv
```

Otherwise: regex scan via `${CLAUDE_SKILL_DIR}/scripts/extract.sh` for:

- `__('text')` and `__("text")` in PHP
- `<label translate="true">text</label>` in XML
- `<item name="..." translate="true">text</item>` in XML
- `$t('text')` in JS
- `data-bind="i18n: 'text'"` in HTML

### Phase 3 — Merge

Run `${CLAUDE_SKILL_DIR}/scripts/merge-csv.sh <fresh.csv> <locale.csv>` for each target locale. The script
guarantees:

- Existing translations are preserved byte-for-byte.
- New phrases are appended at the end with empty translation columns.
- Phrases no longer in the fresh extraction are moved to `<locale>.obsolete.csv` next
  to the locale file. Obsolete phrases are NOT commented in-line — Magento's translation
  loader does not tolerate comments inside the CSV.

### Phase 4 — Validate

Via `${CLAUDE_SKILL_DIR}/scripts/validate-csv.sh`:

- Placeholder consistency: `%1` count in source must match target.
- Character encoding (UTF-8).
- CSV well-formedness (correct quoting, no embedded newlines in unquoted fields).

### Phase 5 — Report

`{output_root}/i18n/{Vendor}_{Module}-{date}.md`:

- Phrases added per locale
- Translations missing per locale
- Placeholder mismatches per locale (if any)
- CSV validation results

## Inputs

```
/magento2-i18n [--locales=en_US,de_DE,fr_FR] [--machine-translate] [--module=<Vendor>_<Module>] [--docs-root=<path>]
```

## Outputs

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/i18n/{locale}.csv (updated)

{output_root}/i18n/{Vendor}_{Module}-{date}.md
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`), anchored at the project root, never
under `{ctx.magento_root}`, `app/code`, or a module dir. See the **Artifact location** rule in
`magento2-context/SKILL.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/i18n/`; otherwise default to
`{ctx.docs_root}/i18n/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `references/extraction-patterns.md` — all translatable patterns + extraction regex.
- `references/csv-format.md` — Magento CSV format rules.
- `references/placeholder-rules.md` — `%1` `%2` etc. consistency.
- `references/machine-translation.md` — provider integration (DeepL, Google, OpenAI).

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/extract.sh` — Magento CLI wrapper or regex fallback.
- `${CLAUDE_SKILL_DIR}/scripts/merge-csv.sh` — deterministic merge: preserves translations, appends new
  phrases, separates obsolete phrases to `<locale>.obsolete.csv`.
- `${CLAUDE_SKILL_DIR}/scripts/validate-csv.sh` — CSV well-formedness + placeholder check.

## Acceptance Criteria

- Existing translations are never overwritten.
- Phrases removed from code are written to `<locale>.obsolete.csv`, not commented
  in-line, and not deleted.
- Placeholder mismatches between source and any locale are surfaced as findings.
- CSV files are valid (parseable by Magento's translation loader).

## Related Skills

| Phase | Skill              |
|-------|--------------------|
| 0     | `magento2-context` |
