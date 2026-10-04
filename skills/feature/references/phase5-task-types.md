# Phase 5 — Execution Detail and Task Types

Part of the `feature` skill — read at Phase 5 start (the Per-task completion protocol stays in SKILL.md).

## Environment context (resolve once, before Phase 5 tool steps)

**Invoke the `context` skill** — it is the single source of truth for `{ctx.vendor}`,
`{ctx.runner}`, `{ctx.magento_cli}`, `{ctx.composer}`, `{ctx.tools.*}`, edition, versions, and
the active theme. Do **not** hand-roll a runner/tool probe here (that duplicated the hub and
drifted from it — FI-3). The same applies to the Phase 1 vendor lookup: prefer `{ctx.vendor}`,
falling back to a `CLAUDE.md` `Vendor prefix:` line or an explicit user question only when the
hub reports it as null.

Consume the resolved values directly:

- `{runner}` = `{ctx.runner}` (empty string in bare-PHP mode — `${runner} php …` still works).
- `{magento}` = `{ctx.magento_cli}` (null ⇒ offer the commands as manual "next steps").
- Tool availability = `{ctx.tools.phpcs}`, `{ctx.tools.phpstan}`, `{ctx.tools.phpunit}`, etc.
  (each is the resolved path or null — skip and report the ones that are null).

All subsequent tool invocations in Phase 5 and Phase 6 use these `{ctx.*}` values. Never
hardcode a specific runner — fall back gracefully and report what was skipped.

---

Work through the approved task list in dependency order. For tasks marked `Parallel: yes` in the
task list, concurrent execution via sub-agents is permitted subject to the rules in
`references/task-breakdown-guide.md` (Parallel Execution section) — those rules are the authority
and stand alone. Optionally, if a generic parallel-dispatch process skill is present in the session
(e.g. `superpowers:dispatching-parallel-agents`), you may prefer its isolation / shared-state
mechanics on top of them; if absent, the guide's section is complete on its own. See
`context/references/process-skills.md` for when deferring to a generic process skill is
sanctioned — and the surfaces where it is not. For each task:

## Fallback discipline (applies to every delegating task below)

Each task type below names the sub-skill it delegates to. Per the **Delegate by probing** Core
Rule, attempt that invocation first and fall back to inline **only** when the `Skill` call actually
fails. When a fallback is genuinely required:

1. **Keep the task's type prefix.** A task is typed by the *work* — admin config = `C`, extension
   point = `I`, CLI/cron = `L`, queue = `Q`, EAV = `E`, GraphQL = `G`, tests = `T`, validate = `V`,
   deploy = `D` — not by which skill happened to run. Never relabel a `C`/`I`/`L`/`Q`/`E`/`G` task
   to `X` because its generator was unavailable; that hides the work from type-based routing.
2. **Generate inline from the same `references/` the skill uses**, to the same quality bar — e.g.
   `system-config`'s field + config-reader patterns for a `C` task — not a thinner stub.
3. **Record the concrete reason** on the task's `Skill:` line (e.g. "`system-config` —
   not Skill-invocable: tool returned no such skill"), never a speculative "if Skill-invocable"
   hedge.

`T*`, `V*`, and `D*` restate their specific fallback below — and `D*` is the one type that never
runs inline. `C*`/`I*`/`L*`/`Q*`/`E*`/`G*` have no separate inline generator: you author the same
output the skill would have produced, keeping the type.

## New module tasks (M*)

1. Invoke the `module-create` skill with the module name and surfaces.
2. After creation, immediately invoke the `review` skill (the corresponding R* task).
3. Fix all Critical and High findings before starting the next task.
4. Document Medium findings — they will appear in the final report.
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

**TDD mode (on):** for each behaviour-bearing class the module adds (`Service`, `Model` with
logic, `Plugin`, `Observer`, `Console/Command`, `Resolver`, data-patch transforms), scaffold the
**signature** first (interface + a body that throws `not implemented`), write the failing test
from the task's acceptance criteria, **watch it fail for the right reason**, then fill the minimal
body to green before review. Pure scaffold/config (registration, DI, module.xml, plain DTOs,
db_schema) is exempt. Follow `references/tdd-mode.md` and the loop in
`context/references/tdd-discipline.md`.

## Existing module tasks (X*)

1. Identify the exact files to add or modify.
   Before editing unfamiliar code you may dispatch `explorer` to map its execution
   paths and extension points first (per `references/task-breakdown-guide.md` type table). When
   you do, pass `model` from the `CLAUDE.md` directive `Explorer model: {tier}` if set, otherwise
   `haiku` (the explorer's frontmatter default).
2. Apply changes following all rules in `CLAUDE.md` and `module-create/references/`.
   **TDD mode (on):** if the change adds behaviour (not pure config/scaffold), write the failing
   test first and watch it fail for the right reason before applying the production change, per
   `references/tdd-mode.md` and `context/references/tdd-discipline.md`.
3. Run `php -l` on every modified PHP file and `xmllint --noout` on every modified XML file.
   These tools operate on local files and do not require a runner.
4. Invoke the corresponding review task (R*).
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Review tasks (R*)

1. Invoke `review` on the target module (`--diff` mode after the first pass keeps
   the review focused on what changed):

   ```
   Skill: review
   Args: --docs-root=.docs/{FeatureName} --diff {Vendor}_{Module}
   ```

2. Fix all Critical and High findings in the same task — do not defer.
3. Log Medium findings to the final report.
4. Mark the R* task complete only when all Critical/High findings are resolved.
5. → run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Test tasks (T*)

Delegate to `test-generate` when available; fall back to inline generation otherwise.

```
Skill: test-generate
Args: --types=unit --missing-only --docs-root=.docs/{FeatureName} {Vendor}_{Module}
```

`test-generate` discovers untested classes, writes tests with real assertions, and
runs `php -l` per generated file. The T* task completes when the generator reports done.

**TDD mode (on):** the behaviour tests were already written test-first inside their `M*`/`X*`
tasks. Here the T* task **verifies** the suite is green and uses `test-generate` only to
**top up** coverage on exempt/boilerplate classes — it does not author the behaviour's first test.
Do not regenerate or overwrite the test-first tests.

Inline fallback (when the skill is absent):

1. Write unit tests for every `Api/`, `Service/`, and `Model/` class added or modified in the
   target module. Do not create empty test stubs — every test must contain real assertions.
2. Run `php -l` on all new test files.
3. Do **not** run PHPUnit here — test execution and coverage measurement are handled in Phase 6.
4. Mark the T* task complete when test files exist, contain real test logic, and pass `php -l`.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled) —
whether the T* task was delegated to `test-generate` or done inline.

## EAV attribute tasks (E*)

When the blueprint declares EAV attributes, generate an E* task per attribute and delegate
to `eav-attribute`:

```
Skill: eav-attribute
Args: --entity=product --code={code} --label="{Label}" --type={input_type} --module={Vendor}_{Module} --docs-root=.docs/{FeatureName}
```

The skill produces the `Setup/Patch/Data/Add{Code}Attribute.php` patch, companion models
when needed, and a brief report. After E* completes, an R* review task runs on the
affected module.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## GraphQL surface tasks (G*)

When the blueprint declares a GraphQL surface with non-trivial design (batch loaders, auth,
schema migration), generate a G* task per resolver group and delegate to `graphql`:

```
Skill: graphql
Args: --module={Vendor}_{Module} --operation={query|mutation} --auth={customer|admin|anonymous} --docs-root=.docs/{FeatureName}
```

The skill produces schema, resolver, batch loader (if applicable), DI, and unit tests.
Simple GraphQL surfaces continue to use `module-create`'s graphql templates.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Extension point tasks (I*)

When the blueprint wires an extension point (plugin, observer, or preference) onto existing code,
generate an I* task and delegate to `extension-point`:

```
Skill: extension-point
Args: --module={Vendor}_{Module} --mode={plugin|observer|preference} --docs-root=.docs/{FeatureName}
```

The skill produces the interception class, `di.xml` wiring, and a unit test.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## System configuration tasks (C*)

When the blueprint requires admin store configuration (system.xml fields + typed config reader),
generate a C* task and delegate to `system-config`:

```
Skill: system-config
Args: --module={Vendor}_{Module} --docs-root=.docs/{FeatureName}
```

The skill produces `system.xml`, `config.xml`, `acl.xml`, and a typed config reader class.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## CLI command / cron tasks (L*)

When the blueprint adds a CLI command or cron job, generate an L* task and delegate to
`cli-command`:

```
Skill: cli-command
Args: --module={Vendor}_{Module} --mode={command|cron} --docs-root=.docs/{FeatureName}
```

The skill produces the command class, `di.xml` registration, and (for cron) `crontab.xml`.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Message-queue tasks (Q*)

When the blueprint adds an async message-queue surface, generate a Q* task and delegate to
`message-queue`:

```
Skill: message-queue
Args: --module={Vendor}_{Module} --topic={topic.name} --docs-root=.docs/{FeatureName}
```

The skill produces the topic DTO, publisher, consumer, and all five queue XML files
(`communication.xml`, `queue_topology.xml`, `queue_publisher.xml`, `queue_consumer.xml`,
`di.xml`).

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Validate task (V*)

When `lint` is present, delegate the quality gate to it — it runs PHPCS
(Magento2 standard), PHPStan, PHPMD, and optional php-cs-fixer/rector in a single pass and
emits ranked findings via the shared emitters:

```
Skill: lint
Args: --module={Vendor}_{Module} --docs-root=.docs/{FeatureName}
```

When `lint` is absent, run each check inline with the probed `{runner}`.
Skip and report any tool that is unavailable.

```bash
# Code style
{runner} vendor/bin/phpcs --standard=Magento2 app/code/{Vendor}/{ModuleName}

# Mess detection
{runner} vendor/bin/phpmd app/code/{Vendor}/{ModuleName} text phpmd.xml

# Static analysis
{runner} vendor/bin/phpstan analyse --level=8 app/code/{Vendor}/{ModuleName}

# Unit tests
{runner} vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist app/code/{Vendor}/{ModuleName}/Test/Unit
```

The validate task is complete only when PHPCS, PHPMD, PHPStan level 8, and PHPUnit all pass for
every new and modified module. Record which tools were skipped due to unavailability — these are
environment limitations, not failures.

→ run the **Per-task completion protocol** (mark `[x]` in `plan.md`, save, commit if enabled).

## Deploy task (D*)

Delegate to `deploy`. Invoke via the `Skill` tool with the module list and the
user's environment selection (default: `local`). This skill does not run `bin/magento`
commands inline — `deploy` owns the pre-flight, plan, execute, smoke, and
rollback steps.

```
Skill: deploy
Args: --env=local --docs-root=.docs/{FeatureName} {Vendor}_{ModuleA} {Vendor}_{ModuleB}
```

Per-task commit (when enabled): D* tasks make no commit (no files change). Record the
deploy report path returned by `deploy` in `plan.md` next to the D* task.

→ run the **Per-task completion protocol** to mark `[x]` in `plan.md` (no commit for D*).

If `deploy` is unavailable, state the unavailability explicitly and offer the
equivalent commands as manual next steps for the user to run themselves:
`{magento} module:enable {modules}` → `{magento} setup:upgrade` →
`{magento} setup:di:compile` (prod) → `{magento} setup:static-content:deploy -f` (prod) →
`{magento} cache:flush`. Ask the user to install `deploy` before re-running.
