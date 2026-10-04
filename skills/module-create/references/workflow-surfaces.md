# Step 4 — Generate Implementation Files (Detail)

Part of the `module-create` skill — read at Step 4 (Generate implementation files).

- Work surface by surface in the order from the "Generate surfaces in order" Core Rule.
- Use the matching template from `templates/` as the structural base for each file type.
- Apply `references/naming-conventions.md` to all identifiers: classes, interfaces, tables,
  config paths, ACL IDs, route handles, event names.
- Apply `references/composer-metadata.md` rules to `composer.json` — including the `authors` block.
  Derive the author **name** from `git config user.name` (fallback `gh api user` for the GitHub
  identity) and the **email** from `git config user.email`. Do not use `{Vendor}` as the author
  name; ask the user only if both git and GitHub identities are empty.
- Create the shared compliance files (both always required):
    - `LICENSE.txt` from `templates/LICENSE.txt` (proprietary EULA using `{Vendor}`). Its contents
      must match the composer `license` field — if `license` is an SPDX id (`OSL-3.0`, `MIT`, …),
      write that license's standard text instead.
    - `.gitignore` from `templates/gitignore` (write it to the module root **with** the leading dot).
- Apply these rules to **every generated PHP file**:
    - **Coding style:** follow PER-CS 3.0 as the baseline; where it conflicts with the
      Magento 2 coding standard or framework requirements, Magento 2 wins. `--standard=Magento2`
      PHPCS is the enforcement gate. See `context/references/php-coding-style.md`.
      (The specific Magento-precedence cases below — `strict_types`, PHPDoc FQCN, naming — are
      where Magento overrides the PER-CS default.)
    - `<?php` on line 1, then `declare(strict_types=1);`. Do **not** hand-write the copyright
      header — it is applied uniformly to every PHP file by the stamp step in Step 5.
    - Namespace `{Vendor}\{ModuleName}` plus sub-namespace matching the directory path.
    - All constructor parameters and return types explicitly typed; no missing type hints.
    - Constructor injection only; promoted `readonly` properties; no `ObjectManager::getInstance()`.
    - Forbidden: `echo`, `print`, `die()`, `exit()`, `var_dump()`, `eval()`, `@` operator.
    - **PHPDoc on every public method in every generated PHP file** — not only `Api/` and `Service/`
      classes. Applies to controllers, observers, plugins, ViewModels, cron jobs, consumers, data
      patches, and repository implementations. Load `references/phpdoc-rules.md` once at the start
      of Step 4 and apply its rules to all PHP files generated in this step.
      Required per method: one-line summary ending with a period; `@param` with FQCN for object types;
      `@return` with FQCN for non-void methods; `@throws` for catchable exceptions only.
    - Constructor PHPDoc: required when the constructor has parameters — one `@param` per injected
      dependency with FQCN; no `@return` on constructors.
    - Fluent setters: `@return $this` in concrete classes, `@return static` in interfaces.
    - `{@inheritDoc}` acceptable when a concrete class implements an interface method with no
      behavioural differences; use full PHPDoc when adding `@throws` or changing documented behaviour.
    - All `Api/` interfaces: `@api` annotation on the interface docblock.
    - `@throws` only for exceptions callers are expected to handle.
    - Extension-attribute PHPDoc (critical — Category 6 FAIL without this):
      `getExtensionAttributes()` `@return` must be the entity-specific interface
      `\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null`,
      NOT the generic `\Magento\Framework\Api\ExtensionAttributesInterface`.
      Same rule for `setExtensionAttributes()` `@param`. Apply to both the DTO interface and
      its Model implementation.
- Apply these rules to **every generated XML file**:
    - Well-formed XML with correct `xsi:noNamespaceSchemaLocation` per file type.
    - `etc/module.xml`: no `setup_version`; `<sequence>` only for concrete load-order dependencies.
    - `etc/acl.xml`: root resource `{Vendor}_{ModuleName}::main`; child `{Vendor}_{ModuleName}::config`
      when admin config surface is declared.
    - `etc/adminhtml/system.xml`: every `<section>` protected by
      `<resource>{Vendor}_{ModuleName}::config</resource>`.
- For `.phtml` templates: all output through `$escaper->escapeHtml(__('…'))` or the appropriate
  `escapeHtmlAttr`, `escapeUrl`, `escapeJs`, `escapeCss` variant. Never `$block->escape*()`.
- For POST controllers: implement `HttpPostActionInterface`; inject `FormKeyValidator`.
- For admin controllers: declare `public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';`.
- When `persistence` and `service_contracts` are both declared, populate `etc/di.xml` with:
  repository interface preference, DTO preference, and SearchResults preference. Use the
  commented-out examples in `templates/di.xml` as the base — uncomment and fill in all
  `{placeholders}`.
- For persistence surfaces: table names as `{vendor_lower}_{module_lower}_{entity}` (snake_case).
  Create `etc/db_schema_whitelist.json` as `{}`. Do not write the regeneration command into
  `README.md` yourself — `docs` (Step 6) includes
  `setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleName}` in the generated
  README's Installation section whenever the module has `db_schema.xml`; this skill also
  surfaces the same command as a Step 7 next step.
