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
`{ConfigPath}` (full config path `{section}/{group}/{field}`, used in typed reader constants),
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
`{timestamp}`, `{uuid}`, `{author}`, `{commit}`, `{env}`, `{path}` / `{Path}`, `{file}` /
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
Area
EventName
AttributeCode
BackendModelName
BackendName
Behaviour
CHECKLIST_TABLE
CRITICAL_COUNT
Class
ClassUnderTest
Code
ConsumerName
Controller
ControllerArea
ControllerName
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
Existing
ExistingModule
FINDINGS_HTML
FeatureName
FieldId
From
Group
GroupId
HIGH_COUNT
ID
Interface
Item
JobName
LOW_COUNT
MEDIUM_COUNT
METHOD
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
PluginName
PreferenceFor
PreferenceForShort
SHA1
SHA2
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
bytes
code
col
commit
component
component-name-kebab
consumer_description
ctx.magento_cli
ctx.magento_root
ctx.runner
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
ids
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
