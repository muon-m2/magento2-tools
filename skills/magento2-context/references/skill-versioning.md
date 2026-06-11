# Skill Versioning

Single source of truth for skill versions and the rules for bumping them. Every saved
artefact (review report, blueprint, plan, task file, deploy report, audit report) must
record the contributing skill versions so older artefacts remain re-interpretable when
skills evolve.

## Current Versions

| Skill                      | Version | Bumped when                                                         |
|----------------------------|---------|---------------------------------------------------------------------|
| magento2-context           | 1.4.0   | JSON schema changes, new resolution rules, new tool probes          |
| magento2-module-create     | 1.6.0   | New template added, surface added, naming rule changed              |
| magento2-module-review     | 2.2.1   | New checklist category, severity calibration change, new JSON field |
| magento2-feature-implement | 2.4.0   | New phase, new approval gate, mode added, template structure change |
| magento2-bug-fix           | 1.0.1   | Workflow phase change, RCA format change                            |
| magento2-deploy            | 1.2.0   | Deploy plan template change, rollback recipe change                 |
| magento2-test-generate     | 1.1.0   | Generator pattern change, new test type added                       |
| magento2-module-upgrade    | 1.1.0   | New deprecation map, BC-break detection rules                       |
| magento2-security-audit    | 1.2.0   | New CVE source, new pattern, severity calibration change            |
| magento2-performance-audit | 1.1.0   | New pattern, new runtime check, severity calibration change         |
| magento2-debug             | 1.2.0   | New mode added, output format change                                |
| magento2-eav-attribute     | 1.1.1   | New entity type supported, new input type, template change          |
| magento2-graphql-create    | 1.0.1   | New resolver pattern, schema-migration rule change                  |
| magento2-frontend-create   | 1.0.1   | New theme detection rule, new component pattern                     |
| magento2-data-migration    | 1.1.0   | New idempotency strategy, new importer pattern                      |
| magento2-release           | 1.1.0   | New tag convention, new publish target                              |
| magento2-i18n              | 1.2.0   | New extraction pattern, new placeholder rule                        |

## Changelog (last update: 2026-06-11)

- **magento2-context 1.3.0 → 1.4.0** — hub runner contract fix plus a portability and
  layout-awareness pass:
  - CTX-1: in bare-PHP mode `runner` now serialises as the empty string `""` instead of JSON
    `null`, which had produced the literal command `null php -r ...` (exit 127) on every
    bare-PHP project. JSON `null` is reserved for the no-environment case.
  - CTX-4: macOS/BSD portability — SHA-256 falls back `sha256sum`→`shasum`→`openssl`;
    first-letter uppercasing uses awk (not GNU `sed \U`); tab escaping uses a literal tab.
  - CTX-5/CTX-6: the Magento-root layout is detected BEFORE vendor resolution (repo-root
    projects now resolve a vendor), and the bare-mode `magento_cli` is layout-aware.
  - CTX-7: edition detection adds Commerce Cloud and Mage-OS.
  - CTX-8: the compose probe matches `php`/`phpfpm`/`php-fpm`/`fpm`/`web` service names.
  - CTX-3: a cache TTL (default 24h, `M2_CACHE_TTL`) re-resolves stale runner state; the cache
    is written atomically.
  Guarded by `tests/test-context-resolver.sh` and `tests/test-context-layout-override.sh`.
- **magento2-eav-attribute 1.1.0 → 1.1.1** — frontmatter fix (EAV-1): removed 4 leading
  spaces before the opening `---` that prevented the skill from registering. Guarded by
  `tests/test-skill-frontmatter.sh`.
- **magento2-feature-implement 2.3.1 → 2.4.0** — Phase-6 overhaul: the smoke-browser raw-CDP
  fallback no longer fake-passes (exits 78 — FI-2); the S8 pass rule is "no new/unresolved
  exception groups" instead of the unsatisfiable "diff is empty" (FI-1); the skill invokes
  `magento2-context` instead of hand-rolling a probe (FI-3); `admin-login` saves cookies and
  S4–S6 re-load them, `require("fs")` → ESM import, a Puppeteer→Playwright adapter, and a
  configurable `--admin-path` (FI-7/8/9); S4/S5/S9 acceptance text downgraded to what the
  script does (FI-10); the duplicated/drifted Phase-6B suite tables collapsed to reference
  pointers; vendor-name leaks and the CLAUDE.md-as-password concern fixed.
- **magento2-feature-implement 2.3.0 → 2.3.1** — trimmed the frontmatter `description` from
  ~1256 to ≤1024 chars (FI-4) so the resume-trigger sentence survives registry truncation.
- **magento2-debug 1.1.0 → 1.2.0** — added `scripts/snapshot.sh` (read-only, context-aware) so
  the documented `snapshot` mode has an implementation; root-aware DI/plugin walks and the
  Monolog-2 timestamp fix from the same pass.
- **magento2-context 1.2.0 → 1.3.0** — tool probe is now layout- and runner-aware.
  Project-local `vendor/bin/*` tools (phpcs, phpstan, phpunit, phpmd, rector, psalm,
  php-cs-fixer) resolve via the host path at the Magento root (so a `src/` layout finds
  `src/vendor/bin/*`) and, when absent from the host mount, via a runner probe
  (`{runner} test -x vendor/bin/<tool>`, guarded on `composer.lock` presence so the
  hermetic contract test never shells into a container). Resolved value is the bare
  runner-relative `vendor/bin/<tool>` for runner-backed modes (consumers prefix `{runner}`
  themselves). Previously these resolved to `null` in `src/` layouts; repo-root (`.`)
  layouts are byte-identical to before.
- **magento2-context 1.1.0 → 1.2.0** — portability: removed hardcoded project container
  name from runner detection. Container now resolves via `M2_PHP_CONTAINER` env >
  `.claude/m2.json` `php_container` > generic name patterns (configured-but-not-running
  falls through). Magento root now detects `.`-vs-`src` layout (was hardcoded `src`
  default), overridable via `M2_MAGENTO_ROOT` / `.claude/m2.json` `magento_root`. Cache
  key now folds in the `.claude/m2.json` hash and the `M2_*` env overrides so changing an
  override busts the cache.
- **magento2-context 1.0.0 → 1.1.0** — new fields: `runner_kind`,
  `theme.frontend_source`, `theme.adminhtml_source`, `composer_source`,
  `php_version_source`. Cache key now includes `composer.json` and `CLAUDE.md` hashes.
  Theme no longer defaults to `custom` without probe evidence.
- **magento2-module-review 2.1.0 → 2.2.0** — `emit-json.sh` now reads `SKILL_NAME`,
  `SKILL_VERSION`, `SKILL_VERSIONS_JSON`, `OUTPUT_KIND`, `OUTPUT_BASENAME` from the
  environment and emits an `outputKind` top-level field.
- **magento2-deploy 1.0.0 → 1.1.0** — `--validate-only` flag added; preflight now
  runs PHPUnit, `setup:db:status`, dependency-graph cycle detection, composer
  install dry-run (production), and maintenance-mode writeable probe (production).
  `record()` treats required-skipped as failure.
- **magento2-security-audit 1.0.0 → 1.1.0** — `build-findings.sh` aggregator added.
  CVE data moved to `magento-cve-data.yaml` with a `status: live|illustrative`
  marker; scanner refuses `confidence: confirmed` unless `status: live`.
- **magento2-eav-attribute 1.0.0 → 1.1.0** — product, customer, category templates
  now include `getAttribute()` idempotency guards.
- **magento2-i18n 1.0.0 → 1.1.0** — `merge-csv.sh` added; obsolete phrases now go
  to `<locale>.obsolete.csv` instead of inline comments.
- **magento2-module-create 1.5.0 → 1.5.1** — `create-dirs.sh` accepts `MODULE_DIR`
  env override; `verify-created.sh` arithmetic bug fixed.
- **magento2-performance-audit 1.0.0 → 1.0.1** — `emit-json.sh` invocation contract
  documented via env vars (`SKILL_NAME=magento2-performance-audit`,
  `OUTPUT_KIND=performance`).
- **magento2-release 1.0.0 → 1.0.1** — Phase 2 now calls
  `magento2-deploy --validate-only`.

## Header Format

Single-skill artefact:

```
Skill version: {Skill}@{Version}
```

Multi-skill artefact (preferred — explicit about every contributor):

```
Skill versions:
  - {LeadSkill}@{Version}
  - {ContributingSkillA}@{Version}
  - {ContributingSkillB}@{Version}
  - magento2-context@{Version}
```

Substitute concrete values from the table above when writing an artefact. The
registry-consistency test recognises these tokens as placeholders and does not
flag them as drift.

## Semver Rules

| Bump  | Trigger                                                                                             |
|-------|-----------------------------------------------------------------------------------------------------|
| Major | Removed checklist categories, changed JSON schema in a backward-incompatible way, removed CLI flags |
| Minor | New checklist category, new mode, new template, new optional flag                                   |
| Patch | Bugfix only — no behaviour change to outputs                                                        |

Bumping a skill means editing this file AND updating any template strings that emit the
version (`templates/feature-blueprint.md`, `templates/final-report.md`,
`templates/task-list.md`, `references/report-template.md`, `templates/report.html`).

## Why This Matters

Saved reports include the skill version that produced them. Future re-reads can detect
mismatch and either re-run with current skills or explicitly preserve historical
interpretation. The version is the contract for "this report's findings mean what those
rules meant at that time."
