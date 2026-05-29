# magento2-tools

A collection of Claude Code skills for end-to-end Magento 2 engineering: scaffolding,
review, testing, bug-fixing, deployment, and auditing.

> **Status:** Stage 0–1 (portable plain-skills repo). A Claude Code *plugin* wrapper
> (`magento2:` namespace, one-command install) is planned — see the portability plan.

## What's here

17 skills under `.claude/skills/`, each self-contained (`SKILL.md` + `references/` +
`scripts/` + `templates/`), plus a contract test harness under `.claude/skills/_tests/`.

| Skill | Purpose |
|-------|---------|
| `magento2-context` | Resolves project context (vendor, runner, Magento root/version, tools). The hub every other skill delegates environment questions to. |
| `magento2-module-create` | Scaffold a new module. |
| `magento2-module-review` | Review a module / diff against standards. |
| `magento2-feature-implement` | End-to-end feature workflow. |
| `magento2-bug-fix` | Reproduce → RCA → minimal TDD fix → regression test → review → deploy. |
| `magento2-deploy` | Pre-flight validation, ordered deploy, rollback. |
| `magento2-test-generate` | Generate unit/integration/API/MFTF tests. |
| `magento2-module-upgrade` | BC-break detection, deprecation maps. |
| `magento2-security-audit` | CVE + secret + EQP static scan. |
| `magento2-performance-audit` | N+1, caching, indexer/queue review. |
| `magento2-debug` | Investigate logs / DI graph when reproduction is hard. |
| `magento2-eav-attribute` | Add EAV attributes idempotently. |
| `magento2-graphql-create` | Schema-first GraphQL surfaces. |
| `magento2-frontend-create` | Themes, components, email templates. |
| `magento2-data-migration` | Idempotent data patches / importers. |
| `magento2-release` | Version bump, changelog, tag, publish. |
| `magento2-i18n` | Translation extraction / locale management. |

`magento2-context` is the dependency hub — most skills invoke it first. Higher-level
skills chain others (e.g. `bug-fix` calls `context`, `module-review`, `deploy`, and
`data-migration`).

## Using it today (plain repo)

Copy or symlink the skills into a project (or your user scope):

```bash
# per project
cp -r magento2-tools/.claude/skills/magento2-* <your-project>/.claude/skills/

# or user scope (available in every project)
cp -r magento2-tools/.claude/skills/magento2-* ~/.claude/skills/
```

Invoke a skill, e.g. `/magento2-bug-fix "<description>"`.

### Per-project environment overrides

`magento2-context` auto-detects the runner (Docker vs bare PHP) and the Magento root.
For non-standard setups, override detection in either of two ways (env var wins over file):

```bash
export M2_PHP_CONTAINER=my-php-container   # name of the running PHP container
export M2_MAGENTO_ROOT=src                 # path to the Magento root (default: auto-detect "." or "src")
```

or commit a per-project `.claude/m2.json`:

```json
{
  "php_container": "my-php-container",
  "magento_root": "src"
}
```

A configured container that is not actually running falls through to generic name-pattern
detection. Changing any override busts the resolver cache automatically.

## Tests

```bash
bash .claude/skills/_tests/run-all.sh
```

Contract tests cover bash syntax, template lint (PHP/XML/JSON/GraphQL/CSV/JS),
cross-reference integrity, and skill-version-registry consistency.

## Versioning

Skill versions and the changelog live in
`.claude/skills/magento2-context/references/skill-versioning.md`.
