# Canonical Placeholder Schema for Templates

Every `{token}` that appears in any `skills/*/templates/` file MUST be listed in the
**Registry** at the bottom of this document. `tests/test-placeholder-tokens.sh` extracts the
tokens from all templates and fails on any token that is not registered here — that is the
"unknown-token lint". Substitution code should replace exactly these tokens.

This file is the de-facto registry: it was regenerated from the tokens actually used in the
templates, not an idealised list. Where two spellings exist for the same concept (two
historical conventions), both are registered and the **preferred** one is noted.

## Core identity tokens

Two naming conventions coexist. Both are accepted; new templates should prefer the
module-create convention for consistency with the bulk of the suite.

| Concept | Preferred (module-create) | Accepted alias (graphql-create) | lowercase | UPPER (constants) | Example |
|---------|---------------------------|---------------------------------|-----------|-------------------|---------|
| Vendor  | `{Vendor}`                | —                               | `{vendor_lower}` (also `{vendor}`) | `{VENDOR_UPPER}` | `Acme` / `acme` / `ACME` |
| Module  | `{ModuleName}`            | `{Module}`                      | `{module_lower}` (also `{module}`, `{moduleName}`) | `{MODULE_UPPER}`, `{MODULE_NAME}` | `OrderExport` / `orderexport` |
| Entity  | `{EntityName}`            | `{Entity}`                      | `{entity}` (also `{entity_lower}`) | `{ENTITY_UPPER}` | `Order` / `order` |
| Module id | `{Vendor}_{ModuleName}` | `{Vendor}_{Module}`             | — | — | `Acme_OrderExport` |

`{vendor}` / `{module}` are lowercase forms used in composer names and config-path keys.
`{moduleName}` (camelCase) appears in JS/RequireJS contexts.

## Attribute / code tokens

| Token | Meaning | Example |
|-------|---------|---------|
| `{AttributeCode}` | PascalCase attribute identifier | `LoyaltyTier` |
| `{attribute_code}` | snake_case attribute identifier | `loyalty_tier` |
| `{Code}` / `{code}` | short code (Pascal / snake) | `LoyaltyTier` / `loyalty_tier` |

## Structural / code tokens

Names used inside generated PHP/XML. Examples: `{ClassUnderTest}`, `{ServiceName}`,
`{ControllerName}`, `{ActionName}`, `{ObserverName}`, `{ConsumerName}`, `{MessageName}`,
`{JobName}`, `{PatchName}`, `{Interface}`, `{Method}` / `{method}` / `{METHOD}`,
`{TargetNamespace}`, `{TargetShortName}`, `{SubNamespace}`, `{Dep1FQCN}`, `{ParentIdAccessor}`,
`{parent_id_key}`, `{ParentTheme}`, `{ParentVendor}`, `{Theme}`, `{theme_lower}`.

## System-config tokens (magento2-system-config)

Store-configuration generator tokens:
`{SectionId}` (snake_case section id in system.xml, e.g. `acme_checkout`),
`{GroupId}` (snake_case group id, e.g. `general`),
`{FieldId}` (snake_case field id, e.g. `enable_feature`),
`{FieldTitle}` (human-readable field label shown in admin, e.g. `Enable Feature`),
`{BackendModelName}` (PascalCase backend model class name, e.g. `SomeBackend`),
`{DefaultValue}` (default field value written to config.xml, e.g. `1`).

## Extension-point tokens (magento2-extension-point)

Plugin, observer, and preference tokens:
`{PluginName}` (PascalCase plugin class name),
`{plugin_name}` (snake_case DI identifier),
`{TargetFqcn}` (fully-qualified class name being intercepted),
`{SortOrder}` (integer plugin sort order),
`{EventName}` (snake_case dispatched event name),
`{observer_name}` (snake_case observer identifier in events.xml),
`{PreferenceFor}` (FQCN of the interface/class being replaced; used in `use` statement and XML attribute),
`{PreferenceForShort}` (unqualified short class/interface name derived from `{PreferenceFor}`; used in `implements`/`extends` after the `use` import),
`{area}` (area folder name: global/frontend/adminhtml/webapi_rest/graphql/crontab).

## CLI-command tokens (magento2-cli-command)

Console command and cron job generator tokens:
`{CommandClass}` (PascalCase command class name, e.g. `SyncOrdersCommand`; placed in `Console/Command/`),
`{CommandName}` (namespaced CLI name, e.g. `acme:orders:sync`; passed to `setName()`),
`{command_name}` (snake_case DI array key for `CommandList` registration, e.g. `acme_orders_sync_command`),
`{CronJobName}` (PascalCase cron job class name, e.g. `SyncOrders`; placed in `Cron/`),
`{cron_job_name}` (snake_case cron job identifier in `crontab.xml`, e.g. `acme_orders_sync`),
`{CronGroup}` (cron group id in `crontab.xml`, e.g. `default`),
`{Schedule}` (cron expression string, e.g. `*/15 * * * *`; or replaced by `<config_path>` when schedule comes from admin config).

Note: `{ServiceName}` is already registered under Structural / code tokens above.

## Indexer tokens (magento2-indexer)

Indexer and mview generator tokens:
`{IndexerName}` (PascalCase indexer class name placed in `Model/Indexer/`, e.g.
`ProductStock`; the action class is `{IndexerName}Action`),
`{indexer_id}` (snake_case unique indexer identifier shared by `indexer.xml` `id`,
`mview.xml` `view id`, and the `indexer:reindex` CLI command, e.g.
`acme_catalog_productstock`),
`{id_column}` (column name in the source table that holds the entity primary key,
e.g. `product_id`; used as `entity_column` in `mview.xml` subscriptions).

Note: `{source_table}` (source DB table subscribed to in mview), `{target_table}`
(destination index table), `{Title}` (human-readable indexer title shown in admin), and
`{Description}` (one-sentence description shown in admin) are already registered under
Value / content tokens above and are reused here — not duplicated.

## Message-queue tokens (magento2-message-queue)

Async message-queue generator tokens:
`{TopicName}` (dot-separated topic name shared across communication.xml, queue_topology.xml,
queue_publisher.xml, and the publisher's `TOPIC` const, e.g. `acme.orders.order.export`),
`{QueueName}` (dot-separated physical queue name shared by queue_topology.xml's binding
destination and queue_consumer.xml's `queue`, e.g. `acme.orders.export`),
`{ExchangeName}` (exchange name shared by queue_topology.xml and queue_publisher.xml; `magento`
by convention for the `db` connection),
`{ConnectionName}` (message-queue connection: `db` by default, or `amqp` when a broker is
confirmed; shared across topology/publisher/consumer XML),
`{PublisherName}` (PascalCase publisher class name placed in `Model/`, e.g. `OrderExportPublisher`).

Note: `{ConsumerName}` (consumer class + queue_consumer.xml `name`) and `{EntityName}` (the
typed message DTO) are already registered above and are reused here. The DTO factory
referenced in the publisher is the framework-generated `{EntityName}InterfaceFactory`
(derived from `{EntityName}`, not a separate token).

## Theme / frontend tokens

`{component}`, `{component-name-kebab}`, `{module-kebab-case}`, `{module-name-kebab}`,
`{template_name}`, `{parent_theme_package}`, `{parent_theme_constraint}`, `{php_constraint}`,
`{framework_constraint}`.

## Context tokens (resolved by magento2-context)

`{ctx.runner}`, `{ctx.magento_cli}`, `{ctx.magento_root}`, `{runner}`, `{magento}`,
`{magento_cli}`. These are substituted from the context JSON, not from user input.

## Value / content tokens (docs, reports, examples)

Free-form values that authors fill in: `{N}`, `{sum}` (estimated-effort total), `{slug}`,
`{route}`, `{url}`, `{description}`,
`{Description}`, `{ShortDescription}`, `{purpose}`, `{reason}`, `{notes}`, `{Title}`,
`{Name}` / `{name}`, `{version}` / `{ver}`, `{Severity}`, `{date}`, `{DATE}`, `{YYYY-MM-DD}`,
`{timestamp}`, `{uuid}`, `{author}` (composer `authors[].name`; derive from `git config user.name`,
fallback `gh api user`), `{author_email}` (composer `authors[].email`; derive from
`git config user.email`), `{commit}`, `{env}`, `{path}` / `{Path}`, `{file}` /
`{file_name}` / `{file1}` / `{file2}`, `{line}`, `{col}`, `{bytes}`, `{expected}` /
`{actual}`, `{from}` / `{to}` / `{From}` / `{To}`, `{from_magento}` / `{to_magento}` /
`{from_php}` / `{to_php}`, `{minimum}`, `{event_name}` / `{event_short_name}` /
`{magento_event}`, `{queue_name}`, `{topic}`, `{consumer_description}`, `{ModuleA}` /
`{ModuleB}` / `{ModuleC}` (multi-module examples), `{ExistingModule}` / `{Existing}`,
`{existing_table}` / `{source_table}` / `{target_table}`, `{ids}`, `{Item}`, `{Group}`,
`{Section}`, `{Area}` / `{ControllerArea}`, `{permission}`, `{surface}`, `{package}`,
`{user}`, `{field}`, `{fixture}`, `{Behaviour}`, `{Class}`, `{Service}`, `{SourceName}`,
`{BackendName}`, `{depMethod}` / `{depReturn}` / `{paramName}` / `{paramValue}` /
`{invalidArgs}` / `{reproducedArgs}` / `{reproducedReturn}` / `{methodUnderTest}` /
`{target_short_lower}` / `{method_lower}` / `{Dep1Type}` / `{Dep2FQCN}` / `{Dep2Type}`,
`{args}`, `{action}`, `{default}`, `{new}` / `{previous}` / `{planned}`, `{SHA1}` / `{SHA2}`,
`{OtherPatch}` / `{Patch}`, `{modules}`, `{MODULE_PATH}`, `{ID}` (task ID),
`{NNN}` (zero-padded execution-order index), `{kebab-title}` (kebab-cased task title; used in
`tasks/` file names), `{PLACEHOLDER}`.

## Report-template section markers (UPPER_CASE)

These are substituted by the review/report emitters, not by code scaffolding:
`{CHECKLIST_TABLE}`, `{CRITICAL_COUNT}`, `{HIGH_COUNT}`, `{MEDIUM_COUNT}`, `{LOW_COUNT}`,
`{EXECUTIVE_SUMMARY}`, `{FINDINGS_HTML}`, `{ENVIRONMENT_LIMITATIONS}`, `{NEXT_STEPS}`,
`{POSITIVE_OBSERVATIONS}`, `{PARALLEL_REVIEW_SECTION}`, `{TOOL_RESULTS_TABLE}`.

`magento2-docs-generate` surface-section markers (substituted when generating module
technical documentation from extracted code surfaces):
`{MODULE_DESCRIPTION}`, `{DEPENDENCIES_LIST}`, `{API_SURFACE_TABLE}`, `{EVENTS_TABLE}`,
`{PLUGINS_TABLE}`, `{CONFIG_PATHS_TABLE}`, `{CLI_COMMANDS_TABLE}`, `{CRON_TABLE}`,
`{REST_ROUTES_TABLE}`, `{GRAPHQL_TABLE}`, `{DB_SCHEMA_TABLE}`, `{EXTENSION_ATTRIBUTES_TABLE}`.

## Substitution rules

- Substitution is whole-token: replace the literal text `{ModuleName}` with the resolved
  value. No regex on naked identifiers.
- After substitution, the resulting file must pass `php -l` / `xmllint` / `node --check` as
  applicable. The template-lint fixtures verify this.
- An unsubstituted placeholder left in a generated file is a hard error.
- Adding a NEW token to a template requires adding it to the Registry below, or
  `test-placeholder-tokens.sh` fails.

## Registry

The machine-readable allow-list. `test-placeholder-tokens.sh` parses the fenced block below
(one token per line, without braces) and rejects any template token not present.

```registry
ActionName
API_SURFACE_TABLE
Area
AttributeCode
BackendModelName
BackendName
Behaviour
CHECKLIST_TABLE
CLI_COMMANDS_TABLE
CONFIG_PATHS_TABLE
CRITICAL_COUNT
CRON_TABLE
DB_SCHEMA_TABLE
DEPENDENCIES_LIST
EVENTS_TABLE
EXTENSION_ATTRIBUTES_TABLE
EventName
Class
ClassUnderTest
Code
CommandClass
CommandName
ConnectionName
ConsumerName
Controller
ControllerArea
ControllerName
CronGroup
CronJobName
DATE
DefaultValue
Dep1FQCN
Dep1Type
Dep2FQCN
Dep2Type
DESC
Description
DescriptiveName
ENTITY_UPPER
ENVIRONMENT_LIMITATIONS
EXECUTIVE_SUMMARY
Entity
EntityName
ExchangeName
Existing
ExistingModule
FINDINGS_HTML
FeatureName
FieldId
FieldTitle
From
Group
GRAPHQL_TABLE
GroupId
HIGH_COUNT
ID
IndexerName
Interface
Item
JobName
LOW_COUNT
MEDIUM_COUNT
METHOD
MODULE_DESCRIPTION
MODULE_NAME
MODULE_PATH
MODULE_UPPER
MessageName
Method
Module
ModuleA
ModuleB
ModuleC
ModuleName
N
NNN
NEXT_STEPS
Name
ObserverName
OtherPatch
PARALLEL_REVIEW_SECTION
POSITIVE_OBSERVATIONS
PLACEHOLDER
ParentIdAccessor
ParentTheme
ParentVendor
Patch
PatchName
Path
PLUGINS_TABLE
PluginName
PreferenceFor
PreferenceForShort
PublisherName
QueueName
REST_ROUTES_TABLE
SHA1
SHA2
Schedule
Section
SectionId
SortOrder
Service
ServiceName
Severity
ShortDescription
SourceName
SubNamespace
TOOL_RESULTS_TABLE
TargetFqcn
TargetNamespace
TargetShortName
Theme
Title
To
TopicName
VENDOR_UPPER
Vendor
Version
YYYY-MM-DD
action
actual
area
args
attribute_code
author
author_email
bytes
code
col
command_name
commit
component
component-name-kebab
consumer_description
cron_job_name
ctx.magento_cli
ctx.magento_root
ctx.runner
date
default
depMethod
depReturn
description
entities
entity
entity_lower
env
event_name
event_short_name
existing_table
expected
field
file
file1
file2
file_name
fixture
framework_constraint
from
from_magento
from_php
id_column
ids
indexer_id
invalidArgs
kebab-title
line
magento
magento_cli
magento_event
method
method_lower
methodUnderTest
minimum
module
module-kebab-case
module-name-kebab
module_lower
moduleName
modules
name
new
notes
observer_name
package
paramName
plugin_name
paramValue
parent_id_key
parent_theme_constraint
parent_theme_package
path
permission
php_constraint
planned
previous
purpose
queue_name
reason
reproducedArgs
reproducedReturn
route
runner
slug
source_table
sum
surface
target_short_lower
target_table
template_name
theme_lower
timestamp
to
to_magento
to_php
topic
url
user
uuid
vendor
vendor_lower
ver
version
```
