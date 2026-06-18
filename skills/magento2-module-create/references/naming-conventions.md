# Naming Conventions

The authoritative naming rules for every Magento 2 identifier this skill generates live in the
shared reference:

**→ `magento2-context/references/naming.md`** — sections 1–12: Module & Package, PHP Classes &
Interfaces, Database, ACL Resources, Config Paths, Routes, Events, Cron, Queue, REST API,
GraphQL, General Rules.

Apply it to every identifier — classes, interfaces, tables, columns, ACL resources, routes,
config paths, events, cron jobs, queue topics. Violations cause review Category 3 failures. All
patterns use `{Vendor}` / `{vendor_lower}`; resolve these from project context before generating
(see SKILL.md Step 1).

This file previously inlined a copy of those rules. It is now a pointer so the conventions stay
single-sourced and cannot drift — `naming.md` is a strict superset of what this skill needs
(there are no `module-create`-specific naming deltas).
