# Creation Checklist

Maps all 12 magento2-module-review categories to concrete generation requirements.
Use during Step 4 (generate) and Step 5 (verify) to confirm each file is compliant before reporting done.

Mark each item as ✓ (compliant), ⚠ (partial), or ✗ (gap) in the final report.

---

## Category 1 — Structure & File Layout

Must create:
- [ ] `registration.php` (always)
- [ ] `composer.json` (always)
- [ ] `etc/module.xml` (always)
- [ ] `etc/di.xml` (always)
- [ ] `README.md` (always)
- [ ] `CHANGELOG.md` (always)
- [ ] `etc/db_schema_whitelist.json` (when `persistence` surface declared)

Must NOT create:
- [ ] No `Helper/` directory (use `Service/` or `ViewModel/`)
- [ ] No `Setup/InstallSchema.php`
- [ ] No `Setup/UpgradeSchema.php`

---

## Category 2 — Registration & Declaration

`registration.php`:
- [ ] Uses `ComponentRegistrar::MODULE`
- [ ] Module name literal exactly `{Vendor}_{ModuleName}` — matches both `registration.php` and `etc/module.xml`

`etc/module.xml`:
- [ ] No `setup_version` attribute on the `<module>` element
- [ ] `<sequence>` entries present only for concrete load-order dependencies
- [ ] `name` attribute matches the registered name in `registration.php`

`composer.json` (see also `references/composer-metadata.md`):
- [ ] `"type": "magento2-module"`
- [ ] PSR-4 autoload (not PSR-0)
- [ ] Autoload key `"{Vendor}\\{ModuleName}\\"` pointing to `""`
- [ ] `"files": ["registration.php"]` in `autoload`
- [ ] `"php"` constraint present — value derived from `src/composer.json`, not hardcoded
- [ ] `"magento/framework"` constraint present — value derived from `src/composer.json`, not hardcoded
- [ ] `version` field present (semver)
- [ ] `license` field present and non-empty
- [ ] `description` field present and meaningful (not a copy of the module name)
- [ ] No `"*"` version constraints anywhere
- [ ] All `Magento_*` and `{Vendor}_*` dependencies listed explicitly in `require`

---

## Category 3 — Naming Conventions

- [ ] Module directory: PascalCase
- [ ] PHP namespace root: `{Vendor}\{ModuleName}` (sub-namespaces match directory structure)
- [ ] DB tables: `{vendor_lower}_{module_lower}_{entity}` (snake_case, verified in `db_schema.xml`)
- [ ] No class names containing `Helper` or `Manager`
- [ ] All interfaces end with `Interface`
- [ ] All repositories end with `Repository`
- [ ] DTOs live in `Api/Data/`
- [ ] Composer `name` follows `{vendor_lower}/module-{module-kebab-case}`
- [ ] Config paths follow `{vendor_lower}_{module_lower}/{group}/{field}`
- [ ] ACL IDs follow `{Vendor}_{ModuleName}::main` / `{Vendor}_{ModuleName}::config`

---

## Category 4 — PHP Coding Standards

Every generated PHP file must pass all of:
- [ ] `<?php` on line 1, blank line, `declare(strict_types=1);` on the next line
- [ ] All method parameters and return types declared — no missing type hints
- [ ] Constructor injection only — `ObjectManager::getInstance()` absent from production code
- [ ] Promoted `readonly` constructor properties used (requires PHP 8.1+; use when project PHP version supports it)
- [ ] Forbidden constructs absent: `echo`, `print` (outside templates), `die()`, `exit()`,
  `var_dump()`, `eval()`, `@` operator
- [ ] Explicit visibility on every property and method
- [ ] `abstract`/`final` declared before visibility; `static` declared after visibility

---

## Category 5 — PHPDoc Quality

Scope: PHPDoc is required on **every public method in every generated PHP file** — controllers,
observers, plugins, ViewModels, cron jobs, consumers, data patches, repository implementations,
and all `Api/` and `Service/` classes. See `references/phpdoc-rules.md` for the full rule set.

**Class docblock:**
- [ ] Every class and interface has a one-line summary docblock ending with a period
- [ ] `@api` annotation on every interface in `Api/` — no `@api` on concrete classes
- [ ] `@SuppressWarnings(PHPMD.CouplingBetweenObjects)` with inline justification when constructor
  dependency count exceeds 5

**Constructor PHPDoc:**
- [ ] Constructor docblock present when the constructor has parameters
- [ ] One `@param` tag per injected dependency, using FQCN with leading backslash
- [ ] No `@return` tag on constructors

**Public method PHPDoc:**
- [ ] Every public method has a one-line summary sentence ending with a period
- [ ] `@param` and `@return` use FQCN for object/interface types (e.g. `\Magento\Framework\...`)
- [ ] Scalar types (`int`, `string`, `bool`, `float`, `array`, `null`) use short form
- [ ] `@return` present on every non-void public method; `@return void` may be omitted but
  `execute()` methods should include it explicitly
- [ ] Fluent setters: `@return $this` in concrete classes; `@return static` in interfaces
- [ ] `{@inheritDoc}` used only when the implementation matches the interface contract exactly;
  full PHPDoc when behaviour differs or additional `@throws` are declared

**`@throws` rules:**
- [ ] `@throws` present only for exceptions callers are expected to handle (runtime conditions)
- [ ] Each `@throws` uses FQCN; one tag per distinct exception type
- [ ] No `@throws \Exception` (generic)

**`@var` rules:**
- [ ] `@var` added for class properties not covered by a PHP type declaration
- [ ] `@var` omitted when the property already has a PHP typed declaration (redundant)

**Extension-attribute PHPDoc (critical — DI compile failure without this):**
- [ ] `getExtensionAttributes()` `@return` = `\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null`
- [ ] `setExtensionAttributes()` `@param` = `\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface`
- [ ] Applied to both the DTO interface (`Api/Data/`) and the Model implementation
- [ ] NOT the generic `\Magento\Framework\Api\ExtensionAttributesInterface`

---

## Category 6 — Architecture & Best Practices

- [ ] Public API interfaces in `Api/`; DTOs in `Api/Data/` extending `ExtensibleDataInterface`
- [ ] Repositories mediate all data access (no ResourceModel in `Controller/` or `Service/`)
- [ ] DB changes only via `etc/db_schema.xml` — no install/upgrade schema scripts
- [ ] Prefer plugins/observers over `<preference>`; any `<preference>` in `di.xml` has an adjacent comment
- [ ] Heavy or lazily-needed deps declared with `<proxy/>` in `etc/di.xml`
- [ ] Session classes configured with Proxy in `di.xml`
- [ ] Admin UI uses UiComponents — no legacy Block-based grid classes
- [ ] Config values read only via `ScopeConfigInterface` — never directly from DB

---

## Category 7 — Security

- [ ] PHTML output via `$escaper->escapeHtml(__('…'))` (never `$block->escape*()`)
- [ ] No raw SQL — parameterized queries via `AdapterInterface` or repositories
- [ ] POST controllers implement `HttpPostActionInterface` AND inject `FormKeyValidator`
- [ ] Sensitive values use `EncryptorInterface` — never stored plain text
- [ ] Sensitive `system.xml` fields declare
  `<backend_model>Magento\Config\Model\Config\Backend\Encrypted</backend_model>`
- [ ] All controller and API handler inputs validated and sanitised

---

## Category 8 — ACL & REST/GraphQL

- [ ] `etc/acl.xml` present when `admin_ui` or `admin_config` surface declared
- [ ] Root ACL resource ID: `{Vendor}_{ModuleName}::main`
- [ ] Config ACL resource ID: `{Vendor}_{ModuleName}::config` (child of `::main`)
- [ ] Every admin controller declares `public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';`
- [ ] `webapi.xml` — every route has explicit `resource` value; `"anonymous"` has XML comment
- [ ] GraphQL resolvers implement `ResolverInterface`; mutations in `Model/Resolver/Mutation/`

---

## Category 9 — CSP & i18n

- [ ] All user-facing strings in PHP: `__('text')`
- [ ] All user-facing strings in PHTML: `$escaper->escapeHtml(__('text'))`
- [ ] `i18n/en_US.csv` created when any UI surface declared
- [ ] `etc/csp_whitelist.xml` created when the module references external hosts in JS/CSS/templates
  (absent is correct when no external resources; never include `unsafe-inline` or `unsafe-eval`)

---

## Category 10 — Testing

- [ ] `Test/Unit/` directory created (always)
- [ ] `Test/Integration/` directory created (always — populate when integration tests are written)
- [ ] One test class per generated `Service/` class
- [ ] One test class per generated Repository implementation
- [ ] Tests use `createMock()` with typed mocks: `SomeInterface&MockObject`
- [ ] No `getMockBuilder()` calls
- [ ] No `ObjectManager::getInstance()` in tests
- [ ] PHPUnit 10: `setUp(): void`, attributes over annotations where applicable
- [ ] Test methods named descriptively (describe behaviour, not implementation)

---

## Category 11 — Admin Configuration

- [ ] `etc/adminhtml/system.xml` created when `admin_config` surface declared
- [ ] `etc/config.xml` created with production-safe defaults (no non-empty credentials)
- [ ] Every `<section>` in `system.xml` protected by
  `<resource>{Vendor}_{ModuleName}::config</resource>`
- [ ] Config service class reads values via `ScopeConfigInterface` — not directly from DB

---

## Category 12 — Software Design Principles

- [ ] Each generated class has one clear responsibility
- [ ] No service class with > 5 constructor dependencies (or `@SuppressWarnings` with justification)
- [ ] `Api/` interfaces have < 10 public methods each
- [ ] No copy-paste duplication between services or templates
- [ ] Constants defined in DTO interfaces or config classes — no inline magic strings
- [ ] Exceptions are typed (`\Magento\Framework\Exception\*` or domain exceptions); no bare `\Exception`
- [ ] No empty `catch` blocks