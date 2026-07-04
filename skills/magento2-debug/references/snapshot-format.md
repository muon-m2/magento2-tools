# Snapshot Format

The `snapshot` mode produces a single Markdown document for paste-into-ticket.

## Required Sections

```markdown
# Magento Snapshot — {YYYY-MM-DD HH:MM UTC}

Skill versions: magento2-debug@1.3.0, magento2-context@1.8.0
Magento mode: {production|developer|default}
Maintenance flag: {enabled|disabled}

## Versions

- Magento: {version} ({edition})
- PHP: {version}
- MySQL: {version}
- Composer: {version}
- Node: {version}

## Modules

- Total enabled: {N}
- Custom modules: {N}
- Vendor modules: {N}

## Indexers

| ID | Status | Mode |
|----|--------|------|
| catalog_product_attribute | Ready | schedule |
| catalogsearch_fulltext | Reindex Required | schedule |
...

## Cache

| Cache type | Status |
|-----------|--------|
| config | Enabled |
| layout | Enabled |
...

## Queue Consumers

| Consumer | Registered | Running |
|----------|-----------|---------|
| product_action_attribute.update | Yes | Yes |
...

## Cron

- Last successful run: {timestamp}
- Pending jobs: {N}
- Failed jobs in last hour: {N}

## Storage

- DB size: {GB}
- var/log/ size: {MB}
- var/cache/ size (if local): {MB}

## Composer Outdated

| Package | Current | Latest |
|---------|---------|--------|
| magento/framework | 103.0.7-p3 | 103.0.7-p5 |
...

## Recent Errors (last hour)

| Signature | Count | Last seen |
|-----------|-------|-----------|
| TypeError in OrderRepository::save() | 12 | 2026-05-24 14:30:00 |
...
```

## Optional Sections

When relevant:

```markdown
## Redis

- Hit rate: 98.4%
- Memory used: 1.2 GB
- Connected clients: 14

## Varnish

- Cache hit rate (last hour): 92.1%
- 5xx rate: 0.02%
```

## Output Behaviour

- Always print to conversation.
- With `--save`: also write to `.docs/debug/snapshot-{date}.md`. `.docs/` is anchored at the
  project root (`{ctx.docs_root}`), never under `{ctx.magento_root}` — see the **Artifact
  location** rule in `magento2-context/SKILL.md`.

## Failure Handling

A check that fails (e.g. MySQL CLI not available) is recorded as "n/a — {reason}" in
the snapshot, not skipped silently.

## Why This Format

The snapshot is designed to be **pasted into an incident ticket** — it gives an
on-call engineer everything they need to triage without re-running commands. Sections
appear in priority order: identity → state → recent activity → infra.
