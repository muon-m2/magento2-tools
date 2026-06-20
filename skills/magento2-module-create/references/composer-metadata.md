# Composer Metadata Rules

Apply these rules to every `composer.json` the skill generates. Violations cause review Category 2
failures. Use `templates/composer.json` as the structural base.

**All version constraints and the vendor name must be derived from project context, not hardcoded.**
See SKILL.md Step 1 for context resolution rules.

---

## Required Fields

| Field                       | Required value                                | How to derive                                             |
|-----------------------------|-----------------------------------------------|-----------------------------------------------------------|
| `name`                      | `"{vendor_lower}/module-{module-kebab-case}"` | `{vendor_lower}` from context; kebab-case from ModuleName |
| `description`               | Non-empty, meaningful string                  | User's stated module purpose                              |
| `type`                      | `"magento2-module"`                           | Fixed — always this exact string                          |
| `license`                   | `"proprietary"` or SPDX identifier            | From project convention or ask user                       |
| `version`                   | Semver string, e.g. `"1.0.0"`                 | Start at `"1.0.0"` unless told otherwise                  |
| `authors`                   | Non-empty array of `{name, email}` objects    | `name` from `git config user.name` (fallback `gh api user`); `email` from `git config user.email` — ask only if both are empty |
| `require.php`               | `{php_constraint}`                            | Read from `src/composer.json` `"php"` field               |
| `require.magento/framework` | `{framework_constraint}`                      | Read from `src/composer.json` `"magento/framework"` field |

**Never substitute a hardcoded PHP or framework version.** If `src/composer.json` is unreadable, ask
the user: *"What PHP and magento/framework version constraints does this store use?"*

**PHP constraint format guidance** (for understanding the value you read from context):

- Three-part tilde `~X.Y.Z` constrains to the X.Y patch series (`>=X.Y.Z, <X.(Y+1).0`) — preferred.
- Two-part tilde `~X.Y` expands to `>=X.Y, <(X+1).0` — allows a future major version, use only if
  the project's existing `composer.json` uses this form.
- Never use `*`, `>=X.Y`, or `^X` for the `php` constraint.

---

## Autoload Block

```json
"autoload": {
    "files": [
        "registration.php"
    ],
    "psr-4": {
        "{Vendor}\\{ModuleName}\\": ""
    }
}
```

Rules:

- `"files"` must include `"registration.php"` — this triggers module registration during Composer
  autoload bootstrap without requiring an explicit `require_once`.
- Use PSR-4 only. Never PSR-0.
- The namespace key must end with `\\` (one backslash in the actual string, encoded as `\\` in JSON).
- The path value is `""` — the module root directory. Never `"src/"` or any subdirectory.
- The namespace prefix must exactly match the module's PHP namespace root (`{Vendor}\{ModuleName}`).

---

## Dependency Declaration

When the module directly uses a class from another Magento module:

- Add `"magento/module-{kebab-case}": "{constraint}"` to `require`.
- Use the same constraint operator already in use by the store's `src/composer.json` for that package.

When the module depends on another module from the same vendor:

- Add `"{vendor_lower}/module-{kebab-case}": "^1.0"` to `require`.

Example for a module using Catalog and Store (version values taken from `src/composer.json`):

```json
"require": {
    "php": "{php_constraint}",
    "magento/framework": "{framework_constraint}",
    "magento/module-catalog": "^{catalog_version}",
    "magento/module-store": "^{store_version}"
}
```

---

## What Must NOT Appear

| Forbidden                                     | Why                                                                           |
|-----------------------------------------------|-------------------------------------------------------------------------------|
| `"*"` in any `require` value                  | Unbounded — resolves unpredictably                                            |
| `"psr-0"` in `autoload`                       | Deprecated; causes PHPCS warning                                              |
| `setup_version`                               | Belongs in `module.xml` (and is deprecated there too)                         |
| Hardcoded credentials in `extra` or `config`  | Secret leak                                                                   |
| `"replace"` entries                           | Only valid when explicitly replacing a deprecated package — must be justified |
| Literal version numbers copied from this file | Versions come from `src/composer.json`, not this document                     |

---

## License File & Copyright Headers

The `license` field is not enough on its own — Marketplace/EQP also requires a matching license
**file** and a copyright header in source files:

- **`LICENSE.txt` at the module root is mandatory** and its contents must match the declared
  `license` field. Write it from `templates/LICENSE.txt` (proprietary EULA, using `{Vendor}`). If the
  `license` field is an SPDX identifier (`OSL-3.0`, `AFL-3.0`, `MIT`, …), replace the body with that
  license's standard text instead, keeping file and field in sync.
- **Every generated PHP file carries a copyright header** pointing at `LICENSE.txt`. Do not hand-write
  it per file — it is applied uniformly by the shared
  `magento2-context/scripts/add-license-headers.sh` (see SKILL.md Step 5). The
  header is generic on purpose (it references `LICENSE.txt` rather than restating terms), so the same
  block is correct for both proprietary and OSI licenses.

README and CHANGELOG format rules are in `references/docs-format.md`.
