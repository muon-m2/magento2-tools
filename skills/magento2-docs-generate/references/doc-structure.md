# Documentation Structure Reference

Canonical section order for the two primary output documents. Sections with no extracted
content are omitted entirely — never include empty tables or placeholder rows.

---

## README Structure

Rendered from `templates/readme.md`. Target file: `{module}/README.md`.

### Required sections (always present)

1. **Module name heading** — `# {Vendor}_{Module}`
2. **Description** — one paragraph from `{MODULE_DESCRIPTION}`.
3. **Requirements** — Magento version, PHP version (from composer.json `require`).
4. **Installation** — `bin/magento module:enable {Vendor}_{Module}` +
   `bin/magento setup:upgrade`.

### Documentation link (always present)

5. **Documentation** — a single "Full technical reference" link to
   `docs/technical-reference.md` covering all surfaces (API, events, plugins, REST,
   GraphQL, DB schema, extension attributes, config paths). The README stays concise;
   per-surface detail lives in the technical reference.

### Closing sections (always present)

6. **Dependencies** — `{DEPENDENCIES_LIST}` from `composer.json require`.

---

## Technical Reference Structure

Rendered from `templates/technical-reference.md`.
Target file: `{module}/docs/technical-reference.md`.

### Preamble (always present)

- Heading `# {Vendor}_{Module} — Technical Reference`
- One-line purpose statement.
- Link back to `../README.md`.

### Surface sections (each omitted when the surface has zero entries)

Each section heading is an anchor used by the README's conditional sections above.

| Section | Heading | Anchor | Token |
|---------|---------|--------|-------|
| Public API | `## Public API Surface` | `#api-surface` | `{API_SURFACE_TABLE}` |
| Events fired | `## Events Fired` | `#events-fired` | `{EVENTS_TABLE}` |
| Events observed | `## Events Observed` | `#events-observed` | included in `{EVENTS_TABLE}` |
| Plugins | `## Plugins` | `#plugins` | `{PLUGINS_TABLE}` |
| Preferences | `## Preferences` | `#preferences` | included in `{PLUGINS_TABLE}` |
| Config paths | `## Admin Config Paths` | `#config-paths` | `{CONFIG_PATHS_TABLE}` |
| CLI commands | `## CLI Commands` | `#cli-commands` | `{CLI_COMMANDS_TABLE}` |
| Cron jobs | `## Cron Jobs` | `#cron-jobs` | `{CRON_TABLE}` |
| REST routes | `## REST Routes` | `#rest-routes` | `{REST_ROUTES_TABLE}` |
| GraphQL | `## GraphQL` | `#graphql` | `{GRAPHQL_TABLE}` |
| DB schema | `## Database Schema` | `#database-schema` | `{DB_SCHEMA_TABLE}` |
| Extension attributes | `## Extension Attributes` | `#extension-attributes` | `{EXTENSION_ATTRIBUTES_TABLE}` |

### Closing sections (always present)

- `## Module Dependencies` — requires/suggests from `composer.json`.
- `## Source File` — note that this document is auto-generated; cite the skill version.

---

## Table Column Conventions

### API Surface table columns

| Column | Content |
|--------|---------|
| Type | `interface` or `class` |
| Name | Short class name (linked to source file if hosted on a known platform) |
| Source | Relative path from module root with line number |

### Events table columns (fired and observed combined)

| Column | Content |
|--------|---------|
| Direction | `fired` or `observed` |
| Event Name | snake_case event identifier |
| Class / Observer | PHP class responsible |
| Source | Relative file path + line |

### Plugins table columns (plugins and preferences combined)

| Column | Content |
|--------|---------|
| Kind | `plugin` or `preference` |
| Name | Plugin name or preference `for` interface |
| Class | Implementation class |
| Target | Intercepted class (plugins) or replaced interface (preferences) |
| Source | Relative di.xml path |

### Config paths table columns

| Column | Content |
|--------|---------|
| Config Path | `section/group/field` |
| Label | Human-readable label |
| Type | Field type |
| Source | `etc/adminhtml/system.xml` |

### CLI commands table columns

| Column | Content |
|--------|---------|
| Command | `bin/magento <command_name>` |
| Class | PHP class |
| Description | From `setDescription()` if found |
| Source | Relative PHP file path |

### Cron jobs table columns

| Column | Content |
|--------|---------|
| Job Name | Cron job identifier |
| Class::Method | `ClassName::execute` |
| Schedule | Cron expression or config path |
| Group | Cron group |
| Source | `etc/crontab.xml` |

### REST routes table columns

| Column | Content |
|--------|---------|
| Method | HTTP verb |
| URL | Route URL template |
| Service | `ClassName::method` |
| Auth | Auth scope(s) |
| Source | `etc/webapi.xml` |

### GraphQL table columns

| Column | Content |
|--------|---------|
| Kind | `type`, `input`, `interface`, `extend type` |
| Name | GraphQL type name |
| Fields | Comma-separated field names |
| Source | `etc/schema.graphqls` |

### DB schema table columns

| Column | Content |
|--------|---------|
| Table | Table name |
| Columns | Comma-separated key column names + types |
| Indexes | Index names |
| Constraints | Primary/foreign/unique |
| Source | `etc/db_schema.xml` |

---

## CHANGELOG Scaffold Structure

Rendered from `templates/changelog-scaffold.md`.
Target file: `{module}/CHANGELOG.md`.

```
# Changelog — {Vendor}_{Module}

All notable changes to this module will be documented in this file.
Format: Keep a Changelog (https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- (list additions here)

### Changed
- (list changes here)

### Fixed
- (list fixes here)

## [x.y.z] — {date}

_Initial documented release._
```

The `{date}` placeholder is substituted with the actual date at generation time. No
history is invented — the scaffold provides structure only.
