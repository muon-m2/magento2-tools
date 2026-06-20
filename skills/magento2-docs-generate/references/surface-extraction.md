# Surface Extraction Reference

Read-only grep/parse recipes for `scripts/extract-surface.sh`. Each surface lists the
source file(s) to check, the extraction command, and the required output fields. Every
entry must record its **source file path** so the generated documentation can cite it.

If a source file does not exist for a given surface, that surface is silently skipped
and must be omitted from the documentation (no empty tables, no placeholder rows).

---

## 1. Public API Surface (`@api`)

**Source files:** All `*.php` under the module directory.

**Recipe:**

```
grep -rn '@api' <module_path> --include='*.php'
```

**Output fields per entry:**
- `class` — short class or interface name (unqualified name from the declaration line)
- `kind` — `interface` or `class`
- `file` — relative path from module root
- `line` — line number of the `@api` annotation

Only classes and interfaces with `@api` in their docblock are public contract. Exclude
`@api` occurrences in inline comments that are not part of a class/interface declaration.

---

## 2. Events Observed (`etc/events.xml`)

**Source files:** `etc/events.xml`, `etc/frontend/events.xml`, `etc/adminhtml/events.xml`,
`etc/webapi_rest/events.xml`, `etc/crontab/events.xml`.

**Recipe:** Parse XML, extract `<observer>` elements:

```
grep -n 'name=\|instance=' etc/events.xml
```

Or via xmllint/xmlstarlet if available:

```
xmllint --xpath '//observer/@name | //observer/@instance | //event/@name' etc/events.xml
```

**Output fields per entry:**
- `event_name` — value of `<event name="...">` attribute
- `observer_name` — value of `<observer name="...">` attribute
- `observer_class` — value of `<observer instance="...">` attribute
- `area` — area derived from the file path (global/frontend/adminhtml/etc.)
- `file` — path to events.xml relative to module root

---

## 3. Events Fired (`dispatch(` calls)

**Source files:** All `*.php` under the module directory.

**Recipe:**

```
grep -rn 'dispatch(' <module_path> --include='*.php'
```

Look for `$this->eventManager->dispatch(`, `$eventManager->dispatch(`, or
`$this->_eventManager->dispatch(`. Extract the first string argument (event name).

**Output fields per entry:**
- `event_name` — first string literal argument to `dispatch()`
- `file` — path to the PHP file, relative to module root
- `line` — line number

Note: Dynamic event names (computed strings, variables) cannot be extracted statically;
skip them and note the count of dynamic dispatches separately.

---

## 4. Plugins (`etc/di.xml`)

**Source files:** `etc/di.xml`, `etc/frontend/di.xml`, `etc/adminhtml/di.xml`,
`etc/webapi_rest/di.xml`, `etc/graphql/di.xml`.

**Recipe:** Extract `<plugin>` elements:

```
grep -n '<plugin ' etc/di.xml
```

**Output fields per entry:**
- `plugin_name` — value of `name` attribute on `<plugin>`
- `plugin_class` — value of `type` attribute on `<plugin>`
- `target_type` — value of `name` attribute on the parent `<type>` element
- `sort_order` — value of `sortOrder` attribute (if present)
- `disabled` — true if `disabled="true"` is set
- `area` — area derived from the file path
- `file` — path to di.xml relative to module root

---

## 5. Preferences (`etc/di.xml`)

**Source files:** `etc/di.xml`, `etc/frontend/di.xml`, `etc/adminhtml/di.xml`,
`etc/webapi_rest/di.xml`.

**Recipe:** Extract `<preference>` elements:

```
grep -n '<preference ' etc/di.xml
```

**Output fields per entry:**
- `for` — value of `for` attribute (interface/class being replaced)
- `type` — value of `type` attribute (concrete class)
- `area` — area derived from the file path
- `file` — path to di.xml relative to module root

---

## 6. CLI Commands (`etc/di.xml` + `Console/`)

**Source files:** `etc/di.xml`, all `*.php` under `Console/Command/`.

**Recipe (DI registration):** Look for `CommandList` or `Magento\Framework\Console\CommandListInterface` entries:

```
grep -n 'CommandList\|CommandListInterface' etc/di.xml
```

**Recipe (command class):** In each `Console/Command/*.php`, extract the `setName()` call
value:

```
grep -rn 'setName(' Console/Command/ --include='*.php'
```

**Output fields per entry:**
- `command_name` — CLI name from `setName()` (e.g. `acme:orders:sync`)
- `class` — PHP class name
- `file` — path to the Command PHP file, relative to module root
- `description` — value from `setDescription()` call, if found

---

## 7. Admin Config Paths (`etc/adminhtml/system.xml`)

**Source files:** `etc/adminhtml/system.xml`.

**Recipe:**

```
grep -n '<section\|<group\|<field' etc/adminhtml/system.xml
```

Or parse via xmllint to extract the full config path hierarchy.

**Output fields per entry:**
- `config_path` — full path: `{section_id}/{group_id}/{field_id}`
- `label` — human-readable label from `<label>` child element
- `type` — field type (text, select, multiselect, obscure, etc.)
- `file` — `etc/adminhtml/system.xml` relative to module root

---

## 8. Cron Jobs (`etc/crontab.xml`)

**Source files:** `etc/crontab.xml`.

**Recipe:**

```
grep -n '<job\|<schedule\|<config_path' etc/crontab.xml
```

**Output fields per entry:**
- `job_name` — value of `name` attribute on `<job>`
- `instance` — value of `instance` attribute on `<job>`
- `method` — value of `method` attribute on `<job>`
- `schedule` — cron expression from `<schedule>`, or config path from `<config_path>`
- `group` — cron group id from the parent `<group>` element
- `file` — `etc/crontab.xml` relative to module root

---

## 9. REST Routes (`etc/webapi.xml`)

**Source files:** `etc/webapi.xml`.

**Recipe:**

```
grep -n '<route ' etc/webapi.xml
```

**Output fields per entry:**
- `method` — HTTP verb: GET, POST, PUT, DELETE
- `url` — URL template (e.g. `/V1/acme/orders/:id`)
- `service_class` — value of `class` attribute under `<service>`
- `service_method` — value of `method` attribute under `<service>`
- `auth` — auth scopes from `<resources>` (anonymous/self/ACL resource)
- `file` — `etc/webapi.xml` relative to module root

---

## 10. GraphQL (`etc/schema.graphqls`)

**Source files:** `etc/schema.graphqls`.

**Recipe:**

```
grep -n 'type\|input\|interface\|extend type\|extend input' etc/schema.graphqls
```

**Output fields per entry:**
- `kind` — `type`, `input`, `interface`, `extend type`, `extend input`
- `name` — GraphQL type name
- `fields` — list of field names with their types (one line each)
- `file` — `etc/schema.graphqls` relative to module root

---

## 11. DB Schema (`etc/db_schema.xml`)

**Source files:** `etc/db_schema.xml`.

**Recipe:**

```
grep -n '<table\|<column\|<index\|<constraint' etc/db_schema.xml
```

**Output fields per entry:**
- `table_name` — value of `name` attribute on `<table>`
- `engine` — value of `engine` attribute (default: innodb)
- `columns` — list of column names + types from `<column>` elements
- `indexes` — list of index names + types
- `constraints` — primary/foreign/unique constraints
- `file` — `etc/db_schema.xml` relative to module root

---

## 12. Extension Attributes (`etc/extension_attributes.xml`)

**Source files:** `etc/extension_attributes.xml`.

**Recipe:**

```
grep -n '<extension_attributes\|<attribute' etc/extension_attributes.xml
```

**Output fields per entry:**
- `for` — value of `for` attribute on `<extension_attributes>`
- `attribute_code` — value of `code` attribute on `<attribute>`
- `type` — value of `type` attribute
- `file` — `etc/extension_attributes.xml` relative to module root

---

---

## 13. `@api` Method Signatures

**Source files:** All `*.php` under the module directory that bear an `@api` annotation on
the class or interface docblock (i.e. already captured in surface `api`).

**Recipe:** For each class/interface collected in surface 1, parse its public method
declarations:

```
grep -n 'public function' <api_file>
```

For each public method, extract:
- The method name.
- Its parameter list (name + type hint).
- Its return type hint (PHP 7+ `function foo(): ReturnType` or docblock `@return`).

Only methods declared directly on the `@api` class or interface are collected; inherited
methods are skipped unless re-declared.

**Output fields per entry:**
- `class` — fully-qualified class name (FQCN) of the `@api` class or interface
- `method` — method name
- `params` — ordered list of `{ "name": "$foo", "type": "string" }` objects
- `return_type` — return type as a string (`"void"`, `"int"`, FQCN, etc.)
- `file` — relative path from module root
- `line` — line number of the `public function` declaration

---

## 14. REST Example Shapes (Service-method + DTO Walk)

**Source files:** `etc/webapi.xml`, PHP source of the service class named by each route.

**Recipe:** For each REST route captured in surface 9, resolve the service method and
build illustrative request/response shapes:

1. **Locate the service class** — use the `service_class` FQCN from surface 9.
   Find its PHP source file under the module tree.

2. **Build a use-map** — parse the file's `use` statements and `namespace` declaration
   to map short type names to FQCNs. Resolution is **module-local**: if a type's resolved
   FQCN does not fall under this module's `Vendor/Module` namespace prefix, it cannot be
   walked and degrades to `"string"`.

3. **Resolve method parameters and return type** — find the `public function <method>()`
   declaration in the service class. For each parameter, use the use-map to resolve the
   type hint. For the return type, resolve similarly.

4. **Walk DTO types** — a type is a DTO if its FQCN matches `*\Api\Data\*Interface`.
   Parse the DTO interface file and collect its public getter methods
   (`get*()`, `is*()`). Map each getter to a snake_case field name and derive a
   placeholder value from the return type (see the Example-derivation table in
   `doc-structure.md`). Walking is bounded by a **depth cap of ≈4 levels** and a
   **visited-set** to break cycles; a type seen at a prior level is replaced by `{}`.

5. **Build `request_shape`** — a JSON-serializable object keyed by parameter name, with
   each value set to the derived placeholder for that parameter's type. If the method has
   no input parameters, `request_shape` is `null`.

6. **Build `response_shape`** — derived from the return type placeholder. `void` →
   `null`.

7. **Extract `throws`** — scan the `@throws` tags in the docblock that immediately
   precedes the service method declaration (method-scoped, not file-wide). Resolve short
   exception class names via the use-map to FQCNs.

**Output fields per entry** (extend each REST route entry with):
- `request_shape` — JSON-serializable object or `null`
- `response_shape` — JSON-serializable value or `null`
- `throws` — list of exception FQCNs extracted from the method's own `@throws` tags

Shapes that cannot be resolved (unresolvable type, missing source file) degrade to
`"string"` at the field level. The shape is still emitted; the caption **"Example —
illustrative, generated from the schema."** must appear above every rendered example block.

---

## 15. GraphQL Operations + Field Types

**Source files:** `etc/schema.graphqls`.

**Recipe (operations):** Scan for `Query`, `Mutation`, and `extend type Query` /
`extend type Mutation` blocks. For each field declared inside those blocks, emit one
operation entry:

```
grep -n 'type Query\|type Mutation\|extend type Query\|extend type Mutation' etc/schema.graphqls
```

Then parse each field inside the block:
- Field name.
- Argument list: each `name: Type` pair.
- Return type (strip GraphQL `!` non-null markers and `[]` list markers from the type
  string for the `output_type` field).
- Resolver class from the `@resolver(class="...")` directive.

**Recipe (field types on non-operation types):** For every type/input/interface collected
in surface 10, update its `fields` list from a flat list of field-name strings to a list
of `{ "name": "...", "type": "..." }` objects. Strip `!` and `[]` markers from `type`.

**Output fields per operation entry:**
- `operation_kind` — `"query"` or `"mutation"`
- `name` — operation field name (e.g. `acmeOrders`)
- `args` — list of `{ "name": "...", "type": "..." }` argument descriptors
- `output_type` — return type string (list/non-null markers stripped)
- `resolver` — FQCN of the resolver class from `@resolver(class="...")`
- `file` — `etc/schema.graphqls` relative to module root

**Updated fields on existing graphql entries:**
- `fields` — changed from a list of name strings to a list of `{ "name": "...", "type": "..." }` objects

---

## 16. User-Facing Surface

**Source files:** `etc/adminhtml/system.xml`, `etc/adminhtml/routes.xml`, `view/adminhtml/`,
`view/frontend/`, `etc/frontend/routes.xml`, `view/adminhtml/ui_component/`,
`etc/adminhtml/menu.xml`, `etc/acl.xml`, `etc/email_templates.xml`.

**Recipe:** This surface aggregates multiple sub-extractors. It is emitted only when at
least one sub-key is non-empty. A module **presents a user surface** iff `user_surface`
is non-empty.

### 16a. Admin Config (`admin_config`)

Parse `etc/adminhtml/system.xml` for section/group/field hierarchy. For each field,
record:
- `config_path` — `{section_id}/{group_id}/{field_id}`
- `tab` — `<tab>` id referenced by the section (nav label context)
- `section` — section id + label
- `group` — group id + label
- `field_label` — `<label>` text of the field
- `comment` — `<comment>` text if present

### 16b. Admin UI (`admin_ui`)

- `components` — list of `*.xml` filenames under `view/adminhtml/ui_component/`
- `menu` — list of menu entries from `etc/adminhtml/menu.xml`: `{ id, title, parent, resource, action }`
- `acl` — list of ACL resource ids from `etc/acl.xml`: `{ id, title }`
- `admin_routes` — list of `{ frontName }` from `etc/adminhtml/routes.xml`

Note: Adminhtml controllers (`Controller/Adminhtml/`) are **excluded** from the
`storefront` sub-key; they belong to `admin_ui` only.

### 16c. Storefront (`storefront`)

- `routes` — list of `{ frontName, area }` from `etc/frontend/routes.xml`
- `controllers` — list of controller PHP files under `Controller/` (excluding `Controller/Adminhtml/`)
- `layouts` — list of layout XML filenames under `view/frontend/layout/`
- `templates` — list of `.phtml` filenames under `view/frontend/templates/`

### 16d. Emails (`emails`)

Parse `etc/email_templates.xml`:
- `id` — template id
- `label` — human-readable label
- `file` — template file path

---

## Extraction Order

The script processes surfaces in this order and skips any file that does not exist:

1. `@api` annotations (PHP scan)
2. Events observed (`etc/events.xml` + area variants)
3. Events fired (`dispatch(` PHP scan)
4. Plugins (`etc/di.xml` + area variants)
5. Preferences (`etc/di.xml` + area variants)
6. CLI commands (`etc/di.xml` + `Console/Command/*.php`)
7. Admin config paths (`etc/adminhtml/system.xml`)
8. Cron jobs (`etc/crontab.xml`)
9. REST routes (`etc/webapi.xml`)
10. GraphQL types (`etc/schema.graphqls`)
11. DB schema (`etc/db_schema.xml`)
12. Extension attributes (`etc/extension_attributes.xml`)
13. `@api` method signatures (PHP scan of `@api` classes/interfaces)
14. REST example shapes (service-method resolution + DTO walk)
15. GraphQL operations + field types (`etc/schema.graphqls`)
16. User-facing surface (admin config / admin UI / storefront / emails)

## Output Format

The script emits one JSON object:

```json
{
  "module_path": "<absolute path>",
  "surfaces": {
    "api": [ { "class": "...", "kind": "...", "file": "...", "line": 0 } ],
    "api_methods": [
      {
        "class": "Vendor\\Module\\Api\\FooInterface",
        "method": "getById",
        "params": [ { "name": "$id", "type": "int" } ],
        "return_type": "Vendor\\Module\\Api\\Data\\FooInterface",
        "file": "Api/FooInterface.php",
        "line": 42
      }
    ],
    "events_observed": [ ... ],
    "events_fired": [ ... ],
    "plugins": [ ... ],
    "preferences": [ ... ],
    "cli_commands": [ ... ],
    "config_paths": [ ... ],
    "cron_jobs": [ ... ],
    "rest_routes": [
      {
        "method": "GET",
        "url": "/V1/acme/orders/:id",
        "service_class": "Vendor\\Module\\Api\\OrderRepositoryInterface",
        "service_method": "getById",
        "auth": "Magento_Sales::sales",
        "file": "etc/webapi.xml",
        "request_shape": null,
        "response_shape": {
          "id": 0,
          "status": "string",
          "items": []
        },
        "throws": [
          "Magento\\Framework\\Exception\\NoSuchEntityException",
          "Magento\\Framework\\Exception\\LocalizedException"
        ]
      }
    ],
    "graphql": [
      {
        "kind": "type",
        "name": "AcmeOrder",
        "fields": [
          { "name": "id", "type": "Int" },
          { "name": "status", "type": "String" }
        ],
        "file": "etc/schema.graphqls"
      }
    ],
    "graphql_operations": [
      {
        "operation_kind": "query",
        "name": "acmeOrder",
        "args": [ { "name": "id", "type": "Int" } ],
        "output_type": "AcmeOrder",
        "resolver": "Vendor\\Module\\Model\\Resolver\\Order",
        "file": "etc/schema.graphqls"
      }
    ],
    "db_schema": [ ... ],
    "extension_attributes": [ ... ],
    "user_surface": {
      "admin_config": [
        {
          "config_path": "acme/general/enable",
          "tab": "general",
          "section": "acme",
          "group": "general",
          "field_label": "Enable Module",
          "comment": "Set to Yes to activate the Acme integration."
        }
      ],
      "admin_ui": {
        "components": [ "acme_order_listing.xml" ],
        "menu": [ { "id": "Acme_Module::menu", "title": "Acme", "parent": "Magento_Backend::stores", "resource": "Acme_Module::config", "action": "acme/index/index" } ],
        "acl": [ { "id": "Acme_Module::config", "title": "Configuration" } ],
        "admin_routes": [ { "frontName": "acme" } ]
      },
      "storefront": {
        "routes": [ { "frontName": "acme", "area": "frontend" } ],
        "controllers": [ "Controller/Index/Index.php" ],
        "layouts": [ "acme_index_index.xml" ],
        "templates": [ "order/list.phtml" ]
      },
      "emails": [
        { "id": "acme_order_confirm", "label": "Acme Order Confirmation", "file": "acme_order_confirm.html" }
      ]
    }
  }
}
```

Empty arrays are included in the JSON for completeness but surfaces with zero entries
must be **omitted** from the generated Markdown documentation. The `user_surface` key
is omitted entirely when all sub-keys are empty.
