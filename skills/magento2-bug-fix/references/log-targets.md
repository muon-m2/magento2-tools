# Magento 2 Log Targets

The canonical log-path reference is shared with the debug skill:
**`magento2-debug/references/log-locations.md`**. It lists the core Magento logs, custom-module
logs, container/infra logs, the runner-prefix reading pattern, time-window heuristics, and the
grep-patterns-by-symptom table. Resolve relative paths against `{ctx.magento_root}`.

This file used to duplicate that content (and had drifted); it now defers to it so the two
stay in sync.

## Bug-fix specifics

During Phase 1, grep the targets above and save, for each log file searched, to
`.docs/bug-fixes/{slug}/collect.md`:

- Path searched
- Pattern used
- Match count
- 3–5 sample matches with timestamps

Do not paste raw log dumps into the conversation — group by error signature and surface the
top distinct entries.
