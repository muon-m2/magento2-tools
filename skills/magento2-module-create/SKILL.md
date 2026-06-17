---
name: magento2-module-create
description:
    Create a new Magento 2 module under the project's vendor namespace. Use when asked to create,
    scaffold, generate, or build a Magento 2 module, extension, component, or package. Produces a
    module where every generated file immediately passes all 12 magento2-module-review categories.
    The skill is surface-driven: it only creates files required for declared surfaces and never
    leaves empty placeholder files. Works without a running Magento instance, Docker, or installed
    Composer dependencies. For a standalone admin form use magento2-adminhtml-form, a GraphQL
    surface use magento2-graphql-create, or a single EAV attribute use magento2-eav-attribute —
    this skill scaffolds a new module/extension, not a single sub-surface.
---

# Magento 2 Module Create

Create Magento 2 modules surface-by-surface. Every file generated must pass the `magento2-module-review`
checklist with zero post-creation fixes required.

## Core Rules

- **Resolve context first.** Invoke the `magento2-context` skill at the start of Step 1 and use its
  resolved values for `{Vendor}`, `{runner}`, `{magento_cli}`, `{php_constraint}`, and
  `{framework_constraint}`. Do not re-resolve these independently.
- **Never guess.** If module name, purpose, or surfaces are ambiguous, ask before generating any files.
- **Surface-driven.** Create only files required by explicitly declared surfaces. Do not create empty
  placeholder directories or stub files for undeclared surfaces.
- **Use a template for every file.** Every file type listed in `references/surfaces.md` maps to a
  template under `templates/`. Do not invent file content from prose rules when a template exists.
- **Compliance-first.** Every generated file satisfies all applicable review categories on creation.
  No compliance TODOs remain after the skill completes.
- **Script-then-fill.** Use `${CLAUDE_SKILL_DIR}/scripts/create-dirs.sh` for directory structure; use `templates/` as
  the
  base for each file type; use AI to fill in module-specific implementation content.
- **Verify before done.** Run available static tools after generation. Do not mark creation complete if
  any PHP file fails `php -l` or any XML file fails `xmllint`.
- **Generate surfaces in order.** When surfaces are independent, follow:
  `core` → `persistence` → `service_contracts` → `admin_config` → `admin_ui` → `frontend_ui`
  → `rest_api` → `graphql` → `cron` → `queue` → `extensions`.

## Workflow

1. **Resolve module identity and load project context.**
    - Read `$ARGUMENTS`. If empty: ask *"What is the module name (PascalCase, e.g. `OrderExport`) and
      which surfaces does it need?"* and wait.
    - Validate module name: PascalCase, letters only, 2–50 characters. Reject anything else.
    - **Invoke `magento2-context`** via the `Skill` tool (or run
      `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`). Capture the JSON as `{ctx}`.
      Use `{ctx.vendor}` for `{Vendor}`, `{ctx.php_constraint}` for the composer.json `php` value,
      `{ctx.framework_constraint}` for `magento/framework`, and `{ctx.runner}`/`{ctx.magento_cli}`
      for any tool invocations. If `{ctx.vendor}` is null, ask the user for the vendor prefix.
      If `{ctx.php_constraint}` is null and the project has no `src/composer.json`, ask the user.
    - Set `{module_lower}` = ModuleName converted to snake_case (see
      `magento2-context/references/naming.md`).
    - Resolve the target path: `{ctx.module_dir}/{Vendor}/{ModuleName}`
      (typically `{ctx.magento_root}/app/code/{Vendor}/{ModuleName}`). Abort if the directory already exists
      unless `--mode=augment` is set.
    - Map the user's description to surfaces using `references/surfaces.md`.
    - Present a **module profile** — vendor, name, path, surfaces, estimated file count — and confirm
      before proceeding for multi-surface modules. Single-surface requests may proceed without
      confirmation.

2. **Build creation plan.**
    - For each declared surface, list the exact files to create using `references/surfaces.md`.
    - Shared files created regardless of surfaces: `registration.php`, `etc/module.xml`, `composer.json`,
      `etc/di.xml`, `README.md`, `CHANGELOG.md`.
    - Auto-add `i18n/en_US.csv` when any UI surface (`admin_ui`, `frontend_ui`) is declared.
    - Auto-add `Test/Unit/` for all non-vendor modules.
    - Gather open questions about entity names, service method signatures, or config paths.
      Ask them all at once — do not interrupt mid-generation.
    - For modules with ≥ 3 surfaces or ≥ 20 estimated PHP files: present the full plan and ask for
      confirmation before generating.

3. **Create directory structure.**
    - Run `${CLAUDE_SKILL_DIR}/scripts/create-dirs.sh {Vendor} {ModuleName} {surface...}` from the workspace root.
      Resolve `{Vendor}` from `magento2-context.vendor` and export `MODULE_DIR` from
      `magento2-context.module_dir` so the script writes to the correct path (it auto-detects
      `src/app/code` vs `app/code` if `MODULE_DIR` is not set).
    - Verify exit code 0 before proceeding.
    - If the script is unavailable: use the `Bash` tool with `mkdir -p` for each surface's directory
      list from `references/surfaces.md`. Report unavailability; do not abort.

4. **Generate implementation files.**
    - Work surface by surface in the order from Core Rule 6.
    - Use the matching template from `templates/` as the structural base for each file type.
    - Apply `references/naming-conventions.md` to all identifiers: classes, interfaces, tables,
      config paths, ACL IDs, route handles, event names.
    - Apply `references/composer-metadata.md` rules to `composer.json`.
    - Apply these rules to **every generated PHP file**:
        - **Coding style:** follow PER-CS 3.0 as the baseline; where it conflicts with the
          Magento 2 coding standard or framework requirements, Magento 2 wins. `--standard=Magento2`
          PHPCS is the enforcement gate. See `magento2-context/references/php-coding-style.md`.
          (The specific Magento-precedence cases below — `strict_types`, PHPDoc FQCN, naming — are
          where Magento overrides the PER-CS default.)
        - `<?php` on line 1, blank line, then `declare(strict_types=1);`.
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
      Create `etc/db_schema_whitelist.json` as `{}`. Document the regeneration command in
      `README.md` under Installation: `setup:db-declaration:generate-whitelist --module-name={Vendor}_{ModuleName}`.

5. **Verify compliance.**
    - Run `php -l` on every generated PHP file. Fix syntax errors before proceeding.
    - Run `xmllint --noout` on every generated XML file. Fix well-formedness errors before proceeding.
    - Run `composer validate --no-check-publish` on the generated `composer.json`.
    - Run available quality tools opportunistically (phpcs, phpstan) using the same probing approach as
      `magento2-module-review`. Unavailable tools are reported, not treated as failures.
    - Do NOT run `bin/magento setup:di:compile`, `setup:upgrade`, or
      `setup:db-declaration:generate-whitelist` automatically — offer them as next steps.
    - Record all results: pass / fail / skipped per check.

6. **Report and offer next steps.**
    - Show the created file tree (all files, relative to module root).
    - Show the creation checklist status from `references/creation-checklist.md`
      (all 12 categories, each marked ✓ compliant / ⚠ partial / ✗ gap).
    - Show verification results.
    - Offer next steps in priority order:
        1. Fill in implementation TODOs (list specific files and what to add).
        2. When persistence surface declared — generate schema whitelist:
           `docker compose exec -u magento php bin/magento setup:db-declaration:generate-whitelist
           --module-name={Vendor}_{ModuleName}`
        3. Run the `magento2-deploy` skill to enable and deploy.
        4. Run the `magento2-module-review` skill on `{Vendor}/{ModuleName}` to confirm the
           full quality gate (PHPCS, PHPStan, PHPUnit) and all 12 review categories pass.

## Quick Create Mode

Triggered when the user includes: `quick`, `minimal`, `skeleton`, `bare`, or `scaffold only`.

Creates only the **core** surface files:
`registration.php`, `etc/module.xml`, `composer.json`, `etc/di.xml`, `README.md`, `CHANGELOG.md`.

Does not create interfaces, models, controllers, templates, or tests. All files must still fully comply
with Categories 1, 2, and 3 of the review checklist.

After creation, list all skipped surfaces and state:
*"Run `/module-create {ModuleName} {surface}` to add a surface when ready."*

## Surface-to-File Mapping

Load `references/surfaces.md` when building the creation plan. Do not assume surface contents from memory.

| Surface             | Common trigger phrases                                                   |
|---------------------|--------------------------------------------------------------------------|
| `core`              | Always included                                                          |
| `persistence`       | database, table, entity, model, resource model, CRUD, schema, store data |
| `service_contracts` | service, contract, repository, API interface, business logic             |
| `admin_config`      | configuration, settings, system.xml, admin config, store settings        |
| `admin_ui`          | admin grid, admin form, admin panel, backend, adminhtml                  |
| `frontend_ui`       | storefront, frontend, customer-facing, block, template, page             |
| `rest_api`          | REST, web API, endpoint, webapi.xml                                      |
| `graphql`           | GraphQL, resolver, query, mutation                                       |
| `cron`              | cron, scheduled task, recurring job                                      |
| `queue`             | message queue, consumer, async, RabbitMQ                                 |

When the user's description is ambiguous, ask about surfaces explicitly before building the plan.

## Optional Parallel Create

Parallel agent creation requires explicit user authorization. When a module meets the threshold
criteria in `references/parallel-create.md` (≥ 4 surfaces or ≥ 30 estimated PHP files), offer
parallel creation to the user and wait for a yes/no answer before proceeding. Read
`references/parallel-create.md` before spawning agents.

## Reference Files

- `references/surfaces.md`: surface-to-file mapping, **per-file template references**, directory lists,
  and cross-surface integration rules.
- `references/creation-checklist.md`: per-category creation requirements mapping all 12 review categories
  to concrete generation rules.
- `references/naming-conventions.md`: legacy local naming reference — pointer to the shared
  `magento2-context/references/naming.md` (authoritative).
- `references/composer-metadata.md`: `composer.json` constraints, autoload format, and metadata rules.
- `references/phpdoc-rules.md`: full PHPDoc generation rules for all class types — scope, format,
  FQCN requirements, brevity rules, and common mistakes to avoid.
- `references/parallel-create.md`: agent split guidance for large or complex modules.
- `references/docs-format.md`: README.md section structure and CHANGELOG.md format rules.

## Template Inventory

`templates/` contains a template for every file type any surface can produce. When generating any
file, look up its template via `references/surfaces.md`. Do not invent file content from prose.

Templates added in v2 (use these for new surfaces):

- Admin UI: `admin-ui-component-listing.xml`, `admin-ui-component-form.xml`,
  `admin-listing-layout.xml`, `admin-form-layout.xml`, `admin-ui-data-provider.php`,
  `admin-ui-column-actions.php`, `admin-routes.xml`, `menu.xml`
- Frontend UI: `frontend-routes.xml`, `frontend-route-handler.php`, `frontend-layout.xml`,
  `frontend-template.phtml`
- REST API: `webapi.xml`
- GraphQL: `schema.graphqls`, `graphql-resolver.php`, `graphql-batch-resolver.php`
- Cron: `crontab.xml`, `cron-job.php`
- Queue: `communication.xml`, `queue_consumer.xml`, `queue_topology.xml`, `queue_publisher.xml`,
  `consumer.php`
- Extensions: `plugin.php`, `di-plugin.xml`, `observer.php`, `events.xml`, `data-patch.php`,
  `schema-patch.php`
- EAV: the attribute patches are owned by the **`magento2-eav-attribute`** skill (the single
  source — its copies carry the `getAttribute()` idempotency guard). Use
  `magento2-eav-attribute/templates/eav-add-{product,customer,category}-attribute-patch.php`;
  this skill keeps only the supporting `source-model.php`, `backend-model.php`.
- Email: `email-template.html`, `email_templates.xml`
- Tests: `test-controller.php`, `test-observer.php`, `test-plugin.php`, `test-resolver.php`,
  `test-repository.php`