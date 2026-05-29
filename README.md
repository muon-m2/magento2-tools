# magento2-tools

A Claude Code **plugin** of skills for end-to-end Magento 2 engineering: scaffolding,
review, testing, bug-fixing, deployment, auditing, and more — built around a shared
context-resolver so the same toolkit adapts to any project and environment.

## Install

```
/plugin marketplace add Muon/magento2-tools
/plugin install magento2-tools@muon --scope user
```

`--scope user` makes it available in every project. Use `--scope project` to pin it to
one repo. Skills are then invoked namespaced, e.g. `magento2-tools:magento2-bug-fix`.

**Team auto-enable** — commit to a project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "muon": { "source": { "source": "github", "repo": "Muon/magento2-tools" } }
  },
  "enabledPlugins": { "magento2-tools@muon": true }
}
```

On folder-trust, Claude Code offers to install the marketplace and enables the plugin —
zero manual steps for teammates.

## Skills

17 skills under `skills/`, each self-contained (`SKILL.md` + `references/` + `scripts/`
+ `templates/`).

| Skill | Purpose |
|-------|---------|
| `magento2-context` | Resolves project context (vendor, runner, Magento root/version, tools). The hub every other skill delegates environment questions to. |
| `magento2-module-create` | Scaffold a new module. |
| `magento2-module-review` | Review a module / diff against standards. Owns the shared JSON/SARIF emitters. |
| `magento2-feature-implement` | End-to-end feature workflow; orchestrates most other skills. |
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

### Dependency graph

`magento2-context` is the universal leaf — every other skill resolves environment through
it and it depends on nothing. `magento2-feature-implement` is the top orchestrator.
`magento2-module-review` owns the shared findings emitters that the audit skills reuse.

```
magento2-context  ◄── (called by all others; depends on nothing)

magento2-feature-implement ──► module-create, module-review, test-generate,
                               eav-attribute, graphql-create, frontend-create,
                               data-migration, deploy, debug, security-audit,
                               performance-audit, bug-fix

magento2-bug-fix           ──► context, module-review, deploy, data-migration, debug
magento2-deploy            ──► context, module-upgrade, release
magento2-module-create     ──► context, module-review
magento2-module-review     ──► context        (+ emit-json.sh / emit-sarif.sh shared here)
magento2-security-audit    ──► context, module-review, module-upgrade
magento2-performance-audit ──► context, module-review, security-audit
magento2-eav-attribute     ──► context, module-create, module-review
magento2-graphql-create    ──► context, module-create, module-review, test-generate
magento2-frontend-create   ──► context, module-create, module-review
magento2-module-upgrade    ──► context, module-review, test-generate
magento2-data-migration    ──► context, module-review
magento2-test-generate     ──► context, module-create
magento2-release           ──► context, deploy
magento2-i18n              ──► context
magento2-debug             ──► context, performance-audit, security-audit
```

## Per-project environment overrides

`magento2-context` auto-detects the runner (Docker vs bare PHP) and the Magento root.
For non-standard setups, override detection (env var wins over file):

```bash
export M2_PHP_CONTAINER=my-php-container   # name of the running PHP container
export M2_MAGENTO_ROOT=src                 # Magento root (default: auto-detect "." or "src")
```

or commit a per-project `.claude/m2.json`:

```json
{ "php_container": "my-php-container", "magento_root": "src" }
```

A configured container that is not running falls through to generic name-pattern
detection. Changing any override busts the resolver cache automatically.

## Layout

```
.claude-plugin/
  plugin.json        # plugin manifest
  marketplace.json   # this repo doubles as its own marketplace ("muon")
skills/              # 17 magento2-* skills (auto-discovered by Claude Code)
tests/               # contract test harness
```

Bundled scripts are invoked from SKILL.md as `${CLAUDE_SKILL_DIR}/scripts/<name>` (own
skill) or `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/scripts/<name>` (cross-skill); the scripts
themselves self-locate via `BASH_SOURCE`, so they are layout-independent.

## Tests

```bash
bash tests/run-all.sh
```

Contract tests cover bash syntax, template lint (PHP/XML/JSON/GraphQL/CSV/JS),
cross-reference integrity (including `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`
paths), and skill-version-registry consistency.

## Versioning

Skill versions and changelog live in
`skills/magento2-context/references/skill-versioning.md`. The plugin itself is versioned
in `.claude-plugin/plugin.json`; see `CHANGELOG.md`.
