# Changelog

All notable changes to the `magento2-tools` plugin. The plugin is versioned as a unit;
individual skill versions are tracked in
`skills/magento2-context/references/skill-versioning.md`.

This project adheres to [Semantic Versioning](https://semver.org/).

## [1.4.0] — 2026-06-15 — feature-implement keeps plan.md Current State current

Reliable `## Current State` maintenance during `magento2-feature-implement` execution, so
interrupted runs resume correctly instead of redoing completed work.

### `plan.md` Current State is kept up to date during execution (`magento2-feature-implement` 2.5.0 → 2.6.0)
- The "mark each task `[x]` in `plan.md`" rule is now a **Per-task completion protocol** woven
  directly into the Phase 5 per-task execution loop. Every task type (M/X/R/T/E/G/V/D) ends with
  an explicit "→ run the Per-task completion protocol" step, framed as a gate: a task is not done
  until its checkbox is flipped and `plan.md` saved, and the next task does not start until then.
  Previously the rule lived only in the Feature-Folder preamble and the resume paragraph, so a
  normal run — and especially an `extend`-mode run — finished tasks without ever advancing
  `## Current State`, which then broke resume.
- Resolved an `extend`-mode contradiction: `SKILL.md` said `extend` skipped Phases 3-4 (so no
  `plan.md` / `## Current State` was maintained), while `references/modes.md` kept a shortened
  Phase 4. `extend` now skips **Phase 3 only** and keeps a minimal Phase 4 that writes `plan.md`
  with a `## Current State` checklist. `modes.md` extend/hotfix pipelines name the protocol
  (hotfix has no `plan.md`, by design).
- Added a Current-State **reconciliation safety net** at Phase 6 start: any completed Phase 5
  task still shown unchecked is flipped to `[x]` before the smoke loop runs.

## [1.3.0] — 2026-06-12 — review findings route to the owning skill

Deterministic remediation routing for `magento2-module-review`: acting on review findings now
dispatches each item to the skill that owns the work instead of fixing everything inline.

### Review fix-routing — findings route to the owning skill (`magento2-module-review` 2.2.3 → 2.3.0)
- New **Fix Routing** table in `magento2-module-review`: when the user proceeds with review
  findings or recommendations, each item is routed deterministically — behavioural and security
  defects to `magento2-bug-fix`, functionality/schema changes to `magento2-feature-implement`
  (`--mode=extend`), coverage gaps to `magento2-test-generate`, and performance/security-scoping/
  data/upgrade/i18n/frontend items to their audit or builder skills. Inline fixing in step 6 is
  reserved for style/PHPDoc-class items and now explicitly includes Low severity (previously
  Low findings were silently dropped from fix passes).
- Both report templates (`report-template.md`, `report.html`) require every Recommended Next
  Step to name its executing skill, so reports stay actionable across sessions.
- Diff-mode reviews invoked from `magento2-feature-implement` / `magento2-bug-fix` /
  `magento2-module-upgrade` return findings to the calling skill — the caller owns remediation,
  preventing routing recursion.

## [1.2.0] — 2026-06-12 — project-root artifacts, approval-gate hardening, PER-CS/Magento2 templates

Artifact-location and approval-gate corrections to the feature workflow, a PER-CS-3.0 coding-style
baseline with Magento-2 precedence, and a full PHP-template compliance pass (generated PHP now
passes `phpcs --standard=Magento2` with zero errors).

### Artifact location — `.docs/` anchored at the project root
- `.docs/` artifacts are now explicitly anchored at the **project working directory**
  (`{project_root}/.docs`) and never written under `{magento_root}`/`app/code`, even when a
  step changes the shell cwd. The context hub gains `project_root` and `docs_root` JSON fields
  and an **Artifact location** Core Rule; `findings-schema.md` and every standalone `.docs`
  writer (review, bug-fix, i18n, eav-attribute, test-generate, module-upgrade, deploy,
  performance-audit, debug) point to it. (`magento2-context` 1.4.0 → 1.5.0.)
- `emit-json.sh` and `build-findings.sh` gain a `DOCS_ROOT` knob (default `.docs`) so an
  in-`src/` cwd cannot redirect findings into the Magento tree. (`magento2-module-review`
  2.2.1 → 2.2.2; `magento2-performance-audit` 1.1.0 → 1.1.1.)

### Feature workflow — save-before-present and plan/task gating (`magento2-feature-implement` 2.4.0 → 2.5.0)
- **Blueprint always saved before review:** Phase 2 now writes `blueprint.md` to disk and
  confirms it exists *before* presenting it, and cites the path. No more presenting a blueprint
  that lives only in the chat.
- **`plan.md` saved for review before the approval gate:** Phase 4 writes `plan.md`
  (`Status: Awaiting Approval`) and confirms it on disk *before* presenting it — the user
  reviews the file. Detailed task records (`tasks.md` / `tasks/`) are written **only after** the
  plan is approved. `task-breakdown-guide.md` corrected to match the new ordering.
- **Per-task files carry an execution-order prefix:** `{ID}-{kebab-title}.md` →
  `{NNN}-{ID}-{kebab-title}.md`, where `{NNN}` is a zero-padded index (`001`, `002`, …) from the
  dependency order. Tasks in the same parallel wave share the same `{NNN}`, so the folder sorts
  into execution order and surfaces parallel groups at a glance.

### Coding style — PER-CS 3.0 baseline with Magento 2 precedence
- New shared reference `magento2-context/references/php-coding-style.md`: generated/modified PHP
  follows **PER Coding Style (PER-CS) 3.0** as the baseline; where it conflicts with the Magento 2
  coding standard or framework requirements, **Magento 2 wins**. `--standard=Magento2` PHPCS
  remains the single enforcement gate — this is generation/review guidance, not a second ruleset.
  Wired into `magento2-module-create` (Step 4 generation rules) and `magento2-module-review`
  (`phpdoc-code-style.md` lens), with one-line pointers from graphql-create, eav-attribute,
  data-migration, bug-fix, and frontend-create. (`magento2-context` 1.5.0 → 1.6.0;
  `magento2-module-create` 1.6.0 → 1.7.0; `magento2-module-review` 2.2.2 → 2.2.3.)

### PHP templates — PER-CS / Magento-2 compliance
- Audited all 64 PHP templates with the authoritative `Magento2` PHPCS standard and PSR-12
  (PER-CS proxy). Generated PHP now passes `--standard=Magento2` with **0 errors** (was 19+).
  Fixes: split multiple-`use`-on-one-line, joined `private`-keyword splits, corrected broken
  method-body indentation; added/repaired PHPDoc (multi-line method docblocks, short descriptions,
  missing `@param`, `@var` on plain-typed test properties); simplified unparseable array-shape
  `@param` types; **removed `final`** from all 19 template classes (Magento prohibits `final`).
  Residual: 10 warnings on intersection-typed mock properties — a known sniff limitation,
  documented in `php-coding-style.md` (*Known Sniff Limitations*), left intentionally.
  (`magento2-bug-fix` 1.0.1 → 1.0.2, `magento2-data-migration` 1.1.0 → 1.1.1,
  `magento2-eav-attribute` 1.1.1 → 1.1.2, `magento2-graphql-create` 1.0.1 → 1.0.2,
  `magento2-test-generate` 1.1.0 → 1.1.1.)

## [1.1.0] — 2026-06-12 — skill-library hardening pass

A broad correctness, consistency, and portability pass across the skill suite, grouped by
workstream below. (Issue-ID labels such as `CTX-1` / `EAV-1` come from an internal audit.)

### Workstream A — Unblock & hub contract
- **EAV-1:** removed 4 leading spaces before the opening `---` in
  `magento2-eav-attribute/SKILL.md` so the skill registers again (was silently absent).
  (`magento2-eav-attribute` 1.1.0 → 1.1.1.)
- **CTX-1:** the context hub now emits `runner: ""` (empty string) in bare-PHP mode
  instead of JSON `null`; consumers compose `${runner} php ...`, so `null` had produced
  the literal command `null php -r ...` (exit 127). JSON `null` is reserved for the
  no-environment case. (`magento2-context` 1.3.0 → 1.4.0.)
- **FI-4:** trimmed `magento2-feature-implement` frontmatter description to ≤1024 chars.
  (`magento2-feature-implement` 2.3.0 → 2.3.1.)
- **TEST-1:** new `tests/test-skill-frontmatter.sh` validates the opening `---`, `name:`
  ↔ directory match, and a non-empty `description:` ≤1024 chars for every skill.
- **TEST-2:** `tests/test-context-resolver.sh` now asserts the runner contract
  (`runner_kind != null` on a PHP host; `bare ⇒ runner == ""`); the unreachable
  `theme == custom` check is replaced with a real honest-gap assertion + tombstone note.
- **Harness:** `tests/run-all.sh` recognises exit 77 as SKIP (counted separately) and
  uses `mktemp` for its scratch file; `test-version-registry-consistency.sh` now also
  checks `"skillVersion"` JSON literals under each skill's `scripts/` (TEST-3).

### Workstream B — Broken generated code & fatal scripts (`magento2-module-create` 1.5.1 → 1.6.0)
- **MC-1:** `verify-created.sh` no longer flags every PHPDoc `@tag` as a forbidden
  construct (the `@` pattern now targets only the error-suppression operator), so compliant
  modules stop failing Category 4.
- **MC-2:** replaced `((var++))` with `var=$((var+1))` and guarded lint command
  substitutions with `|| true`, so the scan runs to completion and prints its summary
  instead of aborting at the first finding under `set -e`.
- **MC-3:** corrected `graphql-batch-resolver.php` to the real
  `BatchResolverInterface::resolve(ContextInterface, Field, array)` signature.
- **MC-4:** `model-entity.php` now extends `AbstractExtensibleModel` (the base that actually
  provides `_getExtensionAttributes()`/`_setExtensionAttributes()`).
- **MC-5:** `acl.xml` now declares the `::view`/`::manage` resources `webapi.xml` references
  (REST routes no longer 401).
- **MC-6:** added the missing admin-form button templates (`GenericButton`, Back/Save/
  SaveAndContinue/Delete) and split the form-vs-grid data providers (`{Entity}FormDataProvider`
  is form-shaped; the listing provider now returns grid shape).
- **MC-7:** added `repository.php` and `search-results-interface.php` templates and aligned
  `test-repository.php` (CollectionProcessor-based constructor).
- **MC-8:** fixed the self-contradictory `test-observer.php` (real `never()`/`once()`
  assertions; observer fetches the event so the catch path is reachable).
- **GQL-1 (security):** corrected the inverted `getUserType()` table in `auth-patterns.md`
  to `UserContextInterface` semantics (admin = 2, not 3) so admin-only resolvers gate admins,
  not customers. Also fixed GQL-3 (no schema-level auth directive) and GQL-4
  (`getWebsiteId()` not `getStores()`).
- **FE-1:** fixed `alpine-component.phtml` JS escaping (escapeJs inside a quoted literal).
- **DEP-1:** deploy preflight `setup:db:status` now passes on ordinary pending changes
  (applied by `setup:upgrade`) and only fails on downgrade/manual-action states.
- **DEP-2:** `snapshot.sh` gained `--include-db` (mysqldump) and the rollback docs now state
  that a code-only revert is lossy for schema/data patches.
- **DEP-7:** preflight PHPUnit check runs only on modules that ship `Test/Unit` and records
  `skipped`/non-required when phpunit or tests are absent (test-less modules can deploy).
- **DM-1/DM-2:** idempotency recipes use `hash('sha256', …)` and read via
  `ScopeConfigInterface` (the writer has no read method).
- **DM-4:** the importer counts a ragged CSV row as one failed row instead of aborting.
- **DM-5:** the transformation patch uses keyset-paginated chunks and marks only the
  processed ids migrated (no whole-table load; no silent data loss under concurrent writes).
- **UPG-1/UPG-2:** corrected the PHP-matrix facts (implicit-nullable deprecation is 8.4 not
  8.1, `mt_rand()` not removed) and the 2.4.8 PHP floor (8.3, not 8.2); added a
  supported-PHP-per-Magento table.

### Workstream C — Fabrication purge & fact-check
- **graphql-create** (1.0.0 → 1.0.1): removed fabricated batch-resolver wiring
  (`BatchResolverFactory`, `BatchedResolverProvider`, `@doc(batch:)`), `DataLoaderInterface`,
  and `dev:graphql:schema-diff`; fixed the `SearchResultPageInfo` and `Magento_PageCache`
  references.
- **module-upgrade** (1.0.0 → 1.1.0): replaced the fabricated `magento/rector-rules-magento`
  / `MagentoLevelSetList` / `rector --only` / `m2-coding-standard` with the real
  `rector/rector` + `SetList`/`withRules` and `phpcs --standard=Magento2`; added the Adobe
  UCT tool; fixed `composer why-not` to the product metapackage; added `status: live|
  illustrative` markers to the version matrices and fixed the deprecation-map errors.
- **release** (1.0.1 → 1.1.0): replaced the fictional `composer publish` and the fabricated
  GitHub-Packages Composer endpoint with real Private Packagist / Satis / VCS flows;
  path-filtered the per-module `git log`; fixed `tag.gpgsign` and the RC-tag sort caveat.
- **security-audit** (1.1.0 → 1.2.0): replaced the invented EQP binaries / EQP-1…14 ids with
  the real `phpcs --standard=Magento2` (`magento/magento-coding-standard`) flow and real
  sniff codes; retired-docs links fixed.

### Workstream D — Scanner & script robustness
- **SEC-1:** `cve-scan.sh` no longer appends `{}` to composer-audit output (which dropped
  every advisory exactly when advisories existed); parse failures now surface in
  `scanner_errors` instead of silently dropping findings.
- **SEC-2:** the CVE mini-YAML parser is now indent-relative, so naturally-nested entries
  parse (and a loud warning fires if entries exist but none parse).
- **SEC-3:** gitleaks now writes to `--report-path` and the result is read from that file;
  exit-code 1 (leaks found) is handled and tool errors fall through instead of exiting 0
  empty.
- **SEC-7:** completed the fallback regex pack (incl. the 3 Magento-specific patterns), added
  canonical-example/placeholder filtering, and mapped trufflehog severity off the Verified flag.
- **performance-audit** (1.0.1 → 1.1.0), **module-review** (2.2.0 → 2.2.1), **debug**
  (1.0.0 → 1.1.0), **test-generate** (1.0.0 → 1.1.0), **i18n** (1.1.0 → 1.2.0): scanner and
  template fixes (PERF-1 runtime-merge, PERF-2/3 static patterns; REV-1 SARIF null `helpUri`,
  REV-2 per-file `php -l`; DBG-1 root-aware walks, DBG-3 Monolog-2 timestamp; TG-1 real
  idempotency assertion, TG-4 coverage dedup; I18N-1 quote-aware extraction, I18N-3/4 sidecar
  obsolete handling).

### Workstream E — Harness hardening
- **TEST-4:** reference-integrity recognises the `magento2-<skill>/…` cross-ref form and
  resolves it precisely; the two known dangling refs are fixed.
- New tests: `test-skill-frontmatter.sh`, `test-plugin-marketplace-sync.sh`,
  `test-context-layout-override.sh` (src-layout + override + cache). CI gained a `shellcheck`
  job and `workflow_dispatch`. `scanner_errors` documented in `findings-schema.md`.
- Plugin unit version bumped 1.0.0 → 1.1.0 (`plugin.json` + `marketplace.json`).

### Documentation
- New developer documentation set under `docs/`: getting started, daily workflows,
  new-project guide, flows & scenarios (with Mermaid phase diagrams, approval-gate map,
  artifact map, end-to-end scenarios), per-skill reference, and configuration/CI guide.
- `README.md` gained a "First steps" quickstart for first-time users and a Documentation
  section linking the new docs. (PRs #2, #3.)

### Workstream F — Consistency, dedup & stale references
- Purged stale slash-command names (`/validate`, `/deploy`, `/module-review`, `/observer`) and
  the non-existent `frontend-create (augment)` routing; unified the commit-format rule
  (no hard-coded versions in commits); added `-c dev/tests/unit/phpunit.xml.dist` to every
  phpunit invocation; aligned `reproduction-patterns.md` with the failing-test rule; corrected
  the EAV product setup-factory table and the false "no duplication" claim.
  (`magento2-bug-fix` 1.0.0 → 1.0.1.)
- **F1 (placeholder schema):** `placeholder-schema.md` regenerated from the de-facto token set
  (172 tokens, organised, with a machine-readable Registry block); normalised the clear
  case-variant duplicates (`{vendor-lower}`/`{vendorLower}`/`{theme-lower}` → snake_case); new
  `tests/test-placeholder-tokens.sh` enforces the registry (the previously-missing unknown-token
  lint).
- **F2 (template single-sourcing):** deleted module-create's three **unguarded** EAV patch
  templates and repointed its surfaces to the canonical, idempotency-guarded
  `magento2-eav-attribute` copies; reconciled the data-patch self-skipping doctrine (default =
  rely on `patch_list`; EAV patches guard because `addAttribute()` isn't re-run-safe); renamed
  frontend-create's `email-templates.xml` → `email_templates.xml` (matches the real Magento
  config + module-create); noted graphql-create as canonical for complex batch resolvers.
- Fixed three more IDE-formatter-corrupted PHP templates (dropped `use {Vendor}\…` prefixes,
  which `php -l` accepts as valid garbage) and added `tests/test-template-orphan-use.sh` so
  that corruption class can never ship silently again.
- **F9 (log-reference merge):** `magento2-debug/references/log-locations.md` is now the single
  canonical log-path catalogue (it absorbed bug-fix's grep-patterns-by-symptom and
  what-to-save sections); `magento2-bug-fix/references/log-targets.md` is reduced to a pointer
  plus the bug-fix-specific collect path. Removed two fabricated claims in the process (the
  non-standard `var/log/connection.log` row, and the false "`dev:di:info` truncates logs"
  statement — `dev:di:info` is unrelated to logs).

### Workstream G — Portability & layout/runner awareness
- Context tool probe made layout- and runner-aware (`magento2-context` 1.2.0 → 1.3.0;
  landed after the 1.0.0 tag, predates the 1.4.0 work below).
- **CTX-4:** the context resolver is macOS/BSD-safe (SHA-256 fallback chain; awk instead of
  GNU `sed \U`; literal-tab escaping) — it previously hard-exited on stock macOS.
- **CTX-5/6/7/8/3:** root detected before vendor; layout-aware bare `magento_cli`; Commerce
  Cloud + Mage-OS editions; broader compose service-name match; cache TTL + atomic write.
  (Folded into `magento2-context` 1.4.0.)
- **DEP/G6:** deploy `execute-plan.sh` uses a portable `now_ms()` and escapes backslashes in
  its JSON (DEP-6).

### Workstream H — feature-implement & modernization (`magento2-feature-implement` 2.3.1 → 2.4.0, `magento2-debug` 1.1.0 → 1.2.0)
- **FI-2 (Critical):** the smoke-browser raw-CDP fallback no longer fake-passes — it exits 78
  (skipped/unverified) instead of returning hardcoded 200s.
- **FI-1 (Critical):** the smoke-baseline death-march is fixed — the S8 criterion is "no
  new/unresolved exception groups" instead of the unsatisfiable "diff is empty".
- **FI-3:** feature-implement invokes `magento2-context` instead of hand-rolling a probe.
- **FI-7/8/9/10:** `admin-login` saves cookies (and `require("fs")` → ESM import); a
  Puppeteer→Playwright adapter makes the second backend work; admin path is configurable
  (`--admin-path`) and the login heuristic checks for the login form rather than a hardcoded
  `/admin`; S4/S5/S9 acceptance text downgraded to what the script actually does.
- **FI-5/FI-m:** Phase-6B duplicated/drifted suite tables collapsed to reference pointers
  (SKILL.md 625 → ~565 lines); vendor-name leaks (`muonXyz`, `Muon`) replaced with generic
  examples; the CLAUDE.md-as-password risk and the `app/etc/env.php` src-layout path fixed.
- **CTX-2:** active-theme detection prefers a non-base registered theme (was steering Hyva/
  custom sites to Luma); **FE-2/FE-3:** theme-activation guidance + theme-composer constraint.
- **H7 (sub-agent):** `#[DataFixture]`-first integration patterns + MFTF maintenance caveat.
- **H10:** added `magento2-debug/scripts/snapshot.sh` so the `snapshot` mode has an
  implementation (read-only, context-aware).
- **H11:** README + CHANGELOG refreshed (`M2_CACHE_TTL`, the new harness checks).

## [1.0.0] — 2026-05-29

First packaged release: the `magento2-*` skills collection as an installable Claude Code
plugin distributed via the `muon-m2` marketplace (this repo).

### Added
- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` — the repo is its own
  marketplace; skills auto-discovered from `skills/`.
- Per-project environment overrides for `magento2-context`: `M2_PHP_CONTAINER` /
  `M2_MAGENTO_ROOT` env vars and `.claude/m2.json` (`php_container`, `magento_root`).
- Reference-integrity test now validates `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`
  script paths.

### Changed
- **Portability:** removed the hardcoded `battlefield-php` container name; runner detection
  now resolves via env > `.claude/m2.json` > generic name patterns. Magento root detects
  `.`-vs-`src` layout instead of assuming `src`. (`magento2-context` 1.1.0 → 1.2.0.)
- Script defaults (preflight, build-findings, secret/cve/cross-module scans) auto-detect
  `app/code` / `composer.lock` rather than assuming `src/`.
- Doc/template path examples use `{ctx.magento_root}/app/code` instead of `src/app/code`.
- Bundled-script invocations in SKILL.md use `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}`.
- Repo layout: skills moved to top-level `skills/`, harness to `tests/`.
- LF line endings enforced via `.gitattributes`.

Skill names retain the `magento2-` prefix (collision safety); plugin invocation is
`magento2-tools:magento2-<skill>`.
