# Vendor Resolution

Algorithm for resolving `{vendor}` (the project's vendor prefix).

## Priority Order

1. **`CLAUDE.md` `Vendor prefix:` line.**
   Pattern: `Vendor prefix: **{Name}**` or `Vendor prefix: {Name}` (asterisks optional).
   If present → use the value verbatim (after trim, after stripping markdown emphasis).
   `resolution_source.vendor` = `"CLAUDE.md:Vendor prefix"`.

2. **`src/app/code/` directory inspection.**
   List immediate subdirectories of `src/app/code/`.
   - If exactly one non-Magento directory exists → use that name.
     `resolution_source.vendor` = `"{ctx.magento_root}/app/code/{name}/ (single non-Magento dir)"`.
   - If multiple non-Magento directories exist → ask the user which one is the project's
     vendor.
   - If only `Magento/` exists or the directory is empty → fall through.

3. **`src/composer.json` package-name inspection.**
   Read `require` keys; collect entries matching `^([a-z0-9-]+)/module-`.
   Group by vendor; pick the vendor with the most entries.
   Capitalize for PascalCase output (`acme` → `Acme`).
   `resolution_source.vendor` = `"src/composer.json:require (most-frequent {name}/module-* vendor)"`.

4. **Ask the user.**
   `What vendor prefix does this project use (e.g. Acme)?`
   `resolution_source.vendor` = `"user prompt"`.

## Output

- `vendor` — PascalCase string, letters only (`Acme`, `MyCompany`, `Muon`).
- `vendor_lower` — `vendor` lowercased (`acme`, `mycompany`, `muon`).

## Edge Cases

| Case | Behaviour |
|------|-----------|
| `CLAUDE.md` says `Vendor prefix: acme` (lowercase) | Normalize to PascalCase; record source as `CLAUDE.md (normalized)`. |
| `CLAUDE.md` says `Vendor prefix: My_Company` (underscore) | Reject; ask user — underscores are not valid in vendor names. |
| `src/app/code/` doesn't exist | Skip step 2; fall through to step 3. |
| Multiple vendors equally-common in composer.json | Tied vendors require user disambiguation. |
| Vendor has non-letter characters (e.g. `Acme2`) | Reject; ask user — only letters allowed. |

## Validation

Final `vendor` must match the regex `^[A-Z][a-zA-Z]{1,49}$`. If validation fails, abort
and ask the user.
