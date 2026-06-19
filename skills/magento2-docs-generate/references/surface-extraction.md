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

## Output Format

The script emits one JSON object:

```
{
  "module_path": "<absolute path>",
  "surfaces": {
    "api": [ { "class": "...", "kind": "...", "file": "...", "line": N } ],
    "events_observed": [ ... ],
    "events_fired": [ ... ],
    "plugins": [ ... ],
    "preferences": [ ... ],
    "cli_commands": [ ... ],
    "config_paths": [ ... ],
    "cron_jobs": [ ... ],
    "rest_routes": [ ... ],
    "graphql": [ ... ],
    "db_schema": [ ... ],
    "extension_attributes": [ ... ]
  }
}
```

Empty arrays are included in the JSON for completeness but surfaces with zero entries
must be **omitted** from the generated Markdown documentation.
