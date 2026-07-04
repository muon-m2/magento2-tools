---
name: magento2-debug
description:
    Interactive Magento 2 debugging assistant. Use when the user wants to inspect logs,
    trace plugins or observers for a given event, inspect the DI graph, find slow
    queries, or get a snapshot of indexer/queue/cron state. Read-only by default —
    produces a diagnostic report without modifying code. Mode-driven: logs / trace / di /
    slow-queries / snapshot / xdebug. Read-only single-session inspection; for severity-ranked,
    actionable performance findings (N+1, caching) use magento2-performance-audit.
---

# Magento 2 Debug

Read-only debugging assistant. Surfaces information that's expensive to gather manually
and easy to misread.

## Core Rules

- **Read-only by default.** This skill does not edit source code. If the user wants
  remediation, redirect to `magento2-bug-fix` or `magento2-performance-audit`.
- **Mode-driven.** Each invocation picks one mode based on the user's request.
- **Static-first where possible.** `trace` and `di` modes work entirely off the source
  tree; runtime modes (`logs`, `slow-queries`, `snapshot`) need filesystem/CLI access.
- **De-dupe noisy output.** Log triage groups by error signature; slow-query analysis
  groups by query pattern. Don't dump raw output into the conversation.

## Modes

### `logs`

```
/magento2-debug logs --since=1h --pattern="checkout"
```

Inspects Magento logs. Reads `var/log/system.log`, `var/log/exception.log`,
`var/log/debug.log`, or a custom path. Groups by error signature, surfaces the top 20
distinct entries with first/last seen + count + sample.

See `references/log-locations.md` and `${CLAUDE_SKILL_DIR}/scripts/log-triage.sh`.

### `trace`

```
/magento2-debug trace --event=checkout_submit_all_after
/magento2-debug trace --method='Magento\Catalog\Model\Product::save'
/magento2-debug trace --class='Magento\Catalog\Api\ProductRepositoryInterface'
```

For an event: lists all observers across enabled modules, sorted by area then module.
For a method: lists all plugins (before / around / after) with `sortOrder` and `disabled`.
For a class: shows DI `<preference>` resolution.

Output: Mermaid sequence diagram of the actual call chain.

See `references/event-catalog.md` and `${CLAUDE_SKILL_DIR}/scripts/plugin-trace.sh`.

### `di`

```
/magento2-debug di --for='Magento\Catalog\Api\ProductRepositoryInterface'
```

Shows DI graph for a type:

- All `<preference>` for the interface
- All plugins on the resolved type
- All argument bindings from `<type>` entries

Useful when wondering "why is Magento using this implementation?"

See `references/di-graph-walk.md` and `${CLAUDE_SKILL_DIR}/scripts/di-walk.sh`.

### `slow-queries`

```
/magento2-debug slow-queries --since=24h
```

Reads MySQL slow log (path configurable). Groups queries by signature (replaces literals
with placeholders). Top 20 by total time + per-query suggestions:

- Missing index inferred from WHERE columns
- WHERE on non-indexed columns
- Table scan hint
- Repeat-query pattern hint

See `references/slow-query-patterns.md` and `${CLAUDE_SKILL_DIR}/scripts/slow-query-parse.sh`.

### `snapshot`

```
/magento2-debug snapshot
```

One-shot system snapshot:

- Indexer status + mode
- Cache type status
- Queue consumers + backlog
- Pending cron jobs
- Magento mode (developer/production)
- Maintenance flag
- DB version
- PHP version + extensions
- `composer outdated`

Output: single Markdown snapshot for paste-into-ticket. Produced by
`${CLAUDE_SKILL_DIR}/scripts/snapshot.sh` (read-only; resolves `{magento_cli}`/`{runner}` from
the magento2-context cache, every probe best-effort).

See `references/snapshot-format.md`.

### `xdebug`

```
/magento2-debug xdebug
```

- Check Xdebug config in container
- Verify port 9003 + IDE-side path mapping
- Toggle Xdebug on/off (delegating to Makefile / project script if present)

Includes troubleshooting checklist.

## Inputs

```
/magento2-debug <mode> [mode-specific flags]
```

Common flags:

- `--since=<duration>` — `1h`, `24h`, `7d`
- `--module=<Vendor>_<Module>` — constrain scope
- `--format=markdown|json` — output format
- `--save` — write to `{output_root}/debug/{mode}-{date}.md`
- `--docs-root=<path>` — output-root override for `--save`; see "Output root" below.

## Outputs

- Markdown to conversation (always)
- Optional `{output_root}/debug/{mode}-{date}.md` when `--save`

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). It only affects the opt-in `--save`
output: when set, write the saved report under `<path>/debug/`; otherwise default to
`{ctx.docs_root}/debug/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `references/log-locations.md` — default log paths + variations.
- `references/event-catalog.md` — common Magento events.
- `references/slow-query-patterns.md` — known patterns + index suggestions.
- `references/di-graph-walk.md` — di.xml graph walking technique.
- `references/snapshot-format.md` — snapshot section structure.
- `references/xdebug-troubleshooting.md` — Xdebug config + common issues.

## Scripts

- `${CLAUDE_SKILL_DIR}/scripts/log-triage.sh` — group log entries by signature.
- `${CLAUDE_SKILL_DIR}/scripts/di-walk.sh` — di.xml graph walker.
- `${CLAUDE_SKILL_DIR}/scripts/plugin-trace.sh` — plugin discovery for a target.
- `${CLAUDE_SKILL_DIR}/scripts/slow-query-parse.sh` — MySQL slow-log parser.

## Acceptance Criteria

- Each mode runs without writing to source code.
- Failure to read a log file degrades gracefully (reports "log not readable" rather than
  crashing).
- `trace` mode produces output matching `bin/magento dev:di:info` where the CLI is
  available, and is correct from static inspection alone otherwise.

## Notes

This skill is **read-only**. It does not edit any file. If the user wants to act on
findings, the skill suggests the appropriate next skill:

- defects → `magento2-bug-fix`
- slow-query patterns → `magento2-performance-audit`
- DI collisions → `magento2-security-audit`

## Related Skills

| Phase                                               | Skill              |
|-----------------------------------------------------|--------------------|
| 0                                                   | `magento2-context` |
| (none — output is the deliverable; no code changes) |                    |
