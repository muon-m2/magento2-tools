# Naming Conventions

Apply these rules to every identifier the skill generates. Violations cause review Category 3 failures.
All patterns use `{Vendor}` and `{vendor_lower}` — resolve these from project context before generating
(see SKILL.md Step 1).

---

## Module & Package

| Identifier            | Pattern                                     | Example (Vendor=Acme, Module=OrderExport) |
|-----------------------|---------------------------------------------|-------------------------------------------|
| Module directory      | PascalCase, letters only                    | `OrderExport`                             |
| PHP namespace root    | `{Vendor}\{ModuleName}`                     | `Acme\OrderExport`                        |
| Magento module name   | `{Vendor}_{ModuleName}`                     | `Acme_OrderExport`                        |
| Composer package name | `{vendor_lower}/module-{module-kebab-case}` | `acme/module-order-export`                |

**PascalCase → kebab-case conversion** (for Composer name and `{module-kebab-case}`):
Split on uppercase letters, lowercase all, join with `-`.
`OrderExport` → `order-export` | `MulesoftConnector` → `mulesoft-connector`

**PascalCase → snake_case conversion** (for `{module_lower}`, table prefixes, config paths):
Same split, join with `_`.
`OrderExport` → `order_export` | `MultiFactorLogin` → `multi_factor_login`

**`{vendor_lower}`** = `{Vendor}` lowercased.
`Acme` → `acme` | `MyCompany` → `mycompany`

---

## PHP Classes & Interfaces

| Type                     | Pattern                                  | Example                               |
|--------------------------|------------------------------------------|---------------------------------------|
| Interface (any)          | `{Name}Interface`                        | `OrderRepositoryInterface`            |
| Repository class         | `{Name}Repository`                       | `OrderRepository`                     |
| DTO interface            | `{Name}Interface` in `Api/Data/`         | `Api/Data/OrderInterface`             |
| Search results interface | `{Name}SearchResultsInterface`           | `OrderSearchResultsInterface`         |
| Service class            | `{Name}Service`                          | `OrderExportService`                  |
| ViewModel class          | `{Name}ViewModel`                        | `OrderListViewModel`                  |
| Observer class           | `{DescriptiveName}Observer`              | `OrderPlacedObserver`                 |
| Plugin class             | `{TargetShortName}{Method}Plugin`        | `OrderRepositorySavePlugin`           |
| Cron job class           | `{DescriptiveName}` (no suffix)          | `ExportOrders`                        |
| Consumer class           | `{Name}Consumer`                         | `OrderExportConsumer`                 |
| Admin controller         | `Controller/Adminhtml/{Entity}/{Action}` | `Controller/Adminhtml/Order/Index`    |
| Frontend controller      | `Controller/{ControllerName}/{Action}`   | `Controller/Order/View`               |
| Data patch               | `Setup/Patch/Data/{DescriptiveName}`     | `Setup/Patch/Data/AddInitialStatuses` |

**Forbidden patterns:** any class name containing `Helper` or `Manager`.
Replace with: `*Service` (business logic), `*ViewModel` (presentation), `*Processor` (transformation).

---

## Database

| Identifier               | Pattern                                                           | Example (vendor_lower=acme, module_lower=order_export) |
|--------------------------|-------------------------------------------------------------------|--------------------------------------------------------|
| Table name               | `{vendor_lower}_{module_lower}_{entity}`                          | `acme_order_export_log`                                |
| Primary key column       | `entity_id`                                                       | `entity_id` (unsigned int, auto-increment)             |
| Foreign key reference ID | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}_FK`     | `ACME_ORDER_EXPORT_LOG_ORDER_ID_FK`                    |
| Index reference ID       | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}`        | `ACME_ORDER_EXPORT_LOG_STATUS`                         |
| Unique constraint ID     | `{VENDOR_UPPER}_{MODULE_UPPER}_{ENTITY_UPPER}_{COL_UPPER}_UNIQUE` | `ACME_ORDER_EXPORT_LOG_HASH_UNIQUE`                    |

`{VENDOR_UPPER}` = `{Vendor}` uppercased. `{MODULE_UPPER}` = `{module_lower}` uppercased.

Reference IDs in `db_schema.xml` must be UPPER_SNAKE_CASE and globally unique within the store.
Always prefix all reference IDs with `{VENDOR_UPPER}_{MODULE_UPPER}_` to avoid collisions.

---

## ACL Resources

Pattern: `{Vendor}_{ModuleName}::{resource}`

| Resource                            | ID                                     | When                                                   |
|-------------------------------------|----------------------------------------|--------------------------------------------------------|
| Root (required)                     | `{Vendor}_{ModuleName}::main`          | Admin controller `ADMIN_RESOURCE`, top-level ACL entry |
| Config (required when admin_config) | `{Vendor}_{ModuleName}::config`        | `system.xml` `<resource>`, config ACL                  |
| Entity-level (optional)             | `{Vendor}_{ModuleName}::{entity}_view` | Fine-grained per-entity access                         |

The `::main` resource is always the parent in `acl.xml`. The `::config` resource is always a child of `::main`.

---

## Config Paths

Pattern: `{vendor_lower}_{module_lower}/{group}/{field}`

| Component  | Convention                                                           |
|------------|----------------------------------------------------------------------|
| Section ID | `{vendor_lower}_{module_lower}`                                      |
| Group ID   | Logical grouping name: `general`, `api`, `notifications`, `advanced` |
| Field ID   | snake_case field name: `enabled`, `endpoint_url`, `timeout_seconds`  |

Example: `acme_order_export/api/endpoint_url`

Always read via:

```php
$this->scopeConfig->getValue(
    '{vendor_lower}_{module_lower}/{group}/{field}',
    \Magento\Store\Model\ScopeInterface::SCOPE_STORE,
    $storeId
);
```

---

## Routes

| Identifier             | Pattern                                           | Example (vendor_lower=acme, module_lower=order_export) |
|------------------------|---------------------------------------------------|--------------------------------------------------------|
| Admin route ID         | `{vendor_lower}_{module_lower}`                   | `acme_order_export`                                    |
| Frontend route ID      | `{vendor_lower}_{module_lower}`                   | `acme_order_export`                                    |
| Admin layout handle    | `{vendor_lower}_{module_lower}_{entity}_{action}` | `acme_order_export_log_index`                          |
| Frontend layout handle | `{vendor_lower}_{module_lower}_{route}_{action}`  | `acme_order_export_history_index`                      |

Layout handles are all lowercase. Use underscores only.

---

## Events

Pattern: `{vendor_lower}_{module_lower}_{verb}_{entity}_{timing}`

| Timing               | Suffix    |
|----------------------|-----------|
| Before the operation | `_before` |
| After the operation  | `_after`  |

Examples (vendor_lower=acme, module_lower=order_export):

- `acme_order_export_before_export`
- `acme_order_export_after_export_success`
- `acme_order_export_after_export_failure`

---

## Cron

| Identifier      | Pattern                                            | Example (vendor_lower=acme, module_lower=order_export) |
|-----------------|----------------------------------------------------|--------------------------------------------------------|
| Job code        | `{vendor_lower}_{module_lower}_{description}`      | `acme_order_export_send_pending`                       |
| Schedule method | `execute(\Magento\Framework\DataObject $schedule)` | standard Magento pattern                               |

---

## Queue

| Identifier    | Pattern                                                       | Example (vendor_lower=acme, module_lower=order) |
|---------------|---------------------------------------------------------------|-------------------------------------------------|
| Topic name    | `{vendor_lower}.{module_lower}.{description}` (dot-separated) | `acme.order.export`                             |
| Queue name    | `{vendor_lower}.{module_lower}.{queue_name}`                  | `acme.order.export.pending`                     |
| Consumer name | `{vendor_lower}.{module_lower}.{consumer_description}`        | `acme.order.export.processor`                   |

---

## General Rules

1. Never abbreviate identifiers in ways that obscure intent.
2. When unsure between two valid names, prefer the more specific one.
3. Test class names mirror the class under test: `OrderExportService` → `OrderExportServiceTest`.
4. Test file paths mirror source paths: `Service/OrderExportService.php`
   → `Test/Unit/Service/OrderExportServiceTest.php`.
