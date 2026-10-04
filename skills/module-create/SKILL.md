---
name: module-create
version: 1.10.3
description: >-
  Create a new Magento 2 module under the project's vendor namespace. Use when asked to create,
  scaffold, generate, or build a Magento 2 module, extension, component, or package. Generated files
  pass all 12 magento2-tools:review categories. Surface-driven: creates only files for declared
  surfaces. Works without a running Magento instance or Docker. For a standalone admin form use
  magento2-tools:admin-form, a GraphQL surface magento2-tools:graphql, or one EAV attribute
  magento2-tools:eav-attribute.
---

# Magento 2 Module Create

Create Magento 2 modules surface-by-surface. Every file generated must pass the `review`
checklist with zero post-creation fixes required.

## Core Rules

- **Resolve context first.** Invoke the `context` skill at the start of Step 1 and use its
  resolved values for `{Vendor}`, `{runner}`, `{magento_cli}`, `{php_constraint}`, and
  `{framework_constraint}`. Do not re-resolve these independently.
- **Never guess.** If module name, purpose, or surfaces are ambiguous, ask before generating any files.
- **Surface-driven.** Create only files required by explicitly declared surfaces. Do not create empty
  placeholder directories or stub files for undeclared surfaces.
- **Use a template for every file.** Every file type listed in `references/surfaces.md` maps to a
  template under `templates/`. Do not invent file content from prose rules when a template exists.
- **Compliance-first.** Every generated file satisfies all applicable review categories on creation.
  No compliance TODOs remain after the skill completes.
- **Script-then-fill.** Use `${CLAUDE_SKILL_DIR}/scripts/create-dirs.sh` for directory structure; use `templates/` as
  the
  base for each file type; use AI to fill in module-specific implementation content.
- **Verify before done.** Run available static tools after generation. Do not mark creation complete if
  any PHP file fails `php -l` or any XML file fails `xmllint`.
- **Generate surfaces in order.** When surfaces are independent, follow:
  `core` → `persistence` → `service_contracts` → `admin_config` → `admin_ui` → `frontend_ui`
  → `rest_api` → `graphql` → `cron` → `queue` → `extensions`.
- **Document before report (required).** Step 6 generates the module's documentation set; Step 7
  (report) may not start until it exists on disk and is current. The set is **code-derived** (this
  skill assumes no running instance) and is **delegated in full to `docs`**: README,
  CHANGELOG, technical reference, developer guide (when a public surface exists), and user guide
  (when a UI/config surface exists, with screenshots or named placeholders when no instance is
  available). This skill does not hand-write any of those. When a REST/GraphQL surface is declared,
  this skill separately writes request/response payload examples, plus other helpful artifacts as the
  surfaces warrant. Reduced in Quick Create Mode; refresh-only in `--mode=augment`. The delegation,
  per-mode scope, and completeness gate live in `references/documentation-guide.md`.
- **Source of truth.** Generate from templates → shared references → baked-in Magento 2 knowledge
  → official Magento/Adobe docs (live-fetched only when uncertain). Do NOT read, grep, or "study"
  other modules under `app/code`/`vendor/*`/Magento core to infer conventions, entity shapes,
  naming, or wiring. Narrow exceptions: the target module/class of this operation, and the specific
  contract of a module this code explicitly depends on. Affirm sources in the final report. See
  `context/references/source-of-truth.md`.
- **After a context compaction,** re-read the reference for the phase in progress before continuing.

## Workflow

1. **Resolve module identity and load project context.**
    - Read `$ARGUMENTS`. If empty: ask *"What is the module name (PascalCase, e.g. `OrderExport`) and
      which surfaces does it need?"* and wait.
    - Validate module name: PascalCase, letters only, 2–50 characters. Reject anything else.
    - **Invoke `context`** via the `Skill` tool (or run
      `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/resolve-context.sh`). Capture the JSON as `{ctx}`.
      Use `{ctx.vendor}` for `{Vendor}`, `{ctx.php_constraint}` for the composer.json `php` value,
      `{ctx.framework_constraint}` for `magento/framework`, and `{ctx.runner}`/`{ctx.magento_cli}`
      for any tool invocations. If `{ctx.vendor}` is null, ask the user for the vendor prefix.
      If `{ctx.php_constraint}` is null and the project has no `src/composer.json`, ask the user.
    - Set `{module_lower}` = ModuleName converted to snake_case (see
      `context/references/naming.md`).
    - Resolve the target path: `{ctx.module_dir}/{Vendor}/{ModuleName}`
      (typically `{ctx.magento_root}/app/code/{Vendor}/{ModuleName}`). Abort if the directory already exists
      unless `--mode=augment` is set.
    - Map the user's description to surfaces using `references/surfaces.md`.
    - Present a **module profile** — vendor, name, path, surfaces, estimated file count — and confirm
      before proceeding for multi-surface modules. Single-surface requests may proceed without
      confirmation.

2. **Build creation plan.**
    - For each declared surface, list the exact files to create using `references/surfaces.md`.
    - Shared files created regardless of surfaces: `registration.php`, `etc/module.xml`, `composer.json`,
      `etc/di.xml`, `README.md`, `CHANGELOG.md`, `LICENSE.txt`, `.gitignore`.
    - `README.md` starts as a **minimal stub** — just `# {ModuleName}` and one sentence describing what
      the module does — so later steps have a file to reference. Do not hand-write Features,
      Installation, Configuration, Public API, or other sections here: Step 6 overwrites the stub with
      the full generated README via `docs`.
    - Auto-add `i18n/en_US.csv` when any UI surface (`admin_ui`, `frontend_ui`) is declared.
    - Auto-add a minimal MFTF smoke test under `Test/Mftf/` (`templates/mftf-test.xml`, plus
      `templates/mftf-actiongroup.xml` for UI surfaces) when any UI surface (`admin_ui`, `frontend_ui`)
      is declared — Marketplace weighs functional coverage alongside the unit tests.
    - Auto-add `Test/Unit/` for all non-vendor modules.
    - Gather open questions about entity names, service method signatures, or config paths.
      Ask them all at once — do not interrupt mid-generation.
    - For modules with ≥ 3 surfaces or ≥ 20 estimated PHP files: present the full plan and ask for
      confirmation before generating.

3. **Create directory structure.**
    - Run `${CLAUDE_SKILL_DIR}/scripts/create-dirs.sh {Vendor} {ModuleName} {surface...}` from the workspace root (prints a one-line summary;
      `VERBOSE=1` adds the per-surface lines and directory tree).
      Resolve `{Vendor}` from `context.vendor` and export `MODULE_DIR` from
      `context.module_dir` so the script writes to the correct path (it auto-detects
      `src/app/code` vs `app/code` if `MODULE_DIR` is not set).
    - Verify exit code 0 before proceeding.
    - If the script is unavailable: use the `Bash` tool with `mkdir -p` for each surface's directory
      list from `references/surfaces.md`. Report unavailability; do not abort.

4. **Generate implementation files.**

    - Work surface by surface in the order from the "Generate surfaces in order" Core Rule, using `templates/` as the base for every file. Apply
      `references/naming-conventions.md` and `references/composer-metadata.md`; PHPDoc on every public method.
    - No `ObjectManager::getInstance()`, no `echo`/`print`/`die()`/`exit()`/`var_dump()`/`eval()`/`@`; do not hand-write the copyright header (Step 5 stamps it).
    - **Read `references/workflow-surfaces.md` before starting this step.**

5. **Verify compliance.**
    - **Stamp copyright headers (required, run first).** After all files are generated, run
      `${CLAUDE_PLUGIN_ROOT}/skills/context/scripts/add-license-headers.sh {module_path} {Vendor}`.
      It prepends the
      standard header (pointing at `LICENSE.txt`) to every `.php` file, idempotently — safe to re-run in
      `--mode=augment`. If the script is unavailable, prepend the block by hand to each PHP file:
      ```php
      <?php
      /**
       * Copyright © {Vendor}. All rights reserved.
       * See LICENSE.txt for license details.
       */
      ```
    - Run `php -l` on every generated PHP file. Fix syntax errors before proceeding.
    - Run `xmllint --noout` on every generated XML file. Fix well-formedness errors before proceeding.
    - Run `composer validate --no-check-publish` on the generated `composer.json`.
    - **Run the creation gate:** `${CLAUDE_SKILL_DIR}/scripts/verify-created.sh {module_path}`. It checks
      the required files (incl. `LICENSE.txt`), composer metadata (no wildcard constraints, `authors`),
      and the copyright header on every PHP file. Treat any ✗ as blocking — fix and re-run before Step 6.
      Output is quiet by default (every ⚠/✗ + a tally); `VERBOSE=1` adds the per-check ✓ lines.
    - Run available quality tools opportunistically (phpcs, phpstan) using the same probing approach as
      `review`. Unavailable tools are reported, not treated as failures.
    - Do NOT run `bin/magento setup:di:compile`, `setup:upgrade`, or
      `setup:db-declaration:generate-whitelist` automatically — offer them as next steps.
    - Record all results: pass / fail / skipped per check.

6. **Generate documentation (required).**
    - Load `references/documentation-guide.md`. It defines the delegation, the per-mode scope,
      screenshot handling, API payload examples, and the completeness gate.
    - Delegate the **full module doc set** to `docs` for the created module:
      ```
      Skill: docs
      Args: --module={Vendor}_{ModuleName}
      ```
      This single call (re)generates `README.md` (overwriting the Step 2 stub), `CHANGELOG.md`,
      `docs/technical-reference.md`, `docs/developer-guide.md` (when the module exposes a public
      surface — service contracts, REST/GraphQL, events, plugins), and `docs/user-guide.md` (when
      `admin_config`, `admin_ui`, or `frontend_ui` is declared, including screenshot placeholders when
      no running instance is available) — all straight from the module's own code. This skill does not
      hand-write any of these; `docs` owns their section structure, per-surface
      omission rules, and content derivation (see its `references/doc-structure.md`).
    - When `rest_api` or `graphql` is declared, write contract-derived request/response payload
      examples under `docs/api-examples/` and reference them from the developer guide.
    - Add other helpful artifacts (Postman collection, ER/sequence diagram) under `docs/artifacts/`
      as the surfaces warrant. Omit those that do not apply — no empty placeholder files.
    - **Quick Create Mode:** the delegation call above naturally produces `README.md`,
      `CHANGELOG.md`, and `docs/technical-reference.md` when no other surfaces are declared —
      `docs` always emits the technical reference, even for a surface-less
      module. **`--mode=augment`:** re-run the delegation so every doc reflects the augmented
      surfaces — never leave a doc describing the pre-augment module.
    - Run the completeness checklist in `references/documentation-guide.md`. Do not proceed to Step 7
      until every required artifact for the current mode exists on disk.

7. **Report and offer next steps.**
    - Show the created file tree (all files, relative to module root).
    - Show the creation checklist status from `references/creation-checklist.md`
      (all 12 categories, each marked ✓ compliant / ⚠ partial / ✗ gap).
    - Show verification results.
    - Offer next steps in priority order:
        1. Fill in implementation TODOs (list specific files and what to add).
        2. When persistence surface declared — generate schema whitelist:
           `docker compose exec -u magento php bin/magento setup:db-declaration:generate-whitelist
           --module-name={Vendor}_{ModuleName}`
        3. Run the `deploy` skill to enable and deploy.
        4. Run the `review` skill on `{Vendor}/{ModuleName}` to confirm the
           full quality gate (PHPCS, PHPStan, PHPUnit) and all 12 review categories pass.
        5. **Marketplace preflight (when the module is bound for Adobe Marketplace/EQP):** run the
           `marketplace` skill (or its read-only
           `${CLAUDE_PLUGIN_ROOT}/skills/marketplace/scripts/check-readiness.sh {module_path}`)
           for a readiness verdict before packaging/`release`. The Step 5 gate already covers the
           common blockers (LICENSE, bounded constraints, headers, `authors`).

## Quick Create Mode

Triggered when the user includes: `quick`, `minimal`, `skeleton`, `bare`, or `scaffold only`.

Creates only the **core** surface files:
`registration.php`, `etc/module.xml`, `composer.json`, `etc/di.xml`, `README.md`, `CHANGELOG.md`,
`LICENSE.txt`, `.gitignore`. The copyright-header stamp (Step 5) still runs.

Does not create interfaces, models, controllers, templates, or tests. All files must still fully comply
with Categories 1, 2, and 3 of the review checklist.

Documentation (Step 6) is reduced to `README.md` + `CHANGELOG.md` + `docs/technical-reference.md`
(what `docs` always produces for a surface-less module) — the rest of the full
doc set (developer/user guides, API examples) is generated when surfaces are added.

After creation, list all skipped surfaces and state:
*"Run `/module-create {ModuleName} {surface}` to add a surface when ready."*

## Surface-to-File Mapping

Load `references/surfaces.md` when building the creation plan. Do not assume surface contents from memory.

| Surface             | Common trigger phrases                                                   |
|---------------------|--------------------------------------------------------------------------|
| `core`              | Always included                                                          |
| `persistence`       | database, table, entity, model, resource model, CRUD, schema, store data |
| `service_contracts` | service, contract, repository, API interface, business logic             |
| `admin_config`      | configuration, settings, system.xml, admin config, store settings        |
| `admin_ui`          | admin grid, admin form, admin panel, backend, adminhtml                  |
| `frontend_ui`       | storefront, frontend, customer-facing, block, template, page             |
| `rest_api`          | REST, web API, endpoint, webapi.xml                                      |
| `graphql`           | GraphQL, resolver, query, mutation                                       |
| `cron`              | cron, scheduled task, recurring job                                      |
| `queue`             | message queue, consumer, async, RabbitMQ                                 |

When the user's description is ambiguous, ask about surfaces explicitly before building the plan.

## Optional Parallel Create

Parallel agent creation requires explicit user authorization. When a module meets the threshold
criteria in `references/parallel-create.md` (≥ 4 surfaces or ≥ 30 estimated PHP files), offer
parallel creation to the user and wait for a yes/no answer before proceeding. Read
`references/parallel-create.md` before spawning agents.

## Reference Files

- `references/surfaces.md`: surface-to-file mapping, **per-file template references**, directory lists,
  and cross-surface integration rules.
- `references/creation-checklist.md`: per-category creation requirements mapping all 12 review categories
  to concrete generation rules.
- `references/naming-conventions.md`: legacy local naming reference — pointer to the shared
  `context/references/naming.md` (authoritative).
- `references/composer-metadata.md`: `composer.json` constraints, autoload format, and metadata rules.
- `references/phpdoc-rules.md`: full PHPDoc generation rules for all class types — scope, format,
  FQCN requirements, brevity rules, and common mistakes to avoid.
- `references/parallel-create.md`: agent split guidance for large or complex modules.
- `references/docs-format.md`: pointer to `docs`'s templates and
  `references/doc-structure.md` — this skill does not define its own README/CHANGELOG format.
- `references/documentation-guide.md`: Step 6 delegation to `docs` for the full doc
  set, screenshot handling, contract-derived API examples, per-mode scope, and the completeness gate.
- `references/workflow-surfaces.md`: Step 4 detail — per-file PHP/XML/phtml/controller generation rules.
- `references/template-inventory.md`: per-surface list of the `templates/` files.
- `context/references/source-of-truth.md` — source-of-truth hierarchy + the
  no-unrelated-module-scanning rule (allowed reads, live-doc fetch protocol, report affirmation).

## Template Inventory

`templates/` has a template for every file type any surface can produce; look one up via `references/surfaces.md` and never invent file content from prose.
**Read `references/template-inventory.md` for the per-surface template list.**

