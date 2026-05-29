# Surface Definitions

Each surface maps to a set of directories and files. When a surface depends on another, the dependency
is automatically included in the creation plan. Load this file during Step 2 (build creation plan).

---

## Core (always included)

Required files (no trigger — always created):
- `registration.php`
- `etc/module.xml`
- `composer.json`
- `etc/di.xml`
- `README.md`
- `CHANGELOG.md`

No additional directories beyond `etc/`.

---

## Persistence

**Depends on:** `core` (and `service_contracts` when a Repository is needed)

**Directories:**
- `Model/`
- `Model/ResourceModel/`
- `Model/ResourceModel/{EntityName}/`
- `Setup/Patch/Data/`

**Files:**
- `etc/db_schema.xml` — declarative schema with table definition
- `etc/db_schema_whitelist.json` — initialized as `{}` with regeneration note
- `Model/{EntityName}.php` — implements `{EntityName}Interface`, extends `AbstractModel`
- `Model/ResourceModel/{EntityName}.php` — extends `AbstractDb`
- `Model/ResourceModel/{EntityName}/Collection.php` — extends `AbstractCollection`

**Rules:**
- Table name: `{vendor_lower}_{module_lower}_{entity}` (all lowercase, underscores only).
- Always include `entity_id` primary key (unsigned int, auto-increment).
- Always include `created_at` and `updated_at` timestamp columns.
- `db_schema_whitelist.json` must be present when `db_schema.xml` exists — initialize as `{}`.
  Document the regeneration command in `README.md` (JSON has no comment syntax).
- Never create `Setup/InstallSchema.php` or `Setup/UpgradeSchema.php`.

---

## Service Contracts

**Depends on:** `core`

**Directories:**
- `Api/`
- `Api/Data/`
- `Service/`

**Files:**
- `Api/{EntityName}RepositoryInterface.php` — CRUD operations interface
- `Api/Data/{EntityName}Interface.php` — DTO extending `ExtensibleDataInterface`
- `Api/Data/{EntityName}SearchResultsInterface.php` — extends `SearchResultsInterface`
- `Model/{EntityName}Repository.php` — implements `{EntityName}RepositoryInterface`
  (in `Model/` because it is a concrete implementation, not an API contract)
- `Service/{FeatureName}Service.php` — orchestration service (create only when the user
  describes specific business logic beyond simple CRUD)

**Integration with persistence:** `Model/{EntityName}Repository.php` injects the ResourceModel.
**Integration with rest_api/graphql:** the repository interface methods are the service contract
  exposed via routing — do not duplicate logic in a separate API layer.

**Custom events:** When the module dispatches custom events (e.g. before/after entity save),
  create `etc/events.xml` to declare event names. Use the `/observer` skill to scaffold
  observer classes that listen to those events.

**DTO extension-attributes rule (critical):**
In both `Api/Data/{EntityName}Interface.php` and `Model/{EntityName}.php`, the return type of
`getExtensionAttributes()` must be `\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null`
and `@param` of `setExtensionAttributes()` must be `\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface`.
Using the generic `\Magento\Framework\Api\ExtensionAttributesInterface` causes a DI compile failure.

---

## Admin Config

**Depends on:** `core`

**Directories:**
- `etc/adminhtml/`

**Files:**
- `etc/adminhtml/system.xml` — config fields grouped by section
- `etc/config.xml` — production-safe default values
- `etc/acl.xml` — root `{Vendor}_{ModuleName}::main` + child `{Vendor}_{ModuleName}::config`

**Rules:**
- Every `<section>` in `system.xml` must include:
  `<resource>{Vendor}_{ModuleName}::config</resource>`
- Defaults in `etc/config.xml` must be production-safe — no non-empty API keys, passwords, or tokens.
- Sensitive fields: `<backend_model>Magento\Config\Model\Config\Backend\Encrypted</backend_model>`.
- Config path format: `{vendor_lower}_{module_lower}/{group}/{field}`.
- Read config in PHP via `ScopeConfigInterface::getValue($path, ScopeInterface::SCOPE_STORE, $storeId)`.

---

## Admin UI

**Depends on:** `core`, `admin_config` (for ACL)

**Directories:**
- `Controller/Adminhtml/{EntityName}/`
- `view/adminhtml/layout/`
- `view/adminhtml/templates/`
- `Ui/Component/Listing/`

**Files (with templates):**
- `etc/adminhtml/routes.xml` — `templates/admin-routes.xml`
- `etc/adminhtml/menu.xml` — `templates/menu.xml`
- `etc/acl.xml` (if not already present from `admin_config`) — `templates/acl.xml`
- `Controller/Adminhtml/{EntityName}/Index.php` — `templates/admin-controller-index.php`
- `Controller/Adminhtml/{EntityName}/Edit.php` — `templates/admin-controller-index.php` (adapt)
- `Controller/Adminhtml/{EntityName}/Save.php` — `templates/admin-controller-save.php`
- `Controller/Adminhtml/{EntityName}/Delete.php` — `templates/admin-controller-save.php` (adapt)
- `view/adminhtml/layout/{vendor_lower}_{module_lower}_{entity}_index.xml` — `templates/admin-listing-layout.xml`
- `view/adminhtml/layout/{vendor_lower}_{module_lower}_{entity}_edit.xml` (if CRUD) — `templates/admin-form-layout.xml`
- `view/adminhtml/ui_component/{vendor_lower}_{module_lower}_{entity}_listing.xml` — `templates/admin-ui-component-listing.xml`
- `view/adminhtml/ui_component/{vendor_lower}_{module_lower}_{entity}_form.xml` (if CRUD) — `templates/admin-ui-component-form.xml`
- `Ui/DataProvider/{EntityName}DataProvider.php` — `templates/admin-ui-data-provider.php`
- `Ui/Component/Listing/Column/{EntityName}Actions.php` — `templates/admin-ui-column-actions.php`

**Rules for every admin controller:**
- Declare `public const ADMIN_RESOURCE = '{Vendor}_{ModuleName}::main';`
- POST controllers (`Save`, `Delete`) must implement `HttpPostActionInterface` and inject
  `\Magento\Framework\Data\Form\FormKey\Validator`.
- GET controllers must not mutate state.
- Never return raw data — use `ResultFactory` with appropriate result type.

**Admin route ID:** `{vendor_lower}_{module_lower}` (used as `<route id="...">` value).

---

## Frontend UI

**Depends on:** `core`

**Directories:**
- `Controller/{ControllerName}/`
- `view/frontend/layout/`
- `view/frontend/templates/`
- `ViewModel/`

**Files (with templates):**
- `etc/frontend/routes.xml` — `templates/frontend-routes.xml`
- `Controller/{ControllerName}/Index.php` — `templates/frontend-route-handler.php`
- `view/frontend/layout/{vendor_lower}_{module_lower}_{route}_index.xml` — `templates/frontend-layout.xml`
- `view/frontend/templates/{name}.phtml` — `templates/frontend-template.phtml`
- `ViewModel/{Name}ViewModel.php` — `templates/viewmodel.php` (existing) — implements `ArgumentInterface`
- `i18n/en_US.csv` (auto-included)

**Rules for templates:**
- All output: `$escaper->escapeHtml(__('…'))`, `$escaper->escapeHtmlAttr(…)`, `$escaper->escapeUrl(…)`.
- Never: `$block->escapeHtml()` (deprecated), raw `echo`, raw `print`.
- No business logic in templates — delegate to ViewModel.

**ViewModel rules:**
- Implement `\Magento\Framework\View\Element\Block\ArgumentInterface`.
- Constructor injection only.
- No direct ResourceModel access.

---

## REST API

**Depends on:** `core`, `service_contracts`

**Files (with templates):**
- `etc/webapi.xml` — `templates/webapi.xml`

**Rules for every route:**
- Every `<route>` must have an explicit `resource` attribute:
  - `"self"` — authenticated customer acting on own data
  - `"{Vendor}_{ModuleName}::resource_id"` — admin-only
  - `"anonymous"` — public, requires an adjacent XML comment justifying the decision
- Handler class must be a `service_contracts` interface (never a concrete class).
- Input/output types must use DTO interfaces, not raw arrays.

---

## GraphQL

**Depends on:** `core`, `service_contracts`

**Directories:**
- `Model/Resolver/`
- `Model/Resolver/Mutation/` (if mutations declared)
- `Model/Resolver/Batch/` (if batch resolvers declared)

**Files (with templates):**
- `etc/schema.graphqls` — `templates/schema.graphqls`
- `Model/Resolver/{QueryName}.php` — `templates/graphql-resolver.php`
- `Model/Resolver/Mutation/{MutationName}.php` — `templates/graphql-resolver.php` (adapt for mutation)
- `Model/Resolver/Batch/{Name}BatchResolver.php` — `templates/graphql-batch-resolver.php` (when avoiding N+1)

**Rules:**
- Resolvers implement `\Magento\Framework\GraphQl\Query\ResolverInterface`.
- Batch resolvers implement `\Magento\Framework\GraphQl\Query\Resolver\BatchResolverInterface`.
- Validate store scope and auth in every resolver.
- Mutations live in `Model/Resolver/Mutation/`.
- Avoid N+1 queries — use batch loading where the schema allows multiple items.

---

## Cron

**Depends on:** `core`

**Directories:**
- `Cron/`

**Files (with templates):**
- `etc/crontab.xml` — `templates/crontab.xml`
- `Cron/{JobName}.php` — `templates/cron-job.php`

**Rules:**
- Cron classes must be idempotent and safe to retry (interrupted runs should not produce duplicates).
- Constructor injection only.
- Job name format: `{vendor_lower}_{module_lower}_{description}` (e.g., `acme_order_export_send_pending`).
- Default group: `default` unless async execution is explicitly required.

---

## Queue

**Depends on:** `core`

**Directories:**
- `Model/Consumer/`

**Files (with templates):**
- `etc/communication.xml` — `templates/communication.xml`
- `etc/queue_consumer.xml` — `templates/queue_consumer.xml`
- `etc/queue_topology.xml` (only if a custom exchange or binding is needed) — `templates/queue_topology.xml`
- `etc/queue_publisher.xml` (when this module publishes) — `templates/queue_publisher.xml`
- `Model/Consumer/{ConsumerName}.php` — `templates/consumer.php`

**Rules:**
- Consumer class must be idempotent.
- Constructor injection only.
- Consumer name format: `{vendor_lower}.{module_lower}.{description}`.

---

## i18n (auto-included)

Auto-included when `admin_ui` or `frontend_ui` surface is declared.

**Files:**
- `i18n/en_US.csv` — initially empty file (Magento CSV format: `"phrase","translation"` per line, no header row)

After implementing user-facing strings, regenerate:
```bash
docker compose exec -u magento php bin/magento i18n:collect-phrases \
  app/code/{Vendor}/{ModuleName}/ -o app/code/{Vendor}/{ModuleName}/i18n/en_US.csv
```

Review the output — `i18n:collect-phrases` overwrites the file; check for regressions.

---

## Tests (auto-included for non-vendor modules)

**Directories:**
- `Test/Unit/`
- `Test/Integration/`

**Files (with templates) — one test class per generated source class:**
- Service unit test: `templates/unit-test.php`
- Controller unit test: `templates/test-controller.php`
- Observer unit test: `templates/test-observer.php`
- Plugin unit test: `templates/test-plugin.php`
- GraphQL resolver unit test: `templates/test-resolver.php`
- Repository unit test: `templates/test-repository.php`

All test files must follow PHPUnit 10 conventions. Use `createMock()` with typed
intersection (`SomeInterface&MockObject`) properties. No `getMockBuilder()`.

---

## Extensions (plugin / observer / events / patches)

Optional surfaces declared via the `extensions` flag (or by passing specific items in
the creation plan). These are commonly used both in new modules and when extending an
existing module. To add extensions to an existing module, re-invoke
`magento2-module-create` with `--mode=augment` so the skill writes only the new files
without recreating the module shell.

**Files (with templates):**

| Subsurface | File | Template |
|---|---|---|
| Plugin | `Plugin/{TargetShortName}{Method}Plugin.php` | `templates/plugin.php` |
| Plugin DI wiring | `etc/di.xml` `<type>` fragment | `templates/di-plugin.xml` |
| Observer | `Observer/{DescriptiveName}Observer.php` | `templates/observer.php` |
| Observer event wiring | `etc/events.xml` | `templates/events.xml` |
| Data patch | `Setup/Patch/Data/{PatchName}.php` | `templates/data-patch.php` |
| Schema patch | `Setup/Patch/Schema/{PatchName}.php` | `templates/schema-patch.php` |
| EAV product attribute | `Setup/Patch/Data/Add{Code}Attribute.php` | `templates/eav-add-product-attribute-patch.php` |
| EAV customer attribute | `Setup/Patch/Data/Add{Code}Attribute.php` | `templates/eav-add-customer-attribute-patch.php` |
| EAV category attribute | `Setup/Patch/Data/Add{Code}CategoryAttribute.php` | `templates/eav-add-category-attribute-patch.php` |
| EAV source model | `Model/Source/{Name}.php` | `templates/source-model.php` |
| EAV backend model | `Model/Attribute/Backend/{Name}.php` | `templates/backend-model.php` |
| Email template | `view/frontend/email/{name}.html` | `templates/email-template.html` |
| Email registration | `etc/email_templates.xml` | `templates/email_templates.xml` |

---

## Cross-Surface Integration Rules

| Surface combination | Additional requirement |
|---|---|
| `persistence` + `service_contracts` | Repository uses ResourceModel; DI preference declared in `etc/di.xml` |
| `service_contracts` + `rest_api` | `webapi.xml` handler maps to the repository interface |
| `admin_ui` + `admin_config` | Shared `etc/acl.xml` with `::main` and `::config` resources |
| `admin_ui` + `persistence` | Grid uses UiComponent listing with ResourceModel collection |
| `frontend_ui` + any | `i18n/en_US.csv` auto-included |
| Any surface + `graphql` | Resolvers inject service contract interfaces, not concrete classes |