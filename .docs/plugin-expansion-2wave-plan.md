# Plugin Expansion — 2-Wave Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six new generator/quality skills, one read-only agent, and a completed command surface to the `magento2-tools` plugin, filling the highest-value gaps in net-new Magento dev work, AI-orchestration/DX, and quality/governance — without duplicating any existing shared machinery.

**Architecture:** Every new skill clones the established generator skeleton (Phase 0–5: context → inputs → plan-gate → test-first RED/GREEN → verify → report) and delegates naming, severity, findings-schema, TDD, coding-style, and placeholder conventions to `magento2-context/references/*` (DRY). The new agent mirrors `magento2-reviewer`'s read-only contract. Quality skills reuse the shared `emit-json.sh`/`emit-sarif.sh` emitters. Nothing re-implements context resolution, findings emission, or naming rules.

**Tech Stack:** Markdown `SKILL.md` definitions, brace-delimited PHP/XML templates, POSIX `bash` helper scripts, the existing `tests/*.sh` contract harness. No new runtime dependencies.

**Wave split (as agreed):**
- **Wave 1** — Priority 1 + Priority 2: `extension-point`, `system-config`, `cli-command`, `message-queue`, `static-analysis`, `docs-generate`, and the `explorer` agent.
- **Wave 2** — Priority 3 + deferred: command-surface completion + `:scaffold` dispatcher; then `indexer`, `marketplace-prep`, `accessibility-audit` at charter depth.

---

## How to use this plan

This plan is written at **build-the-component altitude**, not generate-the-output altitude. For each new skill it gives:

1. The exact directory + file list (create paths).
2. The concrete `SKILL.md` phase structure (the core authored artifact — written in full, not summarized).
3. A **reference inventory** marking each file `NEW` (author it) or `DELEGATE` (link to an existing shared reference — never copy).
4. A **template inventory**: `template path → generated output path → token list → one-line spec → analogue to clone`.
5. Scripts, the test-first approach the skill enforces, new placeholder tokens, routing-disambiguation entries, the contract-test/wiring edits, acceptance criteria, and the commit.

Template **bodies** (the literal PHP/XML) are produced during execution by cloning the cited analogue template and applying the spec — this is deliberate DRY: e.g. an Observer class is standard Magento boilerplate that mirrors patterns already proven in `magento2-adminhtml-form`'s controllers. A template spec here is a buildable specification (exact classes, methods, XML nodes, tokens), never a "TODO".

**Per-skill TDD-of-the-build:** "tests" for building a skill are the contract suite (`bash tests/run-all.sh`) plus a dry-run of the skill against a throwaway fixture module. Each task verifies by running the named contract tests and asserting PASS. (Each skill *itself* enforces code-level TDD on what *it* generates via its Phase 3A — that is authored into the SKILL.md, below.)

---

## Shared conventions (the DRY backbone — referenced by every task)

These are established facts from the current codebase. Every task below refers back here instead of repeating them.

### S1 — Generator skeleton (clone for every new skill)

```
skills/magento2-{name}/
├── SKILL.md            # required; line 1 == "---"; name: matches dir; description ≤ 1024 chars
├── references/         # NEW domain docs (author) — keep focused
├── templates/          # brace-delimited PHP/XML/etc. (only generator skills)
└── scripts/            # optional verify-*.sh / build-*.sh helpers
```

Phase sequence authored into every generator `SKILL.md`:

- **Phase 0 — Context Resolution.** Invoke `magento2-context` (or run `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`); capture JSON as `{ctx}`. Abort if the target module is absent (offer `magento2-module-create`) or `{ctx.magento_root}` is unresolved.
- **Phase 1 — Resolve Inputs.** Ask for missing values in one batch (input table).
- **Phase 2 — Plan (gate).** Present every file to create/modify; wait for "proceed".
- **Phase 3 — Test First, then Generate.** 3A (RED): write the failing test, watch it fail for the right reason; 3B (GREEN): generate minimal code from `templates/` to pass it.
- **Phase 4 — Verify.** `php -l` on every `.php`, `xmllint --noout` on every `.xml`, run the Phase-3A test (red→green), run `magento2-module-review --diff` (gate: zero Critical/High).
- **Phase 5 — Report.** Write `.docs/{category}/{Vendor}_{Module}-{descriptor}-{date}.md` with files generated, test evidence, post-gen commands (`setup:upgrade`, cache flush, `setup:di:compile` note), and cross-links.

### S2 — Shared references (DELEGATE; never copy)

| Reference (path under `skills/magento2-context/references/`) | Use it for |
|---|---|
| `naming.md` | class/module/table/ACL/config-path/route/event/cron/queue/GraphQL naming |
| `severity.md` | Critical/High/Medium/Low/Info scale (findings skills) |
| `findings-schema.md` | JSON + SARIF 2.1.0 finding shape |
| `tdd-discipline.md` | RED→GREEN→REFACTOR loop; behaviour/boilerplate line |
| `php-coding-style.md` | PER-CS 3.0 baseline, Magento wins; `phpcs --standard=Magento2` gate |
| `placeholder-schema.md` | the `{token}` registry — **register new tokens here** |
| `skill-versioning.md` | per-skill version registry + semver + artifact header format |
| `version-resolution.md`, `vendor-resolution.md`, `runner-detection.md`, `theme-detection.md`, `tool-probe.md` | context field resolution (read-only consumers) |
| `process-skills.md` | deferral policy (only `superpowers:dispatching-parallel-agents` is sanctioned) |

### S3 — Reference-string patterns (use verbatim in SKILL.md)

- Cross-skill shared doc: `` `magento2-context/references/naming.md` `` (prose link).
- Own-skill asset: `${CLAUDE_SKILL_DIR}/scripts/verify-x.sh`, `${CLAUDE_SKILL_DIR}/templates/foo.php`.
- Cross-skill script: `${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/scripts/resolve-context.sh`.
- Shared emitters: `${CLAUDE_PLUGIN_ROOT}/skills/magento2-module-review/scripts/emit-json.sh` and `emit-sarif.sh`.

### S4 — Shared findings emitters (DRY for any findings-producing skill)

`emit-json.sh` (env-driven: `FINDINGS_FILE`, `TARGET_MODULE`, `TARGET_PATH`, `MODE`, `SCOPE`, `SKILL_NAME`, `SKILL_VERSION`, `SKILL_VERSIONS_JSON`, `OUTPUT_KIND`, `OUTPUT_BASENAME`, `DOCS_ROOT`, `OUTPUT_DIR`) writes the canonical findings JSON; `emit-sarif.sh <json>` converts it to SARIF. Reuse via a per-skill `scripts/build-findings.sh` that sets:

```bash
EMIT_JSON="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="${SCRIPT_DIR}/../../magento2-module-review/scripts/emit-sarif.sh"
```

`OUTPUT_KIND` is today one of `review|security|performance|upgrade`. **static-analysis adds `quality`** (S6).

### S5 — Registration checklist (what to touch for each component type)

**New SKILL** — auto-discovered by: frontmatter, reference-integrity, all `test-template-*-lint`, `test-version-registry-consistency`, `test-placeholder-tokens`, `test-bash-syntax`. **Manually edit:**
1. `skills/magento2-context/references/skill-versioning.md` — add row (initial `1.0.0`) **[required or version-consistency fails]**.
2. `README.md` (skill count, line ~69 + Skills table), `docs/README.md` (line 3), `docs/skills-reference.md` (new section + count) — **[required or `test-skill-count-consistency.sh` fails]**.
3. `skills/magento2-context/references/placeholder-schema.md` — register any new `{tokens}` **[required or `test-placeholder-tokens.sh` fails]**.
4. `tests/test-routing-discriminators.sh` + `docs/skills-reference.md` routing table — **only if** the skill is disambiguated vs siblings.
5. `tests/test-audit-builders.sh` — **only if** the skill ships a findings `build-findings.sh`.

**New COMMAND** — **manually edit:** `tests/test-command-routing.sh` `EXPECTED` list (hardcoded), create `commands/{verb}.md`, update `README.md` Commands table + count. Write commands set `disable-model-invocation: true`; read-only omit it.

**New AGENT** — auto-discovered by `tests/test-agent-routing.sh` (requires closed `name`+`description`+`tools` frontmatter; review/comprehension agents must **not** declare `Write`/`Edit`/`NotebookEdit`; all `${CLAUDE_PLUGIN_ROOT}/skills/...` refs must resolve). **Manually:** register in the calling skill's reference doc (mirror `magento2-module-review/references/parallel-review.md`).

**feature-implement task type** — `skills/magento2-feature-implement/references/task-breakdown-guide.md` task table + the routing logic in its `SKILL.md`. New prefixes claimed by this plan: `I`=extension-point, `C`=system-config, `L`=cli-command, `Q`=message-queue. (static-analysis reuses the existing `V`=Validate gate; docs-generate is post-hoc, no prefix.)

### S6 — `OUTPUT_KIND=quality` (one small shared change, Task 5)

Add `quality` to the `OUTPUT_KIND` vocabulary used by `emit-json.sh`/`findings-schema.md` so `magento2-static-analysis` can emit through the shared pipeline. Files: `findings-schema.md` (enum line), and a golden refresh if `tests/test-golden-emitters.sh` snapshots the enum (run `UPDATE_GOLDEN=1` only if the test fails on the new value).

---

# WAVE 1

## Task 1: `magento2-extension-point` skill (plugin / observer / preference)

The single most common Magento customization — wiring behaviour onto *existing* code — has no skill today. One skill, three modes (mirrors how `eav-attribute` handles four entity types).

**Files:**
- Create: `skills/magento2-extension-point/SKILL.md`
- Create: `skills/magento2-extension-point/references/plugin-types.md`
- Create: `skills/magento2-extension-point/references/observer-events.md`
- Create: `skills/magento2-extension-point/references/preference-vs-plugin.md`
- Create: `skills/magento2-extension-point/references/area-scoping.md`
- Create: `skills/magento2-extension-point/references/pitfalls.md`
- Create: `skills/magento2-extension-point/templates/plugin-class.php`
- Create: `skills/magento2-extension-point/templates/plugin-di.xml`
- Create: `skills/magento2-extension-point/templates/observer-class.php`
- Create: `skills/magento2-extension-point/templates/events.xml`
- Create: `skills/magento2-extension-point/templates/preference-di.xml`
- Create: `skills/magento2-extension-point/templates/preference-class.php`
- Create: `skills/magento2-extension-point/templates/test-plugin-unit.php`
- Create: `skills/magento2-extension-point/templates/test-observer-unit.php`
- Modify (wiring): `skill-versioning.md`, `placeholder-schema.md`, `README.md`, `docs/README.md`, `docs/skills-reference.md`, `tests/test-routing-discriminators.sh`, `feature-implement` task guide + SKILL.md.

**SKILL.md (authored content):**

- Frontmatter `description`: "Wire behaviour onto an *existing* Magento 2 class without editing it — a **plugin** (before/after/around interceptor + `di.xml`), an **observer** (`events.xml` + Observer), or a **preference**. Use when the user wants to intercept a core/3rd-party method, react to an event, or swap an implementation. For a whole new module use `magento2-module-create`; for multi-surface work use `magento2-feature-implement`."
- Core rules: never edit the target class; choose the lightest mechanism (observer < plugin < preference); `around` plugins only when before+after cannot express it; never plugin `final`/`private`/`static` methods or data interfaces; area-scope the wiring (`etc/di.xml` vs `etc/{area}/di.xml`).
- **Phase 0–5** per S1. Phase 1 inputs by mode:

| Mode | Inputs |
|---|---|
| `plugin` | target FQCN, method, type (`before`/`after`/`around`), area, plugin name, sortOrder, module |
| `observer` | event name, observer name, area, module, dispatched-data shape |
| `preference` | `for` interface/class FQCN, replacement class, area, module |

- Phase 3A (RED): plugin → unit test asserting the interceptor transforms the argument/return (mock subject); observer → unit test asserting `execute()` acts on the event payload; preference → integration test asserting `ObjectManager::get({for})` returns the replacement. Cite `magento2-context/references/tdd-discipline.md`.
- Phase 5 report: `.docs/extension-points/{Vendor}_{Module}-{mode}-{slug}-{date}.md`.

**Reference inventory:**

| File | Status | Contents |
|---|---|---|
| `plugin-types.md` | NEW | before/after/around semantics; return-value & argument rules; `$proceed` cost; sortOrder |
| `observer-events.md` | NEW | common dispatched events; `Observer`/`Event` payload access; sync vs `<event>` in area |
| `preference-vs-plugin.md` | NEW | decision matrix; why preferences are a last resort; conflict risk |
| `area-scoping.md` | NEW | which `di.xml`/`events.xml` (`global` vs `frontend`/`adminhtml`/`webapi_rest`/`graphql`/`crontab`) |
| `pitfalls.md` | NEW | final/private/static, data-interface plugins, around-proceed perf, observer idempotency, no DB writes in hot events |
| naming, tdd-discipline, php-coding-style, placeholder-schema | DELEGATE (S2) | — |

**Template inventory:**

| Template | → Output | Tokens | Spec / analogue |
|---|---|---|---|
| `plugin-class.php` | `Plugin/{PluginName}.php` | `{Vendor}`,`{Module}`,`{PluginName}`,`{TargetFqcn}`,`{Method}` | before/after/around method stub typed to subject; mirror class-header style of `adminhtml-form/templates/generic-button.php` |
| `plugin-di.xml` | `etc/{area}/di.xml` (merge) | `{TargetFqcn}`,`{Vendor}`,`{Module}`,`{PluginName}`,`{plugin_name}`,`{SortOrder}` | `<type><plugin name type sortOrder/></type>`; mirror merge style of `webapi-create/templates/di.xml` |
| `observer-class.php` | `Observer/{ObserverName}.php` | `{Vendor}`,`{Module}`,`{ObserverName}` | implements `ObserverInterface`; typed `execute(Observer $observer)` |
| `events.xml` | `etc/{area}/events.xml` (merge) | `{EventName}`,`{Vendor}`,`{Module}`,`{ObserverName}`,`{observer_name}` | `<event name><observer name instance/></event>` |
| `preference-di.xml` | `etc/{area}/di.xml` (merge) | `{PreferenceFor}`,`{Vendor}`,`{Module}`,`{EntityName}` | `<preference for type/>` |
| `preference-class.php` | `Model/{EntityName}.php` | `{Vendor}`,`{Module}`,`{EntityName}`,`{PreferenceFor}` | extends/implements `{PreferenceFor}` |
| `test-plugin-unit.php` | `Test/Unit/Plugin/{PluginName}Test.php` | `{Vendor}`,`{Module}`,`{PluginName}` | mock subject; assert interception; mirror unit test shape in `eav-attribute` source-model test |
| `test-observer-unit.php` | `Test/Unit/Observer/{ObserverName}Test.php` | `{Vendor}`,`{Module}`,`{ObserverName}` | mock `Observer`/`Event`; assert effect |

**New placeholder tokens to register:** `{PluginName}`,`{plugin_name}`,`{TargetFqcn}`,`{Method}`,`{SortOrder}`,`{EventName}`,`{event_name}`,`{PreferenceFor}`,`{Area}`,`{area}`. (`{ObserverName}`,`{EntityName}` already registered.)

**Routing-discriminator edit:** add `check extension-point  magento2-module-create magento2-feature-implement` to `tests/test-routing-discriminators.sh`; add a row to the `docs/skills-reference.md` table; ensure `module-create` and `feature-implement` descriptions reference `extension-point` (and vice-versa).

**Steps:**
- [ ] **Step 1** — Author the 8 templates + 5 references + `SKILL.md` per the inventories above.
- [ ] **Step 2** — Register new tokens in `placeholder-schema.md`; add the `extension-point` row to `skill-versioning.md` (`1.0.0`); add routing entries (S5).
- [ ] **Step 3** — Update skill count + add section in `README.md`, `docs/README.md`, `docs/skills-reference.md`.
- [ ] **Step 4** — Run: `bash tests/test-placeholder-tokens.sh && bash tests/test-skill-frontmatter.sh && bash tests/test-reference-integrity.sh && bash tests/test-template-php-lint.sh && bash tests/test-template-xml-lint.sh && bash tests/test-routing-discriminators.sh && bash tests/test-skill-count-consistency.sh && bash tests/test-version-registry-consistency.sh` — Expected: all PASS (or SKIP 77 if `php`/`xmllint` absent).
- [ ] **Step 5** — Dry-run the skill against a throwaway fixture module for each mode; confirm generated `di.xml`/`events.xml` pass `xmllint` and the unit test goes red→green.
- [ ] **Step 6** — Commit: `git commit -m "feat(skills): add magento2-extension-point (plugin/observer/preference)"`

**Acceptance:** all three modes generate code passing `magento2-module-review` with zero Critical/High; contract suite green; routing test pins the new boundary.

---

## Task 2: `magento2-system-config` skill (admin store configuration + typed reader)

Adding a `system.xml` config field is an everyday task with no dedicated skill (`module-create` only stubs `admin_config` for new modules).

**Files:**
- Create: `skills/magento2-system-config/SKILL.md`
- Create: `skills/magento2-system-config/references/system-xml-anatomy.md`
- Create: `skills/magento2-system-config/references/field-types.md`
- Create: `skills/magento2-system-config/references/scope-and-paths.md`
- Create: `skills/magento2-system-config/references/config-reader-pattern.md`
- Create: `skills/magento2-system-config/references/encrypted-fields.md`
- Create: `skills/magento2-system-config/templates/system.xml`
- Create: `skills/magento2-system-config/templates/config.xml`
- Create: `skills/magento2-system-config/templates/acl.xml`
- Create: `skills/magento2-system-config/templates/source-model.php`
- Create: `skills/magento2-system-config/templates/backend-model.php`
- Create: `skills/magento2-system-config/templates/config-reader.php`
- Create: `skills/magento2-system-config/templates/test-config-reader-unit.php`
- Create: `skills/magento2-system-config/templates/test-source-model-unit.php`

**SKILL.md (authored content):**

- Frontmatter `description`: "Add admin store configuration to an existing module — `system.xml` section/group/field, `config.xml` defaults, ACL, optional source/backend models, plus a typed `Config` reader (`ScopeConfigInterface` wrapper with store-aware getters). Use for 'add a config field/toggle/API-key setting' in *Stores → Configuration*. For an admin **data** edit form use `magento2-adminhtml-form`; for a new module use `magento2-module-create`."
- Core rules: config path `{vendor_lower}_{module_lower}/{group}/{field}` (cite `naming.md`); secrets use `backend_model=Magento\Config\Model\Config\Backend\Encrypted` + `field type="obscure"`; never read config via `ScopeConfigInterface` ad-hoc in business code — generate the typed reader; ACL config node nests under the module's `::config` resource.
- Phase 1 inputs: module; section (id/label/tab); one+ groups; per field: id, label, `type`, sortOrder, scope flags (`showInDefault/Website/Store`), source model?, backend model?, comment, `depends`; generate typed reader? (default yes).
- Phase 3A (RED): unit test of the typed reader asserting it maps each `{config_path}` to the right `ScopeConfigInterface::getValue(path, scope, scopeId)` call and casts types; unit test of any source model `toOptionArray()`.
- Phase 5 report: `.docs/system-config/{Vendor}_{Module}-{section}-{date}.md` (lists admin path, config paths, ACL resource, default values).

**Reference inventory:** all five NEW (`system-xml-anatomy.md`, `field-types.md` incl. `text/select/multiselect/textarea/file/obscure/button`, `scope-and-paths.md`, `config-reader-pattern.md`, `encrypted-fields.md`); DELEGATE naming/tdd/coding-style/placeholder per S2.

**Template inventory:**

| Template | → Output | Tokens | Spec / analogue |
|---|---|---|---|
| `system.xml` | `etc/adminhtml/system.xml` (merge) | `{Vendor}`,`{Module}`,`{SectionId}`,`{GroupId}`,`{FieldId}`,`{vendor_lower}`,`{module_lower}`,`{ConfigPath}` | section/group/field with scope flags + optional `source_model`/`backend_model`/`depends`; mirror merge handling in `adminhtml-form/templates/menu.xml` |
| `config.xml` | `etc/config.xml` (merge) | `{vendor_lower}`,`{module_lower}`,`{GroupId}`,`{FieldId}`,`{DefaultValue}` | `<default>` tree |
| `acl.xml` | `etc/acl.xml` (merge) | `{Vendor}`,`{Module}` | nests config resource under `Magento_Config::config`; mirror `adminhtml-form/templates/acl.xml` |
| `source-model.php` | `Model/Config/Source/{SourceName}.php` | `{Vendor}`,`{Module}`,`{SourceName}` | implements `OptionSourceInterface`; mirror `eav-attribute/templates/source-model.php` |
| `backend-model.php` | `Model/Config/Backend/{BackendModelName}.php` | `{Vendor}`,`{Module}`,`{BackendModelName}` | extends `Magento\Framework\App\Config\Value` |
| `config-reader.php` | `Model/Config.php` | `{Vendor}`,`{Module}`,`{ConfigPath}`,`{FieldId}` | typed getters wrapping `ScopeConfigInterface`; `isSetFlag` for toggles; store-scope param |
| `test-config-reader-unit.php` | `Test/Unit/Model/ConfigTest.php` | `{Vendor}`,`{Module}` | mock `ScopeConfigInterface`; assert path + cast |
| `test-source-model-unit.php` | `Test/Unit/Model/Config/Source/{SourceName}Test.php` | `{Vendor}`,`{Module}`,`{SourceName}` | assert `toOptionArray()` |

**New placeholder tokens:** `{SectionId}`,`{GroupId}`,`{FieldId}`,`{ConfigPath}`,`{BackendModelName}`,`{DefaultValue}`,`{module_lower}` (verify `{module_lower}`/`{SourceName}` already registered — `{SourceName}` is; `{module_lower}` is). Register the genuinely-new ones.

**Routing:** add `check system-config  magento2-module-create magento2-adminhtml-form`; cross-reference descriptions; add routing-table row.

**Steps:** mirror Task 1 Steps 1–6 (author → register/version/route → docs → run the same contract-test command set → dry-run → commit `feat(skills): add magento2-system-config`).

**Acceptance:** generated config appears in admin at the stated path; typed reader unit test red→green; zero Critical/High in review.

---

## Task 3: `magento2-cli-command` skill (console command + cron job)

Two modes (`command`, `cron`) — both are common operational entry points with intricate `di.xml`/`crontab.xml` wiring and no current skill (`module-create` only stubs `cron`).

**Files:**
- Create: `skills/magento2-cli-command/SKILL.md`
- Create: `skills/magento2-cli-command/references/console-command-anatomy.md`
- Create: `skills/magento2-cli-command/references/cron-anatomy.md`
- Create: `skills/magento2-cli-command/references/pitfalls.md`
- Create: `skills/magento2-cli-command/templates/command-class.php`
- Create: `skills/magento2-cli-command/templates/command-di.xml`
- Create: `skills/magento2-cli-command/templates/cron-job-class.php`
- Create: `skills/magento2-cli-command/templates/crontab.xml`
- Create: `skills/magento2-cli-command/templates/test-command-unit.php`
- Create: `skills/magento2-cli-command/templates/test-cron-unit.php`

**SKILL.md (authored content):**

- Frontmatter `description`: "Scaffold a `bin/magento` **console command** (Symfony Command + `commandList` registration + arguments/options/exit-codes) or a **cron job** (`crontab.xml` + job class, fixed or config-path schedule) on an existing module. Use for 'add a CLI command' / 'add a scheduled job'. Business logic belongs in a service the command/job calls, not in the command itself."
- Core rules: command name = `{vendor_lower}:{module_lower}:{action}`; exit via `Cli::RETURN_SUCCESS`/`RETURN_FAILURE`; delegate logic to a constructor-injected service; set area code when emulating store context; cron jobs must be idempotent and locking-aware for long runs; schedule via `<schedule>` literal or `<config_path>` (pair with `magento2-system-config`).
- Phase 1 inputs: mode; for command → name, description, arguments (name/required/desc), options (name/shortcut/mode/desc), the service FQCN it invokes, module; for cron → job name, schedule expression *or* config path, job class, cron group (default `default`), module.
- Phase 3A (RED): command → `Symfony\Component\Console\Tester\CommandTester` unit test asserting output + exit code for a mocked service; cron → unit test asserting `execute()` calls the service and is safe to call twice.
- Phase 5 report: `.docs/cli-commands/{Vendor}_{Module}-{mode}-{slug}-{date}.md` (run command / `cron:run` group, schedule).

**Reference inventory:** `console-command-anatomy.md` (NEW), `cron-anatomy.md` (NEW: groups, schedule vs config_path, `default` group, `cron:run`), `pitfalls.md` (NEW); DELEGATE per S2.

**Template inventory:**

| Template | → Output | Tokens | Spec / analogue |
|---|---|---|---|
| `command-class.php` | `Console/Command/{CommandClass}.php` | `{Vendor}`,`{Module}`,`{CommandClass}`,`{CommandName}`,`{command_name}`,`{ServiceName}` | extends `Symfony\...\Command`; `configure()` + `execute()`; inject `{ServiceName}` |
| `command-di.xml` | `etc/di.xml` (merge) | `{Vendor}`,`{Module}`,`{CommandClass}`,`{command_name}` | `CommandList` array `<item>` registration |
| `cron-job-class.php` | `Cron/{CronJobName}.php` | `{Vendor}`,`{Module}`,`{CronJobName}`,`{ServiceName}` | `execute()` delegating to service |
| `crontab.xml` | `etc/crontab.xml` (merge) | `{Vendor}`,`{Module}`,`{CronJobName}`,`{cron_job_name}`,`{CronGroup}`,`{Schedule}` | `<group id><job name instance method="execute"><schedule/></job></group>` |
| `test-command-unit.php` | `Test/Unit/Console/Command/{CommandClass}Test.php` | `{Vendor}`,`{Module}`,`{CommandClass}` | CommandTester; assert exit code |
| `test-cron-unit.php` | `Test/Unit/Cron/{CronJobName}Test.php` | `{Vendor}`,`{Module}`,`{CronJobName}` | mock service; assert call |

**New placeholder tokens:** `{CommandClass}`,`{CommandName}`,`{command_name}`,`{CronJobName}`,`{cron_job_name}`,`{CronGroup}`,`{Schedule}`. (`{ServiceName}` already registered.)

**Routing:** add `check cli-command  magento2-module-create`; reference in descriptions; routing-table row.

**Steps:** mirror Task 1 Steps 1–6; commit `feat(skills): add magento2-cli-command (console + cron)`.

**Acceptance:** `bin/magento {name}` runs and returns correct exit code; cron job registers in `cron:install`/shows in `cron_schedule`; tests red→green; zero Critical/High.

---

## Task 4: `magento2-message-queue` skill (async messaging)

`module-create`'s `queue` surface is a stub; real pub/sub wiring spans five XML files plus DTO/publisher/consumer and is highly error-prone — a specialist earns its place (the same logic that justified `graphql-create`/`webapi-create`).

**Files:**
- Create: `skills/magento2-message-queue/SKILL.md`
- Create: `skills/magento2-message-queue/references/mq-architecture.md`
- Create: `skills/magento2-message-queue/references/message-dto.md`
- Create: `skills/magento2-message-queue/references/consumer-runtime.md`
- Create: `skills/magento2-message-queue/references/pitfalls.md`
- Create: `skills/magento2-message-queue/templates/communication.xml`
- Create: `skills/magento2-message-queue/templates/queue_topology.xml`
- Create: `skills/magento2-message-queue/templates/queue_publisher.xml`
- Create: `skills/magento2-message-queue/templates/queue_consumer.xml`
- Create: `skills/magento2-message-queue/templates/message-interface.php`
- Create: `skills/magento2-message-queue/templates/message-model.php`
- Create: `skills/magento2-message-queue/templates/publisher.php`
- Create: `skills/magento2-message-queue/templates/consumer.php`
- Create: `skills/magento2-message-queue/templates/queue-di.xml`
- Create: `skills/magento2-message-queue/templates/test-consumer-unit.php`

**SKILL.md (authored content):**

- Frontmatter `description`: "Scaffold a full async message-queue surface on an existing module — `communication.xml` topic, `queue_topology.xml`/`queue_publisher.xml`/`queue_consumer.xml` bindings, a typed message DTO, a publisher, and an idempotent consumer/handler. Use for 'process X asynchronously' / 'add a queue consumer'. Goes beyond `magento2-module-create`'s queue stub. For a new module use `magento2-module-create` first."
- Core rules: topic name `{vendor_lower}.{module_lower}.{entity}.{action}` (cite `naming.md`); default `connection="db"` unless AMQP confirmed; messages are typed DTOs (interface + impl + `di.xml` preference), never arrays; consumers must be idempotent and handle poison messages; declare `maxMessages`/`max_idle_time` guidance, not hardcoded infinite loops.
- Phase 1 inputs: module; topic name; message DTO (name + typed fields); publisher class name; consumer name + handler method; connection (`db`/`amqp`); queue name; exchange name (AMQP only).
- Phase 3A (RED): unit test of the consumer asserting it decodes a typed message and calls the domain handler exactly once; re-delivery of the same message is a no-op (idempotency).
- Phase 5 report: `.docs/message-queues/{Vendor}_{Module}-{topic}-{date}.md` (topic, queue, `queue:consumers:start {consumer}`, cron-run note).

**Reference inventory:** `mq-architecture.md` (NEW: topic↔exchange↔queue↔consumer; db vs amqp), `message-dto.md` (NEW), `consumer-runtime.md` (NEW: `queue:consumers:start`, `cron_consumers_runner`, max messages), `pitfalls.md` (NEW: idempotency, DLQ, no heavy sync, serialization); DELEGATE per S2.

**Template inventory:**

| Template | → Output | Tokens | Spec |
|---|---|---|---|
| `communication.xml` | `etc/communication.xml` (merge) | `{TopicName}`,`{MessageInterface}` | `<topic name request/>` |
| `queue_topology.xml` | `etc/queue_topology.xml` (merge) | `{ExchangeName}`,`{TopicName}`,`{QueueName}`,`{ConnectionName}` | exchange→queue binding |
| `queue_publisher.xml` | `etc/queue_publisher.xml` (merge) | `{TopicName}`,`{ConnectionName}` | `<publisher topic><connection name/></publisher>` |
| `queue_consumer.xml` | `etc/queue_consumer.xml` (merge) | `{ConsumerName}`,`{QueueName}`,`{ConnectionName}`,`{Vendor}`,`{Module}` | `<consumer name queue connection handler/>` |
| `message-interface.php` | `Api/Data/{EntityName}Interface.php` | `{Vendor}`,`{Module}`,`{EntityName}` | typed getters/setters; mirror `webapi-create/templates/data-interface.php` |
| `message-model.php` | `Model/{EntityName}.php` | `{Vendor}`,`{Module}`,`{EntityName}` | DTO impl |
| `publisher.php` | `Model/{PublisherName}.php` | `{Vendor}`,`{Module}`,`{PublisherName}`,`{TopicName}` | injects `PublisherInterface`; `publish()` |
| `consumer.php` | `Model/Consumer/{ConsumerName}.php` | `{Vendor}`,`{Module}`,`{ConsumerName}`,`{MessageInterface}` | `process({MessageInterface} $msg)` → handler |
| `queue-di.xml` | `etc/di.xml` (merge) | `{Vendor}`,`{Module}`,`{EntityName}` | preference DTO interface→impl |
| `test-consumer-unit.php` | `Test/Unit/Model/Consumer/{ConsumerName}Test.php` | `{Vendor}`,`{Module}`,`{ConsumerName}` | assert decode+handle+idempotent |

**New placeholder tokens:** `{TopicName}`,`{topic_name}`,`{QueueName}`,`{ExchangeName}`,`{ConnectionName}`,`{PublisherName}`,`{MessageInterface}`. (`{ConsumerName}`,`{EntityName}` already registered.)

**Routing:** add `check message-queue  magento2-module-create`; cross-reference; routing-table row.

**Steps:** mirror Task 1 Steps 1–6; commit `feat(skills): add magento2-message-queue`.

**Acceptance:** `bin/magento queue:consumers:list` shows the consumer; topology validates; consumer unit test red→green; zero Critical/High.

---

## Task 5: `magento2-static-analysis` skill (quality-gate + auto-fix)

An **action** skill (not a generator): runs the project's static toolchain and applies safe fixes to green — the "make this pass CI" operation. Distinct from `module-review` (read-only, report-first, opportunistic tools). Reuses the shared emitters for residual findings (S4) via the new `quality` kind (S6).

**Files:**
- Create: `skills/magento2-static-analysis/SKILL.md`
- Create: `skills/magento2-static-analysis/references/tool-matrix.md`
- Create: `skills/magento2-static-analysis/references/autofix-safety.md`
- Create: `skills/magento2-static-analysis/references/ci-integration.md`
- Create: `skills/magento2-static-analysis/scripts/run-analysis.sh`
- Create: `skills/magento2-static-analysis/scripts/apply-fixes.sh`
- Create: `skills/magento2-static-analysis/scripts/build-findings.sh`
- Modify (S6): `skills/magento2-context/references/findings-schema.md` (add `quality` to `OUTPUT_KIND`)
- Modify: `tests/test-audit-builders.sh` (add a `run_builder` line)

**SKILL.md (authored content):**

- Frontmatter `description`: "Run the project's full static-analysis gate (phpcs `Magento2`, phpstan/`phpmd`, php-cs-fixer, rector dry-run) over a module or diff and **apply safe auto-fixes** to green, listing manual-only violations as ranked findings (Markdown + JSON + SARIF). Use for 'fix coding-standard violations' / 'make this pass CI'. For an architecture/quality *review without fixing* use `magento2-module-review`."
- Core rules: probe tools via `{ctx.tools}` (skip missing, never install); fixers run only after the Phase-2 gate; auto-apply only safe transforms (`phpcbf`, `php-cs-fixer`, low-risk rector sets per `autofix-safety.md`); risky rector rules are *proposed*, not applied; re-run the gate after fixing and report residual; never edit `vendor/`.
- Phases: 0 context → 1 scope (`module`/`--diff`/files) → 2 read-only tool pass + present fix plan (gate) → 3 apply safe fixes (`apply-fixes.sh`) + re-run → 4 verify (gate re-run, residual count) → 5 report.
- Phase 5 report: `.docs/quality/{Vendor}_{Module}-quality-{date}.md` + JSON/SARIF via `build-findings.sh` (`OUTPUT_KIND=quality`, `SKILL_VERSIONS_JSON=["magento2-static-analysis@1.0.0","magento2-context@<v>"]`).

**Reference inventory:** `tool-matrix.md` (NEW: which tool detects/fixes what; phpcbf↔phpcs, php-cs-fixer, rector apply vs dry-run, phpmd/phpstan report-only), `autofix-safety.md` (NEW: safe vs review-required transforms), `ci-integration.md` (NEW: exit-code gate, SARIF upload to GitHub code-scanning); DELEGATE severity/findings-schema/coding-style per S2. No templates.

**Scripts:** `run-analysis.sh` (orchestrate read-only passes → findings JSON array, mirror `security-audit/scripts/*` aggregation), `apply-fixes.sh` (run fixers, capture before/after diff stats), `build-findings.sh` (reuse emitters per S4).

**Steps:**
- [ ] **Step 1** — Author SKILL.md + 3 references + 3 scripts.
- [ ] **Step 2** — Add `quality` to `OUTPUT_KIND` in `findings-schema.md`; add `static-analysis` row to `skill-versioning.md` (`1.0.0`).
- [ ] **Step 3** — Add `run_builder magento2-static-analysis "magento2-static-analysis" "quality" "quality-module-${DATE}"` to `tests/test-audit-builders.sh`.
- [ ] **Step 4** — Update counts/section in README + docs.
- [ ] **Step 5** — Run: `bash tests/test-bash-syntax.sh && bash tests/test-audit-builders.sh && bash tests/test-emitter-schema-conformance.sh && bash tests/test-skill-count-consistency.sh && bash tests/test-version-registry-consistency.sh`. If `test-golden-emitters.sh` fails only on the new enum value, refresh with `UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh` and re-run.
- [ ] **Step 6** — Dry-run against a fixture with a deliberate phpcs violation; confirm `apply-fixes.sh` clears it and the report lists residuals.
- [ ] **Step 7** — Commit: `git commit -m "feat(skills): add magento2-static-analysis quality gate"`

**Acceptance:** running it on a violating module reduces phpcs violations to zero (auto-fixable) and emits valid JSON+SARIF with `outputKind=quality`; contract suite green.

---

## Task 6: `magento2-docs-generate` skill (module technical documentation)

Nothing today generates docs. Extracts a module's surface from its own code/XML and renders Markdown — onboarding/governance value.

**Files:**
- Create: `skills/magento2-docs-generate/SKILL.md`
- Create: `skills/magento2-docs-generate/references/surface-extraction.md`
- Create: `skills/magento2-docs-generate/references/doc-structure.md`
- Create: `skills/magento2-docs-generate/scripts/extract-surface.sh`
- Create: `skills/magento2-docs-generate/templates/readme.md`
- Create: `skills/magento2-docs-generate/templates/technical-reference.md`
- Create: `skills/magento2-docs-generate/templates/changelog-scaffold.md`

**SKILL.md (authored content):**

- Frontmatter `description`: "Generate or refresh a module's technical documentation from its own code — public `@api` surface, events fired & observed, plugins, preferences, config paths, CLI commands, cron jobs, REST/GraphQL surface, DB schema, dependencies — plus a README and CHANGELOG scaffold. Use for 'document this module' / 'generate module docs'. Read-only analysis; writes Markdown only."
- Core rules: never invent facts — every documented item is extracted from a real file (cite source path); `@api` = public contract; missing surface = omit the section, not a placeholder; output Markdown only (no code changes).
- Phases: 0 context → 1 scope (module + which docs) → 2 extract surface (`extract-surface.sh` → surface JSON) + present plan (gate) → 3 render templates with extracted facts → 4 verify (no unsubstituted tokens, internal links resolve, no empty tables) → 5 report.
- Outputs: `{module}/README.md`, `{module}/docs/technical-reference.md`, `{module}/CHANGELOG.md` (scaffold); run report `.docs/docs-generated/{Vendor}_{Module}-{date}.md`.

**Reference inventory:** `surface-extraction.md` (NEW: the grep/parse recipe per surface — `events.xml`, `di.xml` `<plugin>`/`<preference>`/`CommandList`, `system.xml`, `crontab.xml`, `webapi.xml`, `schema.graphqls`, `db_schema.xml`, `extension_attributes.xml`, `\\@api` tags, `dispatch(` calls), `doc-structure.md` (NEW: section order); DELEGATE naming/placeholder per S2.

**Template inventory (Markdown — not lint-tested, but tokens ARE registry-checked):**

| Template | → Output | Tokens |
|---|---|---|
| `readme.md` | `{module}/README.md` | `{Vendor}`,`{Module}`,`{MODULE_DESCRIPTION}`,`{DEPENDENCIES_LIST}` |
| `technical-reference.md` | `{module}/docs/technical-reference.md` | `{API_SURFACE_TABLE}`,`{EVENTS_TABLE}`,`{PLUGINS_TABLE}`,`{CONFIG_PATHS_TABLE}`,`{CLI_COMMANDS_TABLE}`,`{CRON_TABLE}`,`{REST_ROUTES_TABLE}`,`{GRAPHQL_TABLE}`,`{DB_SCHEMA_TABLE}` |
| `changelog-scaffold.md` | `{module}/CHANGELOG.md` | `{Vendor}`,`{Module}`,`{date}` |

**New placeholder tokens (UPPER_CASE report markers, mirror existing `{CHECKLIST_TABLE}`):** `{MODULE_DESCRIPTION}`,`{DEPENDENCIES_LIST}`,`{API_SURFACE_TABLE}`,`{EVENTS_TABLE}`,`{PLUGINS_TABLE}`,`{CONFIG_PATHS_TABLE}`,`{CLI_COMMANDS_TABLE}`,`{CRON_TABLE}`,`{REST_ROUTES_TABLE}`,`{GRAPHQL_TABLE}`,`{DB_SCHEMA_TABLE}`. (`{date}` registered.)

**Routing:** no discriminator needed (no close sibling); add a plain row to the routing table noting docs-generate ≠ module-review (docs vs quality).

**Steps:** author → register tokens + version row → docs/count → run `bash tests/test-bash-syntax.sh && bash tests/test-placeholder-tokens.sh && bash tests/test-reference-integrity.sh && bash tests/test-skill-count-consistency.sh && bash tests/test-version-registry-consistency.sh` (PASS) → dry-run against `magento2-eav-attribute` itself and eyeball the technical reference → commit `feat(skills): add magento2-docs-generate`.

**Acceptance:** generated technical reference lists the module's real events/plugins/config/commands with source paths; no unsubstituted tokens; contract suite green.

---

## Task 7: `magento2-explorer` agent (read-only code comprehension)

Second first-party agent, complementing `magento2-reviewer`. Produces a *comprehension map* (architecture, data flow, extension points, dependencies, Mermaid call chain) of an existing module/feature — distinct from the reviewer (which judges quality) and generic `Explore` (which only locates files).

**Files:**
- Create: `agents/magento2-explorer.md`
- Modify: `skills/magento2-module-review/references/parallel-review.md` (offer explorer for the inventory step)
- Modify: `skills/magento2-feature-implement/references/task-breakdown-guide.md` (note: before `X` modify-existing tasks, dispatch explorer)
- Modify: `skills/magento2-bug-fix/` RCA reference (note: dispatch explorer to map the suspect path)

**Agent file (authored content):**

- Frontmatter: `name: magento2-explorer`; `tools: Glob, Grep, Read, Bash` (read-only — must NOT include Write/Edit/NotebookEdit, per `test-agent-routing.sh`); `description` (mirror `magento2-reviewer.md` shape): "Read-only comprehension of an existing Magento 2 module or feature — maps execution paths, the DI/plugin/observer/preference extension points in play, service-contract and cross-module dependencies, and produces a Mermaid call chain. Use before modifying unfamiliar code, during bug-fix RCA, or as the inventory step of a parallel review. Returns a structured comprehension map (not findings, not fixes); never modifies code. Examples — 'map how Acme_Checkout builds the totals'; 'trace what runs when sales_order_place_after fires in Acme_Loyalty'."
- Body sections (mirror reviewer's structure): inputs expected in brief (module path + question scope; self-contained, no parent context); authoritative references to load (`${CLAUDE_PLUGIN_ROOT}/skills/magento2-context/references/naming.md`); how it works (resolve layout → enumerate the relevant surface → trace via Grep/Read → assemble a call chain); **output** = a comprehension map: entry points, data flow, extension points present, dependencies, Mermaid `flowchart`, open questions. Read-only; cites `file:line`.

**Wiring (authored content):** in `parallel-review.md`, add to the Agent guidance: "For the *inventory/comprehension* step prefer `subagent_type: 'magento2-explorer'` (falls back to `'Explore'`, then `'claude'`)." In feature-implement/bug-fix references, add a one-line "dispatch `magento2-explorer` to map the target before editing" note.

**Steps:**
- [ ] **Step 1** — Author `agents/magento2-explorer.md` (read-only tools).
- [ ] **Step 2** — Add the wiring lines to the three reference docs.
- [ ] **Step 3** — Run: `bash tests/test-agent-routing.sh && bash tests/test-reference-integrity.sh` — Expected: PASS (frontmatter closed, no write tools, refs resolve).
- [ ] **Step 4** — Update `README.md` agents/Layout section to enumerate two agents (reviewer + explorer).
- [ ] **Step 5** — Commit: `git commit -m "feat(agents): add read-only magento2-explorer comprehension agent"`

**Acceptance:** `test-agent-routing.sh` passes; module-review's parallel path can dispatch explorer for inventory and falls back cleanly when absent.

---

## Task 8 (Wave 1 close): integration, version bump, release

**Files:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `skills/magento2-feature-implement/SKILL.md` + task guide, `skills/magento2-context/references/skill-versioning.md`.

**Steps:**
- [ ] **Step 1** — Wire the four new generator skills into `feature-implement`: add task-type rows `I`/`C`/`L`/`Q` to `task-breakdown-guide.md` and the matching routing branches in `feature-implement/SKILL.md`; note `V` (Validate) may delegate to `magento2-static-analysis` when present. Bump `magento2-feature-implement` (minor) in `skill-versioning.md`.
- [ ] **Step 2** — Confirm `skill-versioning.md` lists all six new skills (each `1.0.0`).
- [ ] **Step 3** — Bump `plugin.json` + `marketplace.json` to the next **minor** (e.g. `1.11.0`) — they must match; add a dated `## [1.11.0]` CHANGELOG section enumerating the six skills + agent.
- [ ] **Step 4** — Run the full suite: `bash tests/run-all.sh` — Expected: all PASS / SKIP (0 FAIL); `shellcheck` clean in CI.
- [ ] **Step 5** — Commit `Release v1.11.0 — extension-point, system-config, cli-command, message-queue, static-analysis, docs-generate skills + explorer agent`, then push an annotated `v1.11.0` tag (manual, per repo policy).

**Acceptance:** `tests/run-all.sh` green; `test-skill-count-consistency.sh` reflects 26 skills; `test-plugin-marketplace-sync.sh` + `test-release-notes.sh` pass.

---

# WAVE 2

## Task 9: command-surface completion + `/magento2-tools:scaffold` dispatcher

Today 9 commands exist for 20 skills (now 26). Rather than 17 one-off shortcuts (noise), add the few high-frequency shortcuts plus one discovery dispatcher (DRY).

**Files:**
- Create: `commands/test.md` → `magento2-test-generate`
- Create: `commands/upgrade.md` → `magento2-module-upgrade`
- Create: `commands/i18n.md` → `magento2-i18n`
- Create: `commands/lint.md` → `magento2-static-analysis`
- Create: `commands/scaffold.md` → dispatcher (nominal target `magento2-module-create`)
- Modify: `tests/test-command-routing.sh` (`EXPECTED` list), `README.md` Commands table + count.

**Command formats (authored content):**

- Read-only shortcuts (`test`, `upgrade`, `i18n`, `lint`) follow the `context.md` shape: `description` (with sibling cross-ref where adjacent), `argument-hint`, body `Use the magento2-tools:magento2-<skill> skill, forwarding these arguments verbatim: $ARGUMENTS`. `upgrade` and `lint` mutate code → set `disable-model-invocation: true`; `test`/`i18n` are read-mostly → omit it (match how existing read commands are gated).
- `scaffold.md`: `description` "Entry point for Magento 2 code generation — routes to the right generator skill (module, extension-point, system-config, cli-command, message-queue, eav-attribute, graphql, webapi, frontend, adminhtml-form/listing) based on what you ask for." Body lists the routing map and forwards `$ARGUMENTS`. Because `test-command-routing.sh` enforces a `verb:single-skill` 1:1 map, set the dispatcher's nominal target to `magento2-module-create` and **update `test-command-routing.sh`** to record `scaffold:magento2-module-create` (with an inline comment that it is a dispatcher).

**Steps:**
- [ ] **Step 1** — Author the five command files.
- [ ] **Step 2** — Add the five `verb:skill` entries to `EXPECTED` in `tests/test-command-routing.sh`.
- [ ] **Step 3** — Update README Commands table + command count (9 → 14) + counts test docs as needed.
- [ ] **Step 4** — Run: `bash tests/test-command-routing.sh && bash tests/test-skill-count-consistency.sh` — Expected: PASS.
- [ ] **Step 5** — Commit: `git commit -m "feat(commands): add test/upgrade/i18n/lint shortcuts + scaffold dispatcher"`

**Acceptance:** all 14 commands route to a real skill; write commands gated; dispatcher documented.

---

## Deferred charters (Wave 2, charter depth — flesh out before building)

### Task 10 — `magento2-indexer` (custom indexer + mview)
**Why deferred:** narrower audience (custom indexers are occasional). **Scope:** `indexer.xml`, `mview.xml`, an `Indexer` implementing `ActionInterface` (`executeFull`/`executeList`/`executeRow`), optional dimension support, partial-reindex strategy. **Reuse:** generator skeleton (S1); `performance-audit` already reviews indexers (cross-link). **Routing:** vs `data-migration` (one-off data) and `performance-audit` (review). **Est.** ~12 files. Charter to expand: dimension modes, shared-index pitfalls, `indexer:reindex`/`mview` runtime notes.

### Task 11 — `magento2-marketplace-prep` (Adobe Marketplace / EQP submission)
**Why deferred:** extension-vendor niche. **Scope:** composer-metadata completeness, copyright/license headers, MFTF presence, version-constraint sanity, EQP/MEQP static rules, packaging checklist → a readiness report (Markdown + JSON via shared emitters). **Reuse:** `security-audit` already runs EQP static rules — **delegate, don't duplicate**; this skill orchestrates + scores submission readiness on top. **Routing:** vs `security-audit` (depth) and `release` (publishing). **Est.** ~8 files. Charter to expand: the EQP rule subset, the readiness scoring rubric.

### Task 12 — `magento2-accessibility-audit` (storefront WCAG/a11y)
**Why deferred:** user deprioritized ops/runtime; needs template+optional-runtime. **Scope:** static template analysis (ARIA, semantic HTML, alt text, label/for, heading order, LESS contrast heuristics) + optional runtime via `pa11y` (already in the `tool-probe` list) or the Playwright/Chrome-DevTools MCP. Findings via shared emitters with a new `OUTPUT_KIND=accessibility` (same mechanism as Task 5's `quality`). **Routing:** vs `frontend-create` (build) and `module-review` (general quality). **Est.** ~10 files. Charter to expand: the WCAG rule set, theme-aware (Luma/Hyvä) template discovery, runtime-vs-static gating.

---

## Self-review (run against the slate)

- **Spec coverage:** all 8 approved slate items have a task (1–7 Wave 1, 8 Wave 2) + the three deferred items charter'd (10–12); Wave-1 close (Task 8) handles cross-cutting registration/release. ✓
- **Placeholder scan:** no "TBD"/"add error handling"/"write tests for the above" — every template entry has an exact output path, token list, and spec or named analogue; every reference is marked NEW or DELEGATE; every step has an exact command + expected result. ✓
- **Type/name consistency:** task-type prefixes `I/C/L/Q` are unique vs existing `M/X/E/G/F/T/R/V/D/S/P`; new `OUTPUT_KIND` values `quality` (Task 5) and `accessibility` (Task 12) are namespaced consistently; placeholder tokens flagged new vs already-registered against the audited `placeholder-schema.md`. ✓
- **DRY/KISS:** zero re-implementation of context resolution, findings emission, naming, severity, or TDD — all delegated to `magento2-context/references/*` and the shared emitters; the plan body itself centralizes conventions in §S1–S6 instead of repeating them per task; one multi-mode skill each for the plugin/observer/preference and command/cron families rather than separate skills. ✓
