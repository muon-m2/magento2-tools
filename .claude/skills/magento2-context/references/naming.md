# Naming Conventions (Shared)

Authoritative naming rules for **all** Magento 2 identifiers. Consumed by every builder
skill (`module-create`, `eav-attribute`, `graphql-create`, `frontend-create`,
`data-migration`).

All patterns use `{Vendor}` and `{vendor_lower}` — resolve via `references/vendor-resolution.md`
before generating.

---

## 1. Module & Package

| Identifier | Pattern | Example |
|---|---|---|
| Module directory | PascalCase, letters only | `OrderExport` |
| PHP namespace root | `{Vendor}\{ModuleName}` | `Acme\OrderExport` |
| Magento module name | `{Vendor}_{ModuleName}` | `Acme_OrderExport` |
| Composer package name | `{vendor_lower}/module-{module-kebab-case}` | `acme/module-order-export` |

### PascalCase Conversions

| Conversion | Rule | Example |
|---|---|---|
| PascalCase → kebab-case | Split on uppercase; lowercase; join with `-` | `OrderExport` → `order-export` |
| PascalCase → snake_case | Split on uppercase; lowercase; join with `_` | `OrderExport` → `order_export` |
| PascalCase → UPPER_SNAKE_CASE | Same split; uppercase; join with `_` | `OrderExport` → `ORDER_EXPORT` |
| `{vendor_lower}` | `{Vendor}` lowercased | `Acme` → `acme` |
| `{VENDOR_UPPER}` | `{Vendor}` uppercased | `Acme` → `ACME` |

---

## 2. PHP Classes & Interfaces

| Type | Pattern | Example |
|---|---|---|
| Interface (any) | `{Name}Interface` | `OrderRepositoryInterface` |
| Repository class | `{Name}Repository` | `OrderRepository` |
| DTO interface | `{Name}Interface` in `Api/Data/` | `Api/Data/OrderInterface` |
| Search results interface | `{Name}SearchResultsInterface` | `OrderSearchResultsInterface` |
| Service class | `{Name}Service` | `OrderExportService` |
| ViewModel class | `{Name}ViewModel` | `OrderListViewModel` |
| Observer class | `{DescriptiveName}Observer` | `OrderPlacedObserver` |
| Plugin class | `{TargetShortName}{Method}Plugin` | `OrderRepositorySavePlugin` |
| Cron job class | `{DescriptiveName}` (no suffix) | `ExportOrders` |
| Consumer class | `{Name}Consumer` | `OrderExportConsumer` |
| Admin controller | `Controller/Adminhtml/{Entity}/{Action}` | `Controller/Adminhtml/Order/Index` |
| Frontend controller | `Controller/{ControllerName}/{Action}` | `Controller/Order/View` |
| Data patch | `Setup/Patch/Data/{DescriptiveName}` | `Setup/Patch/Data/AddInitialStatuses` |
| Schema patch | `Setup/Patch/Schema/{DescriptiveName}` | `Setup/Patch/Schema/AddOrderColumn` |
| GraphQL resolver | `Model/Resolver/{QueryName}` | `Model/Resolver/Order` |
| GraphQL mutation resolver | `Model/Resolver/Mutation/{MutationName}` | `Model/Resolver/Mutation/SaveOrder` |
| GraphQL batch resolver | `Model/Resolver/Batch/{Name}BatchResolver` | `Model/Resolver/Batch/OrderReviewsBatchResolver` |
| Admin UI data provider | `Ui/DataProvider/{EntityName}DataProvider` | `Ui/DataProvider/OrderDataProvider` |
| Admin UI listing column | `Ui/Component/Listing/Column/{Name}` | `Ui/Component/Listing/Column/Actions` |
| Source model | `Model/Source/{AttributeName}` | `Model/Source/Status` |
| Backend model (EAV) | `Model/Attribute/Backend/{AttributeName}` | `Model/Attribute/Backend/Tags` |
| Frontend model (EAV) | `Model/Attribute/Frontend/{AttributeName}` | `Model/Attribute/Frontend/Color` |

**Forbidden:** class names containing `Helper` or `Manager`. Replace with `*Service`,
`*ViewModel`, or `*Processor`.

---

## 3. Database

| Identifier | Pattern | Example (`vendor_lower=acme, module_lower=order_export`) |
|---|---|---|
| Table name | `{vendor_lower}_{module_lower}_{entity}` | `acme_order_export_log` |
| Primary key column | `entity_id` (unsigned int, AI) | `entity_id` |
| Foreign key reference ID | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}_FK` | `ACME_ORDER_EXPORT_LOG_ORDER_ID_FK` |
| Index reference ID | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}` | `ACME_ORDER_EXPORT_LOG_STATUS` |
| Unique constraint ID | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}_UNIQUE` | `ACME_ORDER_EXPORT_LOG_HASH_UNIQUE` |

Reference IDs in `db_schema.xml` must be UPPER_SNAKE_CASE and globally unique within the
store. Always prefix with `{VENDOR_UPPER}_{MODULE_UPPER}_` to avoid collisions.

---

## 4. ACL Resources

Pattern: `{Vendor}_{ModuleName}::{resource}`

| Resource | ID | When |
|---|---|---|
| Root (required) | `{Vendor}_{ModuleName}::main` | Admin controller `ADMIN_RESOURCE`; top-level ACL entry |
| Config (required when admin_config) | `{Vendor}_{ModuleName}::config` | `system.xml` `<resource>` |
| Entity view | `{Vendor}_{ModuleName}::{entity}_view` | Optional fine-grained per-entity access |
| Entity edit | `{Vendor}_{ModuleName}::{entity}_edit` | Same |
| Entity delete | `{Vendor}_{ModuleName}::{entity}_delete` | Same |

`::main` is always the parent. `::config` is always a child of `::main`.

---

## 5. Config Paths

Pattern: `{vendor_lower}_{module_lower}/{group}/{field}`

| Component | Convention |
|---|---|
| Section ID | `{vendor_lower}_{module_lower}` |
| Group ID | Logical grouping: `general`, `api`, `notifications`, `advanced` |
| Field ID | snake_case |

Example: `acme_order_export/api/endpoint_url`

---

## 6. Routes

| Identifier | Pattern | Example |
|---|---|---|
| Admin route ID | `{vendor_lower}_{module_lower}` | `acme_order_export` |
| Frontend route ID | `{vendor_lower}_{module_lower}` | `acme_order_export` |
| Admin layout handle | `{vendor_lower}_{module_lower}_{entity}_{action}` | `acme_order_export_log_index` |
| Frontend layout handle | `{vendor_lower}_{module_lower}_{route}_{action}` | `acme_order_export_history_index` |

Layout handles are all lowercase with underscores only.

---

## 7. Events

Pattern: `{vendor_lower}_{module_lower}_{verb}_{entity}_{timing}`

| Timing | Suffix |
|---|---|
| Before | `_before` |
| After | `_after` |

Examples (`vendor_lower=acme, module_lower=order_export`):
- `acme_order_export_before_export`
- `acme_order_export_after_export_success`
- `acme_order_export_after_export_failure`

---

## 8. Cron

| Identifier | Pattern | Example |
|---|---|---|
| Job code | `{vendor_lower}_{module_lower}_{description}` | `acme_order_export_send_pending` |
| Schedule method | `execute(\Magento\Framework\DataObject $schedule)` | standard Magento pattern |
| Default group | `default` unless async required | `default` |

---

## 9. Queue

| Identifier | Pattern (dot-separated) | Example |
|---|---|---|
| Topic | `{vendor_lower}.{module_lower}.{description}` | `acme.order.export` |
| Queue | `{vendor_lower}.{module_lower}.{queue_name}` | `acme.order.export.pending` |
| Consumer | `{vendor_lower}.{module_lower}.{consumer_description}` | `acme.order.export.processor` |

---

## 10. REST API

| Identifier | Pattern |
|---|---|
| Route URL | `/V1/{vendor_lower}/{route}[/:param]` |
| Service ref | `{Vendor}\{ModuleName}\Api\{Name}Interface` |
| Resource ref | `{Vendor}_{ModuleName}::{operation}` (`::view`, `::manage`) |

---

## 11. GraphQL

| Identifier | Pattern |
|---|---|
| Query name | `{vendor_lower}{EntityName}` (camelCase, vendor prefix) |
| Mutation name | `save{Vendor}{EntityName}`, `delete{Vendor}{EntityName}`, etc. |
| Type name | `{EntityName}` (no vendor prefix; lives in Magento's global type namespace) |
| Input type | `{EntityName}Input` |

---

## 12. General Rules

1. Never abbreviate identifiers in ways that obscure intent.
2. When unsure between two valid names, prefer the more specific one.
3. Test class name mirrors the class under test: `OrderExportService` → `OrderExportServiceTest`.
4. Test file path mirrors source path: `Service/OrderExportService.php` →
   `Test/Unit/Service/OrderExportServiceTest.php`.
5. Names in user-facing strings (labels, descriptions) are translatable; identifiers are not.
