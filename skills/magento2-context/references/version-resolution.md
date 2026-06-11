# Version Resolution

Algorithm for resolving `magento_version`, `edition`, `php_constraint`, `php_version`,
and `framework_constraint`.

## `edition` and `magento_version`

1. **`src/composer.json`** — read `require`:
    - `magento/product-community-edition` present → `edition = "open-source"`,
      `magento_version` = the constraint value (stripped of operators: `2.4.7-p1`).
    - `magento/product-enterprise-edition` present → `edition = "commerce"`,
      `magento_version` = the constraint value.
    - Else fall through.
    - `resolution_source.edition` = `"src/composer.json:magento/product-{edition}-edition"`.

2. **Magento CLI** — `{magento_cli} --version` if runner available.
   Parse the output (`Magento CLI 2.4.7-p1`).
   `resolution_source.magento_version` = `"{magento_cli} --version"`.

3. **Ask the user.**
   `resolution_source.magento_version` = `"user prompt"`.

## `php_constraint`

1. **`src/composer.json`** — read `require.php`.
   `resolution_source.php_constraint` = `"src/composer.json:require.php"`.

2. **`CLAUDE.md`** — look for `PHP constraint:` or `PHP version:` line.

3. **Ask the user.**

The constraint format is preserved verbatim (e.g. `~8.2.0`, `^8.1`, `>=8.1 <8.4`). Do not
normalize.

## `php_version`

1. **Runner probe** — `{runner} php -r 'echo PHP_VERSION;'` if `runner` is non-null.
   `resolution_source.php_version` = `"{runner} php -r echo PHP_VERSION"`.

2. **`null`** if no runner — record `resolution_source.php_version = "no runner"`.

This is the **actual installed** PHP version, distinct from the constraint.

## `framework_constraint`

1. **`src/composer.json`** — read `require.magento/framework`.
   `resolution_source.framework_constraint` = `"src/composer.json:require.magento/framework"`.

2. **`null`** if not present (rare; only in very stripped-down installs).

## Edge Cases

| Case                                                                | Behaviour                                                                 |
|---------------------------------------------------------------------|---------------------------------------------------------------------------|
| Both community and enterprise editions in composer.json             | Prefer enterprise; record both in `resolution_source`.                    |
| `composer.json` constraint uses an alias (e.g. `dev-main as 2.4.7`) | Use the right-hand version.                                               |
| `magento_version` looks invalid (no major/minor/patch)              | Warn but accept; downstream skills can validate.                          |
| Magento CLI version mismatches composer.json                        | Trust composer.json; warn user.                                           |
| PHP probe fails (extension missing, etc.)                           | `php_version = null`; downstream skills know to skip PHP-specific checks. |
