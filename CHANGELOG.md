# Changelog

All notable changes to the `magento2-tools` plugin. The plugin is versioned as a unit;
individual skill versions are tracked in
`skills/magento2-context/references/skill-versioning.md`.

This project adheres to [Semantic Versioning](https://semver.org/).

## [1.21.2] — 2026-07-17 — Patch-level detection (dormant until CVE data is curated)

### Fixed

- **The scanner can now recognize patch-fixed advisories and report `needs-triage` instead
  of a false positive.** Adobe deliberately decoupled "is fixed" from "what version am I":
  isolated patches (e.g. APSB26-73) and hotfixes (e.g. APSB25-88 / SessionReaper,
  CVE-2025-54236 — CISA KEV, actively exploited) carry security fixes with **no version
  bump**. `2.4.9-2026-jul` is a ZIP filename, not a version — `composer.lock` still says
  `2.4.9` — so version matching alone cannot tell a patched store from a vulnerable one;
  left unguarded, it would report a fully-patched store as vulnerable. That would be a
  false positive, not a silent miss — the inverse of the previous two releases' failure
  mode. Less dangerous, but it is exactly how a scanner becomes noise operators learn to
  ignore.

  An advisory can now declare `fixed_by_patch`; the scanner stops asserting `confirmed` for
  those and emits `confidence: needs-triage` naming the patch and the command to verify it.
  Where a `detect` signature pair is curated, `vendor/` is read for a definite answer:
  **patched → suppressed**, **unpatched → `confirmed`**, **neither → `needs-triage`**
  ("vendor/ matches neither baseline"). Two *positive* signatures deliberately: a store
  carrying a backport or hand-edit matches neither, and a single marker would cry wolf at
  the operators who patched early — Adobe's own tool reports N/A in exactly that case.

  Content markers, not Adobe's reverse-dry-run: that only detects the hotfix path, so a store
  that took the same fix by **upgrading** looks unpatched to it. A marker is present on both
  paths — the reference pair for CVE-2025-54236 is verified against real upstream code,
  where the APPLIED boundary lands exactly on `fixed_in: 2.4.8-p3`. No network, no new
  dependencies; degrades to `needs-triage` when `vendor/` is absent. Advisories without
  `fixed_by_patch` are untouched.

  **This is infrastructure, not yet active detection**: the shipped
  `magento-cve-data.yaml` still declares `status: illustrative` with `entries: []`, so
  nothing is matched against it today. When a curator adds a real entry — e.g.
  CVE-2025-54236, using the reference marker pair now documented in
  `magento-cve-database.md` — and sets `status: live`, a fully-patched store will no
  longer be reported vulnerable for that advisory.

## [1.21.1] — 2026-07-17 — Advisory-edition validation; CVE data lint

### Fixed

- **A typo'd `edition:` in the CVE data matched zero stores, silently.** The data file is
  hand-curated from Adobe security bulletins — whose prose says "Adobe Commerce" and "Adobe
  Commerce Cloud" — and it ships with the plugin, so a curator error reaches every user.
  `Commerce`, `enterprise` and `adobe-commerce` each matched **nothing**, with no warning;
  one on a Critical CVE would have been a fleet-wide silent false negative. An unrecognized
  edition is now treated as **unknown** rather than "does not apply": it matches regardless
  of edition, is downgraded to `confidence: candidate` (per-finding — genuine confirmed
  findings are not demoted), and warns into `scanner_errors`. This mirrors what an **absent**
  `edition:` already does: match every store, which is how "affects both editions" is
  expressed — so omitting the field was always safe while misspelling it was silently
  dangerous. Deliberately **not** normalization: `Commerce` is not quietly accepted as
  `commerce`, which would hide the very error being surfaced. Recognized editions are
  unchanged — `commerce` still does not match an `open-source` store, preserving the edition
  isolation added in 1.21.0.
- **The shipped CVE data file is now linted in CI** (`tests/test-cve-data-schema.sh`) —
  and the lint checks what `cve-scan.sh`'s own parser sees, not what a regex guesses. It
  extracts and executes the real `load_cve_data_yaml` / `parse_record` / `version_in_range`
  out of `cve-scan.sh` (never a hand-copied reimplementation, which could quietly drift
  from the parser it's meant to police), then asserts: every entry the file appears to
  define is actually recognized as a record — not silently dropped (e.g. by an entry
  whose first key isn't `cve`); `affected` is a non-empty list of mapping objects, not
  emptied by wrong indentation or opaque flow-style YAML; each `magento_version_range`
  is one `version_in_range()` can actually match against some version, not a dead range;
  `edition` is `open-source`/`commerce` or absent; and the explicitly-required fields
  (`cve`, `bulletin_url`, `affected`, `recorded_at`) are present. An earlier version of
  this lint regexed the raw text instead and had holes wide enough to bless several of
  these silent-drop shapes — including the one `yaml.dump` produces by default. The
  runtime guard above only fires on a user's machine after bad data has shipped; this
  catches it before release. Both are prerequisites for ever setting
  `magento-cve-data.yaml` to `status: live`.

## [1.21.0] — 2026-07-17 — `distribution_version` + four CVE silent-false-negative fixes

### Added

- **`distribution_version` in the `magento2-context` output schema** — records *what you
  actually installed*, alongside `magento_version` (the Magento base). On the `magento/*`
  editions the two are identical, because those product metapackages version in lockstep
  with Magento. On Mage-OS they diverge: Mage-OS `3.2.0` is based on Magento `2.4.9`.
  Mirroring on non-forks (rather than emitting `null`) means consumers read one field
  unconditionally with no edition branching. Resolved from the
  `mage-os/product-community-edition` entry in `composer.lock`, falling back to the
  composer.json constraint — disclosed in `resolution_source` as
  `"(constraint, not a pinned version)"` — when no lock is present. Additive and optional,
  so `schemaVersion` stays `1.0`. Skill bump: `magento2-context 1.9.0 → 1.10.0` (with the
  `@version` token refs in 19 files across 13 dependent skills tracking the hub).

  This is the Mage-OS patch-level signal: `3.0.0`, `3.1.0` and `3.2.0` **all** report base
  `2.4.9`, and only `3.2.0` carries Adobe's isolated security patch `249-2026-07-001`
  (2026-07-14) — so `magento_version` alone cannot tell a patched Mage-OS store from an
  unpatched one.

- **Magento 2.4.9 in the BC-break matrix** (GA 2026-05-12): PHP 8.2 dropped;
  `laminas/laminas-mvc` and `magento/magento-zf-db` removed (native MVC); Symfony 6.4 → 7.4
  LTS, which breaks subclasses; Zend_Cache → `symfony/cache`; TinyMCE → HugeRTE; PHPUnit
  10.5 → 12; new GraphQL input limits (10 aliases, ~1 MB query length). Grep patterns added
  for the removals. Refutations are recorded alongside them so a future refresh does not
  "rediscover" them: jQuery and RequireJS were **not** removed, `carlos-mg89/oauth` is absent
  from both 2.4.8 and 2.4.9 (so it is not a 2.4.9 change), Elasticsearch is still required,
  and Laminas is not gone — the package count went 17 → 19, so only `Laminas\Mvc\` should be
  scanned, never a bare `Laminas\`.

### Fixed

- **Mage-OS stores silently reported clean by the security audit.** Two compounding bugs.
  `resolve-context.sh` set `magento_version` from the composer.json constraint, so a Mage-OS
  store reported `3.2.0` — a Mage-OS version, not a Magento version at all — which matched no
  `2.4.x` range anywhere. And `cve-scan.sh` compared the resolved edition against each
  advisory's, so `edition="mage-os"` matched neither `open-source` nor `commerce` and **every**
  advisory was skipped. Mage-OS is a downstream fork of Open Source and inherits Adobe's
  vulnerabilities (it applies Adobe's patches), so `open-source` advisories genuinely apply;
  it now maps onto them, and deliberately **not** onto `commerce`. Both were masked only
  because the shipped CVE data file is empty — populating it (`status: live`) is what would
  have armed the false negative. Findings on Mage-OS also cited
  `magento/product-mage-os-edition`, a package that exists nowhere, and recommended upgrading
  to a Magento version the distribution cannot install; they now cite
  `mage-os/product-community-edition` and point at the Mage-OS release whose base is fixed.

- **Commerce Cloud stores silently reported clean by the security audit** — the same bug
  class and the same function as the Mage-OS fix above, just the other fork. `cve-scan.sh`'s
  `advisory_edition()` mapped only `mage-os` onto the advisory vocabulary and passed every
  other edition through unchanged; `commerce-cloud` therefore equalled neither `open-source`
  nor `commerce`, so **every** advisory was skipped and a vulnerable Commerce Cloud store
  reported clean. Commerce Cloud ships the cloud metapackage on top of the enterprise
  edition — it is Adobe Commerce plus a deployment layer, not a separate product line — so a
  `commerce` advisory genuinely applies; it now maps onto `commerce` (and, unlike Mage-OS,
  does not additionally inherit `open-source` advisories, since Cloud is not a fork of Open
  Source). Findings on `commerce-cloud`, `commerce`, and `open-source` stores also cited
  fictional packages (`magento/product-commerce-cloud-edition`,
  `magento/product-commerce-edition`, `magento/product-open-source-edition` — none exist);
  package-name lookup is now an explicit mapping onto the real metapackages
  (`magento/product-enterprise-edition`, `magento/product-community-edition`) instead of
  interpolating the edition string into a name.

- **Open Source, Commerce, and Commerce Cloud stores could silently report clean on a
  compound or wildcard version constraint — the same bug class as the two Mage-OS/Commerce
  Cloud fixes above, but on `magento_version` itself, the field `cve-scan.sh` actually
  matches CVEs against (`distribution_version`, where the earlier fixes landed, feeds
  nothing today).** `resolve-context.sh` stripped operator characters *and the space* from
  the raw composer.json constraint on all three `magento/*` branches, so a compound range
  glued its two bounds into one plausible-looking number
  (`">=2.4.6 <2.4.8"` → `"2.4.62.4.8"`, which compares cleanly and can fall outside every
  affected range) and a wildcard or two-component constraint produced a string
  `parse_version()` cannot parse at all (`"2.4.*"` → `"2.4."`, `"^2.4"` → `"2.4"`) — either
  way, `version_in_range()` returned `False` for every advisory and the store reported
  clean regardless of its real version. These three branches have no lock-based fallback,
  so the constraint is the *only* source: there was no honest gap to fall back to. The
  strip-then-validate discipline already applied to Mage-OS's `distribution_version` (leave
  the space in place, validate the result, null out with a reason naming the raw constraint
  instead of publishing a glued fiction) is now factored into one shared helper and applied
  to all four editions; `magento_version` additionally requires a full three-component
  release; a two-component `"2.4"` still passes the looser Mage-OS shape but still defeats
  `parse_version()`, so it is rejected here. `distribution_version`, which mirrors
  `magento_version` on these three editions, now follows it honestly to `null` instead of
  carrying forward a stale or glued value. Defence-in-depth: `cve-scan.sh`'s "matcher did
  not run" warning previously fired only when `magento_version` was empty; it now also
  fires whenever the version is present but unparseable, independently of the resolver fix.

- **Two false rows in the PHP support matrix.** 2.4.8 was documented as requiring a minimum of
  PHP 8.3 and having "dropped PHP 8.1 and 8.2" — marked `status: live`, the marker that
  authorizes confirmed findings. The tag declares `~8.2.0||~8.3.0||~8.4.0`: 2.4.8 dropped only
  8.1, and 8.2 remains installable across the whole line through `2.4.8-p5`. **PHP 8.2 is
  dropped in 2.4.9, not 2.4.8.** 2.4.5 was listed as 8.1-only but still installs on 7.4. Both
  rows came from prose in a release note rather than from the constraint at the tag; the table
  now separates **Installable** (`require.php`, what composer enforces) from
  **Adobe-supported** (what Adobe runs in production), which for 2.4.9 genuinely differ — it
  installs on 8.3, but Adobe designates 8.3 upgrade-only and validates against 8.5.

- **Stale PHP constraint hint in `magento2-marketplace-prep`.** The Marketplace readiness check
  suggested `'>=8.1 <8.4'`, which excludes PHP 8.4 and 8.5 — both currently supported — and
  floors two majors below what 2.4.9 will install on. A vendor following it would ship a module
  that refuses to install on every modern store. The hint now attributes its example to a
  *named* Magento version, so it stays true as new releases ship rather than rotting silently.

## [1.20.1] — 2026-07-16 — Landing page + schema URN fixes

### Added

- **Project landing page** at <https://muon-m2.github.io/magento2-tools/> — a single
  self-contained GitHub Pages site (served from the `gh-pages` branch) linking to the
  documentation and repository. Linked from the README; the Releasing section documents
  bumping the hero version badge at each release.

### Fixed

- **Three dangling schema URNs in generated XML.** Four generators emitted an
  `xsi:noNamespaceSchemaLocation` pointing at an `.xsd` that does not exist, so a generated
  module failed validation at runtime (`Could not find schema file` on cache flush /
  `setup:upgrade`) even though the XML was well-formed:
  - `etc/config.xml` used `urn:magento:framework:App/etc/config.xsd` — `App/etc/` ships no
    `config.xsd`; the schema is `urn:magento:module:Magento_Store:etc/config.xsd`
    (`magento2-system-config`).
  - `etc/communication.xml` used `urn:magento:framework:MessageQueue/etc/communication.xsd`
    (`magento2-message-queue`) and `urn:magento:framework-message-queue:etc/communication.xsd`
    (`magento2-module-create`) — `communication.xsd` lives in neither; it is
    `urn:magento:framework:Communication/etc/communication.xsd`. The sibling
    `framework-message-queue` URNs for `topology`/`publisher`/`consumer` were already correct.
  - `etc/adminhtml/routes.xml` used `urn:magento:module:Magento_Backend:etc/routes.xsd`
    (`magento2-module-create`, `magento2-adminhtml-listing`) — admin routes use the same
    `urn:magento:framework:App/etc/routes.xsd` as frontend routes, as
    `magento2-adminhtml-form` already did.

  All 27 URNs shipped in the repo were verified against `magento/magento2` 2.4-develop; the
  remaining 24 were already correct. New `tests/test-template-urn.sh` pins every URN to a
  verified allowlist — `test-template-xml-lint.sh` only proves well-formedness and never
  resolves the schema location, which is how these shipped. Patch bumps:
  `magento2-module-create 1.10.1 → 1.10.2`, `magento2-adminhtml-listing 1.1.2 → 1.1.3`,
  `magento2-system-config 1.1.2 → 1.1.3`, `magento2-message-queue 1.1.2 → 1.1.3`.

## [1.20.0] — 2026-07-07 — Generator source-of-truth-first

### Changed

- **Generators now build from templates + references + Magento standards, never from unrelated
  local modules.** Adds a shared `magento2-context/references/source-of-truth.md` (source-of-truth
  hierarchy, a prohibition on scanning unrelated `app/code`/`vendor` modules for conventions, the
  narrow allowed-reads exceptions — target module and directly-declared-dependency contracts — and
  an uncertainty-gated official-doc fetch protocol allowlisted to `developer.adobe.com` /
  `devdocs.magento.com`). A `**Source of truth.**` Core Rule bullet and a Reference-Files pointer
  were added to all 18 generator skills (15 code generators, `magento2-docs-generate`,
  `magento2-test-generate`, and `magento2-feature-implement`). Read-only audit/review skills are
  unchanged. Guarded by `tests/test-source-of-truth-reference.sh` and
  `tests/test-source-of-truth-rollout.sh`.
- Skill patch-bumps (behavioral rule added to each): all 18 touched skills — see
  `skills/magento2-context/references/skill-versioning.md`.

## [1.19.1] — 2026-07-05 — Breeze-aware frontend-create routing

### Fixed

- **`magento2-frontend-create` is now Breeze-aware.** The frontend scaffolder previously
  recognized only Luma / Hyva / custom themes, so on a Swissup Breeze (Breezefront) store a
  request for a theme or child theme fell into its "Custom → default to Luma" path and
  produced the wrong structure — even though `magento2-context` already emits a `theme.breeze`
  object and three dedicated `magento2-breeze-*` skills exist. Routing was one-directional
  (the Breeze skills named `frontend-create` as their sibling, but not vice-versa). The skill
  now reads `theme.breeze` and **routes** Breeze work to the right place: a Breeze `theme`
  operation → `magento2-breeze-child-theme`; Breeze widget/JS work → `magento2-breeze-module-adapt`
  (scope first with `magento2-breeze-compat-audit`). Adds a Breeze row to the theme-awareness
  table, a Phase 1 routing branch (mirroring the existing Hyva `ko`→`alpine` nudge), a
  Core-Rules Breeze-aware note, and reciprocal Related-Skills links. Guarded by a new
  `check frontend-create …` assertion in `tests/test-routing-discriminators.sh`. Patch bump:
  `magento2-frontend-create 1.0.3 → 1.0.4`.

## [1.19.0] — 2026-07-05 — Findings-emission hub + release-readiness audit orchestrator

### Added

- **`magento2-audit` — a read-only release-readiness orchestrator (new skill, `/magento2-tools:audit`).**
  The *inspect* counterpart to `magento2-feature-implement`: one command runs every findings dimension
  (architecture/quality/security review via the `magento2-reviewer` agent, plus `magento2-security-audit`,
  `magento2-performance-audit`, `magento2-static-analysis`, and — where the surface warrants —
  `magento2-accessibility-audit`, `magento2-marketplace-prep`, `magento2-breeze-compat-audit`), fans them
  out in parallel, and **consolidates** them via `scripts/consolidate.sh` into ONE deduplicated,
  severity-ranked report + one merged SARIF (`outputKind=audit`). Duplicates across dimensions collapse to
  a single finding tagged with every dimension that raised it (highest severity wins); an overall
  `PASS`/`CONDITIONAL`/`FAIL` verdict + score is computed. Regression-guarded by
  `tests/test-audit-consolidate.sh`.
- New `audit` value in the shared findings-schema `outputKind` enum, for the consolidated document.

### Changed

- **Findings emitters moved into the `magento2-context` hub.** `emit-json.sh`, `emit-sarif.sh`,
  and `resolve-basename.sh` now live in `skills/magento2-context/scripts/` instead of
  `skills/magento2-module-review/scripts/`. This removes the fragile cross-skill dependency where
  six audit skills reached a sibling skill's scripts dir (`../../magento2-module-review/scripts/`)
  and matches the stated architecture — `magento2-context` is the universal leaf and now owns the
  shared output contract. Emitted JSON/SARIF is byte-identical (golden snapshot unchanged).
- **New shared `emit-findings.sh` wrapper.** The six audit `build-findings.sh` scripts
  (security / performance / static-analysis / marketplace-prep / accessibility / breeze-compat)
  no longer each inline the ~40-line path-resolution + `emit-json` + SARIF-with-fallback tail;
  they call one shared `magento2-context/scripts/emit-findings.sh`. Per-skill post-JSON injection
  (security's `magento_core_cve_status`, marketplace's readiness score) runs via a `POST_JSON_HOOK`
  so behaviour is preserved.

### Fixed

- **`magento2-module-upgrade` now emits SARIF.** It previously wrote Markdown + JSON only via an
  inline emitter, so its deprecation / BC-break findings could not feed CI / GitHub Code Scanning
  like every other findings skill. It now routes findings through the shared hub emitter
  (`scripts/emit-report.sh` → `emit-findings.sh`), producing a schema-valid `.json` plus a `.sarif`
  sibling, and cites the shared `severity.md` + `findings-schema.md`. Regression-guarded by
  `tests/test-upgrade-emitter.sh`.
- **Findings-contract citations made uniform.** `magento2-performance-audit` now cites
  `findings-schema.md` and `magento2-breeze-compat-audit` now cites `severity.md` — closing the
  drift where each had adopted only half of the shared findings contract. All seven
  findings-emitting skills now emit SARIF and cite both shared standards.

## [1.18.0] — 2026-07-04 — Model tiering (advisory per-task tiers + haiku explorer)

### Added

- `magento2-feature-implement` Phase 4 now stamps each task record with an advisory
  `Model tier (advisory)` field (`opus`/`sonnet`/`haiku`) recommending the model tier per task
  type. Advisory only — the harness cannot pin Skill-tool tasks to a model; the field guides
  manual `/model` switching and future per-skill pinning.
- `magento2-explorer` (read-only comprehension agent used by `magento2-feature-implement`,
  `magento2-module-review`, and `magento2-bug-fix`) now defaults to the `haiku` model tier — a
  cost/speed reduction for read-only mapping — overridable via the `CLAUDE.md` directive
  `Explorer model: <tier>`. `magento2-reviewer` is unchanged.

## [1.17.1] — 2026-07-04 — Backlog cleanup (docs polish + internal refactor)

### Changed

- Internal-only cleanup, no behavior change: docs polish (unified the `{Vendor}_{Module}`
  filename token + placeholder notation in `magento2-context/references/artifact-layout.md`;
  `magento2-module-review` output-root heading level; `magento2-i18n` `--docs-root` inputs
  bullet; `magento2-deploy` snapshot.sh phrasing; `magento2-module-create` docs table now
  lists `api-reference`/`graphql-reference`); refactor: the six audit builders now emit
  `scanner_errors` via `emit-json.sh`'s `SCANNER_ERRORS_FILE` and share a
  `resolve-basename.sh` helper (byte-identical output); hardened
  `tests/test-artifact-layout.sh`.

## [1.17.0] — 2026-07-04 — Documentation consolidation

`magento2-docs-generate` is now the single owner of every module documentation type; other
skills delegate or cross-link instead of shipping duplicate, divergent templates. ~17 skills
bumped; docs still generate for every module (via delegation now) — no skill removed.

### Changed

- Documentation is now single-sourced: `magento2-docs-generate` owns every module doc type
  (README, CHANGELOG, guides, references). `magento2-module-create` and
  `magento2-feature-implement` delegate; the feature-level HTML guides link into the module
  Markdown instead of duplicating it. One canonical CHANGELOG format lives in
  `magento2-context/references/changelog-format.md`.

### Added

- Single-surface generators now emit a "run docs-generate to refresh" note after mutating a module.

## [1.16.0] — 2026-07-04 — Unified artifact output root (`--docs-root`)

Every `magento2-*` skill now writes its result artifacts under one overridable output root,
so a `magento2-feature-implement` run collects all its sub-skills' reports under a single
`.docs/{FeatureName}/` tree instead of scattering them across ~20 global category folders.
26 skills bumped; standalone runs are unchanged.

### Added

- Unified artifact output root: every `magento2-*` skill accepts `--docs-root=<path>`, and
  `magento2-feature-implement` uses it to collect a whole run's reports under
  `.docs/{FeatureName}/`. New shared reference `magento2-context/references/artifact-layout.md`.

### Fixed

- All six audit builders now honor `DOCS_ROOT` (four previously ignored it, leaking output
  into the Magento tree when cwd was `src/`) and use one filename scheme
  `{Vendor}_{Module}-{kind}-{date}`, fixing cross-module basename collisions.

## [1.15.0] — 2026-06-20 — Multi-document docs-generate (developer/user guides + REST/GraphQL API references)

`magento2-docs-generate` (`1.0.0 → 1.1.0`) now generates a full documentation set from a
module's own code instead of a single technical reference — all read-only, Markdown-only,
and statically derived (no running Magento instance required).

### Added

- **Four new generated documents** under `{module}/docs/`, each produced only when applicable:
  `developer-guide.md` (always — `@api` usage snippets from real signatures, extension
  points, and Mermaid architecture / event-flow / ER diagrams), `user-guide.md` (when a
  user-facing surface exists — admin config / admin UI / storefront / email walkthroughs
  plus a screenshot **capture-guidance appendix**, never broken `![]` embeds),
  `api-reference.md` (when REST routes exist — per-endpoint request/response/error
  examples + sequence diagrams), and `graphql-reference.md` (when GraphQL operations exist
  — per-operation example query/variables/response/errors + sequence diagrams).
- **Illustrative-example carve-out to the "never invent facts" rule.** Request/response/error
  examples are skeletons generated from real DTO getters / GraphQL field types, captioned
  *"Example — illustrative, generated from the schema"* — never fabricated data. Error models
  are derived from Magento conventions (REST envelope + status mapping; GraphQL `errors[]`
  + `category`).
- **Expanded surface extractor** (`extract-surface.sh`, single JSON contract): new
  `api_methods`, `graphql_operations`, and `user_surface` keys; `rest_routes` enriched with
  `request_shape` / `response_shape` / `throws` (service-method resolution + bounded DTO
  getter walk with `use`-statement short-name resolution, module-local only, graceful
  degradation, method-scoped `@throws`, PHP 8 union-type handling); `graphql` fields enriched
  to `{name, type}`.
- New extractor contract test + fixture module (`tests/test-docs-generate-extraction.sh`,
  `tests/fixtures/docs-generate/`); 16 new placeholder tokens; `--docs` flag extended with
  the new conditional doc types.

## [1.14.1] — 2026-06-19 — README dependency-graph completeness

Documentation-only patch. No skill, command, agent, script, or template changed — only
`README.md`.

### Fixed

- **README dependency graph now covers all 32 skills.** The graph was missing 10 nodes —
  `adminhtml-form`, `extension-point`, `system-config`, `cli-command`, `message-queue`,
  `indexer`, `static-analysis`, `docs-generate`, `marketplace-prep`, and
  `accessibility-audit` — each now added with edges taken from its own *Related Skills*
  table. The `magento2-feature-implement` orchestrator edge was also expanded to the
  generators it actually dispatches (`adminhtml-form`, `extension-point`, `system-config`,
  `cli-command`, `message-queue`, `static-analysis`, `docs-generate`).

## [1.14.0] — 2026-06-19 — Marketplace-hygiene baseline (generators emit marketplace-clean modules)

Generators now bake in the packaging/compliance contract that `magento2-marketplace-prep` audits, so a
freshly scaffolded module clears the systematic first-try Marketplace/EQP blockers and warnings instead
of scoring 0/100. The audit contract is mirrored generator-side in the new shared
`magento2-context/references/module-hygiene.md`.

### Added

- **Tier 1 — `magento2-module-create` 1.8.0 → 1.9.0.** Two always-created templates — `LICENSE.txt`
  (proprietary EULA; swap for the SPDX text when `license` is an SPDX id) and `gitignore`
  (→ module `.gitignore`); an `authors` block in `composer.json` derived from `git config user.name`
  (fallback `gh api user`) and `git config user.email` — never `{Vendor}`; a shared
  `add-license-headers.sh` post-step that stamps the standard copyright header (referencing `LICENSE.txt`)
  onto every `.php`, idempotently. `verify-created.sh` now gates LICENSE, `.gitignore`, `authors`,
  wildcard-free constraints, and the header on every PHP file.
- **Tier 2 — cross-cutting hygiene.** New shared `magento2-context/references/module-hygiene.md` (the
  generator-side contract), `magento2-context/scripts/add-license-headers.sh` (relocated here as the
  single source), and `magento2-context/scripts/resolve-dep-constraint.sh` (resolves a bounded composer
  constraint via `composer show` → `composer.lock` → `composer.json`, never `*`). All 16 PHP-generating
  skills now run the shared stamper as a finalization step (patch bumps). Self-enforcing via
  `tests/test-license-header-coverage.sh`.
- **Tier 3 — MFTF smoke + preflight.** `magento2-module-create` auto-adds a minimal MFTF smoke test
  under `Test/Mftf/` when a UI surface is declared (`mftf-test.xml` + `mftf-actiongroup.xml`), so
  Marketplace functional coverage is non-zero; Step 7 offers a `magento2-marketplace-prep` /
  `check-readiness.sh` readiness preflight before packaging.

### Changed

- Patch bumps for the 16 wired generators (`adminhtml-form`, `adminhtml-listing`, `system-config`,
  `webapi-create`, `eav-attribute`, `extension-point`, `graphql-create`, `message-queue`, `cli-command`,
  `indexer`, `data-migration`, `test-generate`, `frontend-create`, `bug-fix`, `breeze-child-theme`,
  `breeze-module-adapt`). `magento2-context` held at 1.7.0 (resolution contract unchanged; the new
  scripts/reference are shared infra it does not itself invoke).
- `tests/test-placeholder-tokens.sh` now skips MFTF `{{…}}` mustache refs. New tests:
  `test-license-headers.sh`, `test-dep-constraint.sh`, `test-license-header-coverage.sh`.
- Skill count unchanged (32); no new skills.

## [1.13.0] — 2026-06-19 — Breeze (Swissup Breezefront) support

### Added

- **New skill `magento2-breeze-child-theme`** — scaffolds a Swissup Breeze child theme: `theme.xml` with a `Swissup/breeze-*` parent (`breeze-blank`/`breeze-evolution`/`breeze-enterprise`), `registration.php`, `composer.json`, a Breeze-only `breeze_default.xml` layout handle, and Breeze-side overrides in `web/css/breeze/_default.less` with the `@critical` guard. Prefers `bin/magento breeze:theme:create` when available. Sibling to `magento2-frontend-create` (generic Luma/Hyvä/custom themes).
- **New skill `magento2-breeze-module-adapt`** — adapts an existing module to Breeze by generating a **separate companion** `{Vendor}_{Module}Breeze` module (sequenced after the target + `Swissup_Breeze`) that holds the adapter layer: `breeze_default.xml` JS registration on the `breeze.js` block, `web/css/breeze/_default.less`, and Cash `$.widget` stubs converted from the target's RequireJS/Knockout/jQuery widgets. Never edits the target, so it works on read-only `vendor/` modules.
- **New skill `magento2-breeze-compat-audit`** — read-only static auditor; scans a module for RequireJS/Knockout/jQuery-widget/mixin usage and emits ranked findings (Markdown + JSON + SARIF via the shared emitters) plus a verdict (compatible out-of-box / needs Better Compatibility / needs a manual adapter), pointing at `magento2-breeze-module-adapt`.
- **`OUTPUT_KIND=compatibility`** — a new `outputKind` value (+ category vocabulary) in the shared findings schema/emitters, for the Breeze compatibility report.
- **`theme.breeze` detection in `magento2-context` (1.6.1 → 1.7.0)** — a new `theme.breeze` object (`installed`/`active`/`parent`/`packages`/`source`): `installed` keys off any `swissup/breeze-*` / `swissup/module-breeze` composer package; `active` walks the active frontend theme's `app/design` `<parent>` chain for a Breeze ancestor. The three Breeze skills refuse to run (printing the install command) when Breeze is not installed.

### Changed

- Skill count **29 → 32**.

## [1.12.2] — 2026-06-19 — feature-implement: probe-before-fallback sub-skill delegation

### Fixed

- **`magento2-feature-implement` 2.10.0 → 2.10.1** — closes a delegation-discipline gap surfaced by auditing a real feature run, where the orchestrator skipped `magento2-*` sub-skill delegation on an unverified "not Skill-invocable here" assumption and relabelled typed tasks (an admin-config `C` task built inline as `X`). Adds a **Delegate by probing, never by assumption** Core Rule — attempt the `Skill` invocation and fall back to inline only on an actual failure, recording the concrete reason; never pre-declare a sub-skill (or the whole family) unreachable or skip from memory/a project note. Adds a Phase 5 **Fallback discipline** subsection — on a genuine fallback, keep the task's type prefix (never downgrade `C`/`I`/`L`/`Q`/`E`/`G` to `X`) and author the same output inline from the skill's own references; `magento2-feature-implement` never runs `bin/magento` itself (`magento2-deploy` owns the deploy plan). Reinforced by a "type by work, not tool availability" note in `references/task-breakdown-guide.md` and `Skill:`-field + `D1` deploy guidance in `templates/task-record.md`. No new phase/gate/mode/task-type.

## [1.12.1] — 2026-06-19 — documentation is a required step before the final step

### Changed

- **`magento2-feature-implement` 2.9.0 → 2.10.0** — Phase 7 is split into **7A** (documentation, required) and **7B** (final report); 7B may not start until the documentation set exists on disk and is current. 7A (re)generates per-module technical docs via `magento2-docs-generate`, a cross-module `spec.md`, developer- and user-scope HTML guides with screenshots (reusing the Phase 6B captures), REST/GraphQL request/response payload examples when an API surface exists, and other helpful artifacts — refreshed (never left stale) on resume / `extend` runs. New `references/documentation-guide.md` defines the per-scope artifacts, per-mode scope, and completeness gate; per-mode scope is wired into `references/modes.md`; the final report now links the doc set. Previously documentation was an optional Phase-7 after-thought generated *after* the report.
- **`magento2-module-create` 1.7.1 → 1.8.0** — new **Step 6** (documentation, required) before the report (now Step 7). The set is code-derived/static (this skill assumes no running instance) and lives under `{module}/docs/` in Markdown: a technical reference via `magento2-docs-generate`, developer- and user-scope guides, screenshots (or clearly-marked placeholders naming the screen to capture post-deploy when no instance is available), contract-derived REST/GraphQL request/response examples, and helpful artifacts. Reduced to `README.md` + `CHANGELOG.md` in Quick Create Mode; refresh-only in `--mode=augment`. New `references/documentation-guide.md`.

## [1.12.0] — 2026-06-18 — Wave 2: command surface + indexer / marketplace-prep / accessibility-audit skills

### Added

- **New skill `magento2-indexer`** — scaffolds a custom indexer + materialized view: `indexer.xml`, `mview.xml` subscriptions, an indexer implementing both `Indexer\ActionInterface` (executeFull/executeList/executeRow) and `Mview\ActionInterface` (execute) that delegates to a batched, idempotent action class, plus a unit test.
- **New skill `magento2-marketplace-prep`** — read-only Adobe Marketplace / EQP submission-readiness audit (composer metadata, license headers, MFTF presence, version-constraint sanity, packaging) producing a tiered, scored report (Markdown + JSON + SARIF via the shared emitters, `outputKind=marketplace`). Delegates EQP static code rules to `magento2-security-audit` rather than duplicating them.
- **New skill `magento2-accessibility-audit`** — static-first storefront WCAG audit of `.phtml`/`.less` templates (alt text, form labels, ARIA, heading order, keyboard/tab-index, contrast heuristics), theme-aware (Luma/Hyvä), with an optional opt-in `pa11y` runtime pass; emits ranked findings (`outputKind=accessibility`).
- **Five new slash-command shortcuts** — `/magento2-tools:test` (`magento2-test-generate`), `:upgrade` (`magento2-module-upgrade`), `:i18n` (`magento2-i18n`), `:lint` (`magento2-static-analysis`), and a `:scaffold` dispatcher that routes a generation request to the matching generator skill (defaulting to `magento2-module-create`). Command count **9 → 14**.
- **`OUTPUT_KIND=marketplace` and `OUTPUT_KIND=accessibility`** — two new `outputKind` values in the shared findings emitters, for the marketplace-prep and accessibility-audit reports.

### Changed

- Skill count **26 → 29**.

## [1.11.0] — 2026-06-18 — Wave 1: extension/config/cli/queue/static-analysis/docs skills + explorer agent

### Added

- **New skill `magento2-extension-point`** — wires a plugin, observer, or preference onto existing code; generates the interception class, `di.xml` wiring, and a unit test. Covers all three interception modes (`--mode=plugin|observer|preference`).
- **New skill `magento2-system-config`** — generates a complete admin store configuration surface: `system.xml` fields, `config.xml` defaults, `acl.xml` nodes, and a typed config reader class.
- **New skill `magento2-cli-command`** — generates a Magento 2 CLI command or cron job: command class, `di.xml` registration, and (for cron) `crontab.xml`.
- **New skill `magento2-message-queue`** — generates a full async message-queue surface on an existing module: typed topic DTO + interface, publisher, idempotent consumer, and all five queue XML files (`communication.xml`, `queue_topology.xml`, `queue_publisher.xml`, `queue_consumer.xml`).
- **New skill `magento2-static-analysis`** — action skill running the full static quality gate (PHPCS Magento2 standard, PHPStan level 8, PHPMD, optional php-cs-fixer / rector) with a mandatory Phase-2 approval gate before any auto-fix is applied; emits ranked findings as Markdown + JSON (`outputKind=quality`) + SARIF via the shared emitters.
- **New skill `magento2-docs-generate`** — generates module technical documentation by extracting public API surfaces, extension points, DI graph, templates, and cron jobs into a structured Markdown technical reference (read-only; writes Markdown only).
- **New read-only agent `magento2-explorer`** — comprehension agent that maps a module's execution paths, extension points, and DI graph before an `X*` (modify) task; dispatched automatically by `magento2-feature-implement` when needed.
- **`OUTPUT_KIND=quality`** — new `outputKind` value in the shared findings emitters (`emit-json.sh` / `emit-sarif.sh`), used by `magento2-static-analysis` for its quality-gate findings.

### Changed

- **`magento2-feature-implement` 2.8.0 → 2.9.0** — gained four new task types: `I*` (extension point → delegates to `magento2-extension-point`), `C*` (system config → delegates to `magento2-system-config`), `L*` (CLI command/cron → delegates to `magento2-cli-command`), `Q*` (message queue → delegates to `magento2-message-queue`). The `V*` (Validate) quality-gate task now delegates to `magento2-static-analysis` when present (falls back to inline tool invocations otherwise). Skill count **20 → 26**.

## [1.10.2] — 2026-06-18 — per-skill version registry sync (no functional change)

Provenance-only patch. The per-skill version bumps that accompany the [1.10.1] audit-remediation fixes were committed to `main` **after** the `v1.10.1` tag was cut, so this release formalizes them in a tagged release rather than force-moving the already-published `v1.10.1` tag. **No skill behaviour changed since 1.10.1** — this release exists purely so the tagged history and the per-skill provenance registry agree.

### Changed

- Synced `skills/magento2-context/references/skill-versioning.md` (the per-skill version registry) and the `<skill>@<version>` pins it governs to the 1.10.1 remediation: `magento2-context` → 1.6.1, `magento2-module-create` → 1.7.1, `magento2-module-review` → 2.3.1, `magento2-deploy` → 1.2.1, `magento2-security-audit` → 1.2.1, `magento2-test-generate` → 1.1.2, `magento2-eav-attribute` → 1.2.1, `magento2-graphql-create` → 1.0.3, `magento2-release` → 1.1.1, `magento2-adminhtml-listing` → 1.0.1. Skills whose 1.10.1 changes were doc-only (`magento2-i18n`, `magento2-debug`, `magento2-performance-audit`, `magento2-feature-implement`) were intentionally not bumped.

## [1.10.1] — 2026-06-18 — audit remediation: bug fixes, drift cleanup, regression guards

Correctness pass from an internal optimization & bug-hunt audit. No new skills or user-facing features — existing generators/scripts now produce correct output, and the reference docs match the implementation.

### Fixed

- **`magento2-graphql-create`** — schema fragment no longer declares `status`/`created_at` as non-null when no resolver returns them (was a runtime "Cannot return null for non-nullable field" on a valid query).
- **`magento2-module-create`** — admin Save controller loads the record by id on edit instead of always inserting a duplicate, and stashes failed-save input in the data persistor.
- **`magento2-deploy`** — smoke test checks each module against `module:status --enabled` (was a single alternation over the combined enabled+disabled output → false pass on disabled/partial deploys); production pre-flight now enforces the documented branch-match guardrail (`main`/`master`/`release/*`, `PROD_BRANCH` override, detached-HEAD aware).
- **`magento2-release`** — the workflow renders the release-notes file before `gh release create` consumes it via `--notes-file` (Phase 6 previously pointed at a path nothing created).
- **`magento2-eav-attribute`** — category/customer-address patch classes match their output filename (`Add{AttributeCode}Attribute`), fixing a PSR-4 autoload break.
- **`magento2-test-generate`** — REST API test service name uses PascalCase `{Vendor}` (was a lowercase token → unresolvable SOAP service); coverage-gap no longer double-counts classes under nested type dirs (e.g. `Model/Resolver`).
- **`magento2-module-review`** — emitted JSON includes the schema-required `scanner_errors` field; the grep evidence fallback also scans `.phtml` (the XSS surface) when ripgrep is absent.
- **`magento2-security-audit`** — CVE version ranges include `-pN` patch builds at the upper bound (was a false negative on patched installs); emitted `category` values use the shared schema vocabulary; the secret scan covers `app/etc/env.php` (the crypt key).
- **`magento2-context`** — added the documented composer.json vendor fallback (letters-only, most-frequent `{name}/module-*` prefix; non-letter vendors fall through to the user prompt); SKILL.md cache-key and tools-schema docs now match the resolver.
- **`magento2-i18n` / `magento2-debug` / `magento2-feature-implement`** — reference docs corrected to match the implementation (separate `<locale>.obsolete.csv`, slow-log path resolution, removal of the dead raw-CDP backend, harness model-name commit trailer).

### Changed

- Hoisted duplicated content to shared references to prevent drift: `magento2-module-create`'s naming reference is now a pointer to the canonical `naming.md`; the audit skills point to the shared severity scale and their own calibration references instead of inlining (and drifting from) them.
- `magento2-module-create` admin layouts and the listing layout now match the specialist skills — no storefront-only `<update handle="styles"/>`, and the grid uses `admin-1column`.

### Added

- Two contract tests guarding the fixed bug-classes: emitter **schema-conformance** (locks the `scanner_errors` fix) and GraphQL **resolver field-coverage** (locks the non-null-field fix). The suite is now 35 tests.

## [1.10.0] — 2026-06-17 — `magento2-webapi-create` REST/Web-API skill + review/audit subagent

### Added

- **New skill `magento2-webapi-create`** — contract-first REST / Web-API generator (the 20th skill), sibling to `magento2-graphql-create`. Generates `webapi.xml` CRUD routes + optional custom-action routes, the `Api/{Entity}RepositoryInterface` service contract + `Api/Data` DTO/search-results interfaces, a full `{Entity}Repository` (`SearchCriteria` via `CollectionProcessor`), `di.xml` preferences, `acl.xml`, and a `WebapiAbstract` functional test. Goes beyond `magento2-module-create`'s webapi stubs with per-route auth scopes (anonymous/self/ACL), exception→HTTP mapping, extension attributes, and SearchCriteria pagination. Assumes the entity model exists (`magento2-module-create`'s job). 8 templates, 6 references.
- **Review/audit subagent** — `agents/magento2-reviewer.md`, a read-only first-party agent for
  Magento module review (whole-module or a single dimension: architecture / security / frontend /
  testing / performance). `magento2-module-review`'s parallel-review now prefers it (falling back to
  the generic `claude` type when absent), so the parallel-review story is self-contained instead of
  depending on a generic agent. Pinned by `tests/test-agent-routing.sh` (valid frontmatter,
  read-only tools, resolvable references).

### Changed

- README / getting-started "first steps" examples now use the `/magento2-tools:<verb>` command
  shortcuts (`:snapshot`, `:perf`, `:deploy`) instead of the long-form skill invocations.

## [1.9.0] — 2026-06-17 — slash-command shortcuts, routing disambiguation, release automation, `magento2-adminhtml-listing`

### Added

- **New skill `magento2-adminhtml-listing`** — adminhtml UI-component grid/listing generator (the 19th skill), sibling to `magento2-adminhtml-form`. Declarative `ui_component/{entity}_listing.xml` + DataProvider (AbstractDataProvider default; optional SearchResult), columns, actions column, and mass actions, wired to an existing edit form. Bakes in the 5-place listing naming contract (the empty-grid pitfall). 12 templates, 9 references, `verify-listing.sh`.
- **Slash-command shortcuts** — a `commands/` surface with 9 thin pass-through commands
  (`/magento2-tools:context|snapshot|review|security|perf|deploy|bugfix|feature|release`) that
  forward arguments verbatim to the matching skill. Read-only commands are auto-invokable; the
  four write commands (`deploy`/`bugfix`/`feature`/`release`) are user-only
  (`disable-model-invocation: true`) and never weaken a skill's approval/production gates.
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.
- **Routing disambiguation** — tightened `description` frontmatter on `magento2-feature-implement`
  (negative guard toward narrower skills), `magento2-module-review` / `magento2-security-audit`
  (scope boundary), `magento2-debug` / `magento2-performance-audit` (read-only inspection vs
  severity-ranked findings), `magento2-module-create`, and `magento2-eav-attribute` ↔
  `magento2-data-migration` (cross-references), so natural-language requests route to the right
  skill. The `/context` and `/snapshot` command descriptions note explicit-intent use. Pinned by
  `tests/test-routing-discriminators.sh`. Routing metadata only — no skill-version or behaviour
  change.
- **Release automation** — `.github/workflows/release.yml` publishes a GitHub Release when a `v*`
  tag is pushed: it runs the contract suite, asserts the tag matches `plugin.json` +
  `marketplace.json`, and uses `scripts/release-notes.sh` to extract the matching CHANGELOG section
  as the release notes. Version bump / CHANGELOG / tag stay manual. CI/infra only — no skill change.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy

### Added

- **`.docs/` path-guard hook** — a `PreToolUse` hook (`hooks/guard-docs-path.sh`, registered
  in `hooks/hooks.json`) that blocks `Write`/`Edit` of a `.docs/` artifact anywhere other than
  `{project_root}/.docs/` in a detected Magento project, enforcing the `magento2-context`
  artifact-location rule mechanically instead of by prose. No-op in non-Magento repos and on
  any uncertainty (fails open; no escape hatch). Pure matcher in `hooks/docs-path-matcher.sh`;
  contract test `tests/test-docs-path-guard.sh`. Plugin-level — no skill-version-registry change.
- **Golden-render tests for the shared findings emitters** — `tests/test-golden-emitters.sh`
  pins the full output shape of `emit-json.sh` and `emit-sarif.sh` against checked-in golden
  files under `tests/golden/`, so any regression in the emitted JSON/SARIF structure fails
  loudly (the prior field-probe test only checked three fields). The `runAt` timestamp is
  normalized; regenerate the goldens with `UPDATE_GOLDEN=1`. Test-only.
- **Process-skill deferral policy** — new `skills/magento2-context/references/process-skills.md`
  defines when a `magento2-*` orchestrator may defer to a generic session process skill (and when
  it must not); `magento2-feature-implement` and `magento2-bug-fix` point at it.
- **`LICENSE`** — the MIT license text the manifest already declared.
- **`tests/test-skill-count-consistency.sh`** — pins every "N skills" claim in the README/docs to
  the actual skill count; the bash-syntax test and CI shellcheck now also scan `hooks/`.

### Fixed

- Skill-count drift in the README and developer docs (now consistently **18 skills**).

### Changed

- Enriched `.claude-plugin/plugin.json` metadata (added `category`, broadened `keywords`).

## [1.7.0] — 2026-06-16 — `magento2-adminhtml-form`: adminhtml UI-component form generator

### New skill: `magento2-adminhtml-form` 1.0.0

Generator for adminhtml UI-component edit forms — fills the admin-forms gap between
`magento2-module-create` (basic admin stub) and `magento2-frontend-create` (storefront-only). The
team's recurring pain point: hand-rolling a new admin edit form and hitting silent "blank form" /
"save does nothing" failures.

- Declarative `view/adminhtml/ui_component/{entity}_form.xml` + `DataProvider`
  (`AbstractDataProvider` + `DataPersistorInterface`, `getData()` keyed by entity id) +
  New/Edit/Save/Delete controllers + the required button blocks, wired to an existing listing.
  Optional modifier/Pool, WYSIWYG, toggle, dynamic-rows, and image/file uploader surfaces.
- 17 templates, 10 reference docs, `scripts/verify-form.sh`. Built test-first: a RED baseline
  captured an unaided agent's failure modes, the templates were written to eliminate exactly those,
  and GREEN was verified via the repo template-lint harness (`php -l` + `xmllint` on every template).
- Bakes in the five-name blank-form **naming contract**, flat-post Save (empty id → `null`),
  `acl.xml` **without** the invalid `translate` attribute, canonical WYSIWYG/toggle fields, and
  Open-Source-vs-Adobe-Commerce gating (content staging / B2B / Page Builder).
- Registered in `skill-versioning.md` (1.0.0) and the README skills table (now 18 skills). Shipped
  in plugin **1.7.0** — `plugin.json` / `marketplace.json` bumped 1.6.0 → 1.7.0.

## [1.6.0] — 2026-06-16 — Plan vs. task-record split in the feature orchestrator

### `plan.md` / task-record de-duplication (`magento2-feature-implement` 2.7.0 → 2.8.0)

The execution plan and the detailed task records no longer overlap. `plan.md` is now strictly the
resumable **index** — Mermaid diagrams, the `## Current State` checklist, the Smoke Iterations
block, and the summary table. The **detailed task records** (type, target, dependencies, included
changes, risks, acceptance criteria) live only in `tasks.md` (≤ 5 tasks) or `tasks/` (> 5 tasks).

- The `templates/task-list.md` template was renamed to `templates/plan.md` (index only); a new
  `templates/task-record.md` holds the detailed records.
- Records are now written **before** the Phase 4 approval gate, alongside `plan.md`, so the user
  reviews the full task detail before approving. The previous "records written only after approval"
  carve-out is removed — `plan.md` and the task records both follow one save-before-present rule,
  and on a change-request both are revised in sync.
- New placeholder tokens `{ID}` / `{NNN}` / `{kebab-title}` registered in `placeholder-schema.md`.
- Version bumped in the three emitting templates (`feature-blueprint.md`, `plan.md`,
  `final-report.md`).

## [1.5.1] — 2026-06-15 — Docs: test-first discipline across the developer docs

Documentation-only release. Developer docs under `docs/` now cover the v1.5.0 test-first
changes. No skill, template, or behaviour changes — skill versions are unchanged.

- **Configuration** — documents the `MAGENTO2_FI_TDD` env var and the
  `Feature implement: tdd = on` `CLAUDE.md` hint.
- **Skills reference** — `--tdd` opt-in on `magento2-feature-implement`; the
  `magento2-data-migration` and `magento2-eav-attribute` phase lists now show the
  test-first RED→GREEN steps; `tdd-discipline.md` listed among the shared `magento2-context`
  references; `magento2-test-generate` framed as the backfiller for existing code.
- **Flows and scenarios** — test-first added to the shared-infrastructure list and the
  feature-implementation flow; new **Test-first builders (data-migration, eav-attribute)**
  section with a red → green → refactor diagram; a TDD note in Scenario 1.
- **Daily workflows / New project guide / Getting started** — TDD-mode recipe, test-first
  EAV/data-patch recipes, backfiller-vs-test-first framing, and a house-style safety note.

## [1.5.0] — 2026-06-15 — Test-first discipline widened across the build flow

Test-driven development moves from a single skill (`magento2-bug-fix`) to a shared, opt-in
discipline used by the feature orchestrator and the data/EAV builders. Tests for behaviour are
now written *before* the code, watched to fail, then turned green — instead of generated after.

### Shared test-first discipline (`magento2-context` reference — no version bump)
- New `skills/magento2-context/references/tdd-discipline.md` defines the red → green → refactor
  loop, the **behaviour/boilerplate line** (what is written test-first vs. exempt scaffold/config),
  the interface-first seam for bulk-scaffolded code, Magento unit/integration specifics, and a
  tiered fallback when no test DB is available. `magento2-bug-fix` now points at it as the single
  source instead of owning the prose.
- `magento2-context` is **not** version-bumped: adding a cross-cutting reference doc does not
  change its resolved JSON/schema/probes.

### Opt-in TDD mode for the orchestrator (`magento2-feature-implement` 2.6.0 → 2.7.0)
- New **TDD mode** — `--tdd` (also `CLAUDE.md: Feature implement: tdd = on` / `MAGENTO2_FI_TDD=1`),
  default **off**, `spike` mode always exempt. New `references/tdd-mode.md`.
- Phase 5 `M*`/`X*` behaviour-bearing classes are implemented test-first (scaffold signature →
  failing test → minimal body). Phase 4 acceptance criteria become the RED test list. The `T*`
  task becomes a coverage top-up rather than the first author of behaviour tests.

### Test-first data patches (`magento2-data-migration` 1.1.1 → 1.2.0)
- Phase 2 is now **Test First, then Generate**: a failing integration test asserts post-migration
  state **and idempotency** (apply twice → identical) before the patch body; tiered unit fallback
  when no test DB is available; Phase 3 runs the test; new acceptance criterion + test path in the
  report.

### Test-first EAV attributes (`magento2-eav-attribute` 1.1.2 → 1.2.0)
- Phase 3 is now **Test First, then Generate**: a failing integration test asserts the attribute's
  scope/input-type/wiring **and** idempotency before the patch; behavioural source/backend models
  get a test-first unit test; new acceptance criterion + test path in the report.

### Unchanged by design
- `magento2-test-generate` keeps its role as the backfiller for modules that have **no** tests.
- `magento2-module-review` gains no test-first gate, so it stays usable on test-less modules.

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
