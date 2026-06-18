# magento2-tools — Skills Optimization & Bug-Hunt Audit

**Date:** 2026-06-18
**Scope:** All 20 skills + shared infrastructure (context resolver, hooks, scripts, the review subagent, command shortcuts).
**Focus (as requested):** optimization + bug hunting only. **No scope-extension / new-feature suggestions.**
**Method:** 6 parallel deep-read auditors (one per skill cluster), each barred from re-reporting anything the 33-test contract suite already covers; every High/Critical finding below was re-verified by reading the offending source line.

---

## 1. Executive summary

The plugin is **mature and well-engineered**: a clean hub-and-spoke design around `magento2-context`, a green 33-test contract suite, golden-file emitters, portable shell (BSD/macOS fallbacks, atomic cache writes), and genuinely shared disciplines (TDD loop, JSON/SARIF emitters) that are *referenced* rather than copied. The defensive posture is real — e.g. the docs-path guard fails **open** on every uncertain branch.

The weaknesses cluster into **five recurring root causes**, not 50 unrelated defects. Fixing the root causes clears most of the list:

| # | Root cause | Representative impact | Bugs it explains |
|---|------------|----------------------|------------------|
| R1 | **Two-copy template drift** — `module-create` keeps its own admin/eav/webapi templates that duplicate *and diverge from* the specialist skills | A module scaffolded by `module-create` then extended by `adminhtml-form`/`-listing` gets inconsistent route-id, ACL, primary-key and a Save controller that duplicates rows | C1-adjacent, H1, H2, H8, O-dup |
| R2 | **Reference-vs-implementation drift** — references describe behaviour the scripts don't implement; the test suite checks *path existence + lint*, never *semantic agreement* | Agents follow a reference that contradicts the (correct) code, re-introducing the very bug the code avoids | i18n-csv, vendor-step3, raw-CDP, branch-guard, slow-log, slow_query |
| R3 | **Inlined shared content** — severity scale, findings schema, naming, coding-style, TDD, docs-path repeated inline instead of cited | Token cost in always-loaded SKILL.md + guaranteed drift | ~325+ hoistable lines |
| R4 | **Placeholder-token hygiene** — case mismatches, space-containing tokens, class-name≠filename | Generated code that won't autoload or won't resolve a service; invisible to the token-lint test | C1 partial, H8, H15, M-eav-label |
| R5 | **Hard-pinned version strings** — `magento2-context@1.6.0` and per-skill versions hand-written in ~17 files; the plugin actually versions as a whole at 1.10.0 | Fictional, drifting version numbers in emitted artifacts | L-version × many |

**Headline counts:** 1 Critical · ~15 High · ~20 Medium · ~20 Low bugs; ~325+ lines of hoistable duplication; ~1,870 tokens of session-loaded routing metadata (trimmable on the 2-3 heaviest skills).

---

## 2. Bugs

Severity reflects impact on **generated output** or **report consumers**. `✅ verified` = I re-read the source line and confirmed.

### 2.1 Critical

| ID | Skill | File:line | Finding | Fix |
|----|-------|-----------|---------|-----|
| **C1** ✅ | graphql-create | `templates/schema-fragment.graphqls:20-21` vs `templates/{query,mutation,paginated,batch}-resolver.php` | Schema declares `status: {Entity}Status!` and `created_at: String!` **non-null**, but every resolver returns only `['id'=>…, 'name'=>…]`. Any client selecting `status`/`created_at` → runtime *"Cannot return null for non-nullable field."* The graphql-shape test only checks brace balance, so it passes. | Either make the two fields nullable in the schema, or add `'status' => $entity->getStatus()` and `'created_at' => $entity->getCreatedAt()` to all four resolver return arrays. |

### 2.2 High

| ID | Skill | File:line | Finding | Fix |
|----|-------|-----------|---------|-----|
| **H1** ✅ | module-create | `templates/admin-controller-save.php:57-59` | Save always does `entityFactory->create()` + `setName(...)` and **never loads by id** → editing an existing record creates a duplicate. (The `adminhtml-form` skill does it correctly via load-by-id + `setData`.) | Port the form skill's `$id = (int)($data['{entity}_id'] ?? 0); $model = $id ? getById($id) : create();` + `setData($postData)` pattern. |
| **H2** ✅ | adminhtml-form / -listing | form `routes.xml:11` (`id={vendor_lower}_{entity}`) vs listing `routes.xml:5` (`id={vendor_lower}_{module_lower}`); form `acl.xml:15` (`::{entity}`) vs listing `acl.xml:15` (`::main`) | The two skills are *designed to pair* but register **different route ids and ACL resources**. When `{entity} != {module_lower}` (e.g. `Acme_Catalog`/`Product`), the form's `*/*/` redirects + `menu.xml` link target a route the listing never registers, and the two cite unrelated ACL resources. | Standardize both on one route id (`{vendor_lower}_{module_lower}_{entity}`) and one ACL convention; update menu `action`, form `submitUrl`, layout-handle filenames, and `ADMIN_RESOURCE` to match. |
| **H3** | adminhtml-form | `templates/menu.xml:17` | Menu points at `…/{entity}/index`, but the form skill only generates New/Edit/Save/Delete (Index belongs to the listing skill) → standalone form's menu link 404s. | For standalone forms point the menu at `…/{entity}/new`; emit `/index` only when a paired listing exists. |
| **H4** ✅ | deploy | `scripts/smoke.sh:32` | `module:status \| grep -qE "$(echo "$MODULES" \| tr ' ' '\|')"` — `module:status` prints **both** enabled *and disabled* lists, and the alternation passes if **any one** module matches. A disabled or partially-deployed module still reports `pass`. | Use `module:status --enabled` and loop `grep -qx "$mod"` per module; fail if any is missing. |
| **H5** ✅ | release | `SKILL.md:91` consumes `--notes-file .docs/releases/{Module}-{Version}.md`; no phase writes it | Phase 6 (`gh release create --notes-file …`) points at a file **no workflow phase generates** → every GitHub release fails. The template exists (`templates/release-notes.md`) but is never rendered. | Add a step at end of Phase 3 (or a 5.5) that renders the template from classified commits to that path before Phase 6. |
| **H6** ✅ | feature-implement | `references/per-task-commits.md:102` | Hard-codes `Co-Authored-By: Claude Opus 4.7` — directly contradicting the file's own line-14 rule *"do not hard-code … a fixed model name … both drift"*, and already stale. | Replace with the placeholder form from the sibling `commit-format.md`: `Co-Authored-By: {current Claude model, per the harness convention} <noreply@anthropic.com>`. |
| **H7** | feature-implement | `scripts/smoke-browser.mjs:111` (only call site) | `smoke-runner.md:87` + `smoke-test-guide.md:39` promise *"any HTTP ≥ 500 is a Critical finding"* for browser suites, but `captureNetworkErrors()` is called **only** in `adminLogin`. `storesConfigWalk`, `gridProbe`, `visit`, `customerFlow` only check console errors → a 5xx on a navigable page is silently passed. | Call `captureNetworkErrors()` at the start of each browser command and fold `netErrors.length === 0` into each ok/exit computation. |
| **H8** | eav-attribute | `templates/eav-add-category-attribute-patch.php:18`, `…-customer-address-attribute-patch.php:17` | Class names `Add{AttributeCode}CategoryAttribute` / `…AddressAttribute`, but `SKILL.md:20,77,139` uniformly names the output file `Add{AttributeCode}Attribute.php`. PSR-4 class↔file mismatch breaks autoloading (product/customer copies are correct). | Rename both classes to `Add{AttributeCode}Attribute`, or have the SKILL name the file after the class. |
| **H9** ✅ | module-review | `scripts/emit-json.sh:158-160` | The emitted `document` has `skipped`/`tools` but **no `scanner_errors`**, which `findings-schema.md:136` marks **Required**. security-audit/perf inject it via `build-findings.sh:145`; module-review has no such step → its JSON is schema-invalid. | Read optional `SCANNER_ERRORS_FILE` (default `[]`) and add `'scanner_errors': scanner_errors`. |
| **H10** | module-review | `scripts/collect-evidence.sh:35` | grep fallback is `--include='*.php'` only; the `rg` branch (line 33) includes `.phtml`. On hosts without ripgrep, the escaping/XSS scan silently misses **every template** — the highest XSS-risk surface. | Add `--include='*.phtml'` to the grep fallback. |
| **H11** ✅ | security-audit | `scripts/cve-scan.sh:106` | `return lo <= cur <= hi` with patch padded to 0: upper bound `2.4.7` parses to `(2,4,7,0)`, so `2.4.7-p1`=`(2,4,7,1)` is **excluded**. A range `"2.4.0 - 2.4.7"` misses all `-pN` patch builds — a false negative on the most-patched installs. | Treat an upper bound with no explicit `-pN` as `+∞` patch (or compare `(2,4,7)` tuples for the bound). |
| **H12** | security-audit | `cve-scan.sh:352` (`'magento-cve'`), `cross-module-scan.sh:109` (`'preference-collision'` for a cron collision) | Emitted `category` values are off the shared vocabulary (`findings-schema.md:149-150` → `cve`, `cron-ownership`) → corrupts `byCategory` aggregation. | Map to schema category names. |
| **H13** | security-audit | `scripts/secret-scan.sh:13`, `build-findings.sh:25` | Scanner defaults to `app/code`, but `secret-patterns.md:58-61` scopes secrets to `app/etc/env.php`, composer files, `.env.example`. `env.php` (the crypt key — highest-value secret) is outside `app/code`, so `magento-crypt-key` can **never fire by default**. | Scan from Magento root, or add `app/etc` to the default roots. |
| **H14** | test-generate | `scripts/coverage-gap.sh:35-36,52` | Walks `('Model/Resolver',…)` then `('Model',…)`; `os.walk('Model')` recurses into `Model/Resolver`, so each resolver (and `Api`/`Api/Data`) is counted **twice** → inflated/duplicated gap list. | Prune already-covered subdirs, or dedupe by source path. |
| **H15** ✅ | test-generate | `templates/test-api-rest.php:12` | `SERVICE_NAME = '{vendor}{Module}{Entity}RepositoryV1'` uses the **lowercase** `{vendor}` token (line 5 correctly uses `{Vendor}`) → `acme…RepositoryV1`, so `_webApiCall`'s SOAP leg can't resolve the service. | Use `{Vendor}`. |
| **H16** | i18n | `references/csv-format.md:37-52` | Documents an **in-line `"# OBSOLETE …",""` CSV row** + an "active rows alphabetically" claim that contradict the (correct) implementation: `merge-csv.sh` writes obsolete phrases to a *separate* `<locale>.obsolete.csv` "because Magento's loader does not tolerate comments inside the CSV," and preserves order. Anyone following the reference re-introduces a live bogus translation key and re-sorts the file. | Rewrite the "Comments / Obsolete" + "Sorting" sections to describe the separate `.obsolete.csv` file and preserve-order/append-new behaviour the scripts actually use. |

### 2.3 Medium

| ID | Skill | File:line | Finding | Fix |
|----|-------|-----------|---------|-----|
| M1 ✅ | bug-fix | `SKILL.md:67,89,107,124,…` | `{slug}` is the join key between branch (`bugfix/{slug}`) and every artifact path + RCA Bug ID, but **no phase defines how to derive it** (only an example in `commit-format.md`). Different phases can derive different slugs → branch/artifacts diverge. | In Phase 0 add: *"Derive `{slug}` = `{YYYY-MM-DD}-{kebab symptom}`; reuse for the branch and all `.docs/bug-fixes/{slug}/` paths."* |
| M2 | deploy | `references/pre-flight-checks.md:75-81` vs `scripts/preflight.sh` | The documented production guardrail *"branch matches production target"* is **not implemented** — `preflight.sh` does git-clean/composer-dryrun/maintenance only. A production deploy from a feature branch passes pre-flight. | Implement the `rev-parse --abbrev-ref` branch check, or remove it from the doc. |
| M3 | deploy | `scripts/smoke.sh:32,38` | Uses `eval "$MAGENTO_CLI …"`, regressing from the array word-split pattern `extract.sh`/`preflight.sh` deliberately use ("instead of re-splitting via eval which mangles paths"). | Mirror the `cli_argv=($MAGENTO_CLI)` array pattern. |
| M4 | release | `SKILL.md:44-46` vs `references/semver-rules.md:8-11` | SKILL recognizes only `feat:`→minor / `fix:`→patch / `BREAKING`→major; the reference also maps `perf:`/`refactor:`→patch and `fix!:`→major. A release of only `perf:`/`refactor:` commits is wrongly classified "no releasable changes." | Make Phase 1 point to / match the full `semver-rules.md` table. |
| M5 | eav-attribute | all four `eav-add-*-patch.php` (`:55/:64/:55/:59`) | `'label' => '{Attribute Label}'` — a **space-containing token** the lint grammar (`[A-Za-z][A-Za-z0-9_.-]*`) can't see and the registry doesn't contain → a registry-keyed substitution leaves literal `{Attribute Label}` in generated code. | Use a registered spaceless token (e.g. `{AttributeLabel}`) and add it to the registry. |
| M6 | graphql-create | `SKILL.md:68,73,97` | Lists "wire DI in `etc/graphql/di.xml`" as a generate/verify/output step, but there is **no di.xml template** and `n-plus-one-prevention.md:88`/`resolver-patterns.md:150` both say *"No di.xml entry is needed"* (resolvers wired via `@resolver`). | Drop the step, or gate it on "only when the resolver constructor needs configuration." |
| M7 | data-migration | `templates/import-cli-command.php:57-61` vs `SKILL.md:93-94` | `--dry-run` returns `['dry_run'=>true,'source'=>…]` and imports nothing meaningful; the SKILL claims it "outputs what would be imported." | Soften the SKILL text, or add a real `dryRun()` counting insert-vs-skip without writing. |
| M8 | context | `scripts/resolve-context.sh:25,350,380` | File-path vars are spliced raw into single-quoted PHP literals (`file_get_contents('$file')`, `include '$CONFIG_PHP'`). Paths derive from `M2_MAGENTO_ROOT` / `.claude/m2.json`; a value with a `'` breaks the literal — and line 350's `include` is an arbitrary-file-include. Config-injection, not remote, hence Medium. | Pass paths via argv: `php -r '... $f=$argv[1]; ...' -- "$file"` (and `include $argv[1]`). |
| M9 | context | `references/vendor-resolution.md:20-24,47` vs `scripts/resolve-context.sh:130-156` | Reference promises a step-3 composer.json package-name fallback + regex `^[A-Z][a-zA-Z]{1,49}$`; script implements only CLAUDE.md + module-dir scan and validates `^[A-Za-z]+$`. Script emits `vendor:null` where the doc says composer.json resolves it. | Add the composer.json fallback, or downgrade the doc step to "ask the user" and align the regex. |
| M10 | adminhtml-form / -listing | listing `listing.xml:25,…`, `column-actions.php:51,…`; form `form.xml:45-46`, `controller-save.php:88` | Primary key hard-coded as `{entity}_id` although both SKILL Phase-1 tables advertise *"Primary key column"* as overridable. A real PK of `id`/`page_id`/etc. makes every `indexField`/`requestFieldName`/URL param resolve wrong → broken edit/delete. | Add a registered `{primary_key}` token (default `{entity}_id`) and substitute everywhere the PK appears. |
| M11 | adminhtml-listing | `templates/controller-mass-status.php:53-54`, `controller-mass-delete.php:50` | Mass actions call deprecated `Model::save()`/`delete()` directly, no try/catch; `AbstractModel::save()` is `@deprecated` since 2.4 and bypasses repository plugins — one throwing row aborts the batch silently. `references/mass-actions.md` documents the fix the template doesn't apply. | Inject the repository/resource model; wrap each row in try/catch with counters. |
| M12 | module-create | `templates/admin-ui-form-data-provider.php:65` vs `admin-controller-save.php` | DataProvider reads `dataPersistor->get(...)` to repopulate a failed save, but the Save controller **never calls `dataPersistor->set(...)`** on failure → failed-save input is always lost. | Stash `$postData` via `dataPersistor->set(...)` in the Save catch block, same key the DataProvider reads. |
| M13 | feature-implement | `scripts/smoke-tail-since.sh:92` | On log rotation, `tail -c +"$((BASE_SIZE+1))" "$ROTATED"` slices `exception.log.1` at the *live file's* baseline offset, which has no meaning in the rotated file → new lines dropped or pre-baseline lines re-included. | Dump the rotated `.1` from byte 0 (all of it is "since baseline" relative to the new live file), annotated. |
| M14 | feature-implement | `references/smoke-runner.md:62,96` | Still presents the **removed** raw-CDP backend as a working third path, while the same file (`:21,:25`) and the script (`smoke-browser.mjs:400-416`) say it was removed ("fake-passed"). File contradicts itself. | Drop "/raw-CDP" at `:62`; replace the `google-chrome → raw CDP` line at `:96` with `else → exit 78`. |
| M15 | module-review | `scripts/emit-json.sh:149-153` vs `SKILL.md:142`, `diff-mode.md:41` | `target.diffRef` is promised in diff mode but never emitted (target has only module/path/scope). | Read `DIFF_REF` and add `target.diffRef` conditionally. |
| M16 | performance-audit | `static-perf.sh:89` | N+1 `REPO_CALL` regex requires a literal `Repository` token, so `$this->productRepo->get($id)` (the skill's own example uses `repo`) is missed; pre-warmed loops falsely flagged. | Broaden receiver to `\w*[Rr]epo\w*`. |
| M17 | performance-audit | `static-perf.sh:97` | Full-collection detection only matches chained `getCollection()->getItems()`; the dominant `$c=$factory->create(); foreach($c …)` form (claimed flagged by `perf-checklist.md`) is missed. | Add a `getCollection()`/`Factory->create()`-iterated-without-`setPageSize` heuristic. |
| M18 | performance-audit | `references/perf-checklist.md:63`; perf `SKILL.md` Phase 3 | Off-schema category `other`; and `slow_query` is advertised but **no check produces it** (`runtime-checks.sh` has no slow-log probe). | Map `other`→a real category; add the slow-log probe or drop the claim. |
| M19 | debug | `SKILL.md:174` | "DI collisions → magento2-security-audit" mis-routes an architecture/correctness concern; the natural owner is `magento2-module-review`. | Route DI collisions to module-review. |
| M20 | debug | `references/slow-query-patterns.md:5-7` vs `SKILL.md:81` | Hardcodes `cat /var/log/mysql/slow.log` though the path is configurable and varies across MySQL/MariaDB/Docker. | Resolve via `SHOW VARIABLES LIKE 'slow_query_log_file'` first. |
| M21 | test-generate | `templates/test-api-rest.php:18-19`, `test-api-graphql.php` | Assert `id === 1` with **no `@magentoDataFixture`** → fails on an isolated empty DB. | Add a data fixture seeding the asserted entity. |
| M22 | test-generate | `references/test-types.md:42-54` | Promises 401/403/400 + GraphQL pagination tests no template generates (templates emit only 200+404 / shape+input-error). | Ship those methods or align the prose. |

### 2.4 Low (condensed)

- **context `B2`** — `resolve-context.sh:222-231`: the bare `docker ps` name-pattern fallback attaches an *unrelated* project's container as the runner (reproduced in this repo: `runner: docker exec -i mageos-php`). Gate it on a Magento marker (`$LOCK_FILE`/`bin/magento`/`$MODULE_DIR`), like `probe_vendor_tool` already does.
- **context `B3`** — `hooks/docs-path-matcher.sh:23-36`: a write to a file *literally named* `.docs` (basename, not a dir) is denied. Add `case "$path" in */.docs) allow ;; esac`.
- **context `B4`** ✅ — `SKILL.md:89-103` tools schema lists 13 keys; `resolve-context.sh:492-508` emits 15 (adds `php-cs-fixer`, `gh`). Add both to the documented schema.
- **deploy** — `references/rollback-recipes.md:34` calls `./scripts/restore-snapshot.sh` which **doesn't exist** (real restore steps are inlined at `:104-111`). Replace the dead call.
- **adminhtml** — `verify-form.sh`/`verify-listing.sh` write to fixed `/tmp/xmllint.err` (concurrent-run clobber, predictable temp); use `mktemp` + trap.
- **adminhtml-form** — `form.xml:85-107` `is_active` toggle has no default `<value>` → new records render off, risking a NOT NULL violation.
- **frontend-create** — `email_templates.xml:8` uses `{Vendor}_{ModuleName}` while everything else uses `{Module}` → `{ModuleName}` left unsubstituted; `_extend.less:7` re-imports `lib/_lib.less` (double-import in a Luma child theme); `ko-ui-component.js` template/install-path ambiguity vs `ko-component-patterns.md:57`.
- **i18n** — `validate-csv.sh:45` treats `%s` and `%1` as different placeholders although `placeholder-rules.md:18` says Magento's `Phrase` translates `%s`→`%1` → false "mismatch." Normalize before comparison.
- **data-migration** — `importer-service.php:99-102` aborts every row (100% failed) if the CSV lacks the `unique_key` column, with no clear cause; `data-patch-transformation.php:88` stamps `date('Y-m-d H:i:s')` (PHP local time) instead of DB `NOW()`.
- **module-create** — admin layouts use `admin-2columns-left` + `<update handle="styles"/>` which the specialist skills forbid (storefront-only / mandates `admin-1column`); literal `entity_id` instead of `{entity}_id`.
- **feature-implement** — `pickBackend()` returns a dead `cdp` branch `openPage()` can't handle (`smoke-browser.mjs:84-85`); `smoke-baseline.sh` depth comment says 3, code uses `-maxdepth 4`; Phase-0 resume routes off `blueprint.md` Status but executes from `plan.md` checkboxes (frontmatter advertises plan.md-only) → desync window.
- **security-audit** — `secret-scan.sh:96` `AKIA[0-9A-Z]{16}` unanchored (matches inside longer blobs → add `\b…\b`); `:115` `password-define` regex misses `define('PW','x' )` (space before paren); `build-findings.sh:163` re-`json.dump` drops `ensure_ascii=False`.
- **performance-audit** — `runtime-checks.sh:32,37,42` `eval "$MAGENTO_CLI …"` (robustness, not injection — config input); drop `eval`.
- **debug** — read-only guarantee **holds** (clean audit), but `plugin-trace.sh:53` `find_xml()` is dead code; `snapshot-format.md:10` mandates a version line `snapshot.sh` never emits.
- **test-generate** — `test-service.php` is `class` not the documented `final class`; `test-js-ko.js:14` uses weak `toBeDefined()` the skill itself forbids; `test-mftf-form.xml` `<after>` lacks the entity cleanup the reference requires.

---

## 3. Optimization

SKILL.md *body* sizes are mostly healthy (175-196 lines); the exception and the duplication are the levers.

### 3.1 Hoist duplicated content to `magento2-context/references` (~325+ lines)

| Area | Where it's duplicated | Action |
|------|----------------------|--------|
| **Naming** | `module-create/references/naming-conventions.md` (~150 lines) is a near-verbatim fork of `context/references/naming.md`, which module-create *itself* calls "authoritative." | Replace the body with a pointer + module-create-only deltas. **Highest single win.** |
| **Severity scale** | Inlined in `module-review/SKILL.md:169-178`, `security-audit/SKILL.md:167-178`, `performance-audit/SKILL.md:153-161`, and the `severity-*.md` example refs (~80 lines, already drifting) | Keep only skill-specific anchors; one-line pointer to `context/references/severity.md`. |
| **Findings JSON/SARIF object** | Re-embedded in `perf-checklist.md:84-96`, `blackfire-integration.md:56-70`, `indexer-health.md:71-79`, `debug/.../slow-query-patterns.md:64-77` (~60 lines) | Show schema-delta fields + pointer to `findings-schema.md`. |
| **test-generate patterns** | Repository round-trip body triplicated; Jasmine/REST patterns re-pasted between refs and templates; coverage prose triplicated (~135 lines) | References should show the *delta*, not re-paste the template. |
| **adminhtml shared rules** | `edition-differences.md`/`pitfalls.md` near-duplicated across the two adminhtml skills; the "declarative UI / acl-no-translate / test-first / coding-style" Core-Rules blocks are near word-for-word in both SKILL.md | Move shared rules to one reference both skills link; keep only form- vs listing-specific deltas. |
| **coding-style + test-first prose** | Copy-pasted (not referenced) into ~7 SKILL.md each, then *also* pointing at the shared ref | Replace the prose with the one-line cross-reference that already follows it. |
| **docs-path one-liner** | Restated in ~11 SKILL.md files; no citable reference exists (only prose in `context/SKILL.md:29-35`) | Extract to `context/references/artifact-location.md` and cite it (mirror `tdd-discipline.md`). |

### 3.2 Trim the one bloated SKILL.md

`magento2-feature-implement/SKILL.md` is **694 lines** (next largest is 268). Safe extractions that keep workflow logic inline:
- Collapse the eight per-task-type subsections (`:371-512`, ~140 lines) into one `TaskType → delegate skill → key rule` table — the invocation strings already live authoritatively in `task-breakdown-guide.md`. **−90 to −110 lines.**
- Move the Phase-6A coverage command blocks (`:556-568`) and the V* quality-quartet block (`:470-482`) to references — pure tool mechanics. **−20 lines.**
- De-triplicate the "Save-before-present" rule (`:35-41`, restated at `:209-213`, `:253-284`). **−8 lines.**
- Single-source the approval-gate prompt (verbatim in `SKILL.md:293-297`, `task-breakdown-guide.md:278-282`, `templates/plan.md:139-140`) and the duplicated flow/dependency Mermaid diagrams.

**Net: ~−120 to −150 lines (~18-22%) with no behavioural loss.**

### 3.3 De-duplicate generator templates (R1)

- `webapi-create/templates/{repository,data-interface,search-results-interface,di}` are near-verbatim clones of `module-create`'s — and webapi's own SKILL says the entity "already exists (created by module-create)." Consolidate the persistence templates; let webapi extend only the webapi.xml/acl.xml/test surface.
- `eav-attribute`'s four patch templates are *acknowledged* near-duplicates of `module-create`'s (`SKILL.md:177-182` defers single-sourcing as a "follow-up") — and they've already diverged (only one copy carries the `getAttribute()` short-circuit; see H8). Single-source them.
- `module-create`'s admin UI templates duplicate the two specialist skills but diverge on PK, route id, layout, and Save correctness (R1) — have the `admin_ui` surface reuse the specialist templates.
- `verify-form.sh` ≈ `verify-listing.sh` (~95% identical) → one shared parameterized `verify-adminhtml.sh`.
- DataPatch idempotency rules restated inline in `eav-attribute/SKILL.md:23-26` + `data-migration/SKILL.md:17-19` → cite `data-patch-rules.md`.

### 3.4 Kill hard-pinned version strings (R5)

`magento2-context@1.6.0` and per-skill versions are literal-pinned in `emit-json.sh:140`, `report-template.md`, `report.html:253`, the feature-implement/module-upgrade templates, etc. — `skill-versioning.md:84` *itself* flags this as a 17-file hazard. The plugin versions as a whole (1.10.0); these per-skill numbers are fictional and rot. Derive from a single `{{SKILL_VERSIONS}}` placeholder/env var, or drop the block.

### 3.5 Routing-metadata token cost (minor)

All 20 `description:` blocks load every session (~1,403 words ≈ **1,870 tokens**). `feature-implement` (137 words — inlines resume-path mechanics) and `module-create` (100) are the heaviest. Trimming the feature-implement description's resume mechanics to a one-liner is the only worthwhile cut; the rest earn their length as routing disambiguators.

### 3.6 Off-schema / dead surfaces to drop

`category: other` (perf), `category: coding-standard` (`eqp-rules.md:59`, schema says `eqp`), `--format=json` advertised by `debug/SKILL.md:134` with no emitter wired.

---

## 4. Documentation–implementation drift (R2) — the highest-leverage class

These are *bugs in disguise*: an agent that trusts the reference over the (correct) code re-introduces the bug. None are caught by the test suite, which checks path existence + lint, never semantic agreement.

| Reference says | Code actually does | Fix target |
|----------------|--------------------|-----------|
| i18n obsolete phrases go in an in-line `# OBSOLETE` CSV row (csv-format.md) | separate `<locale>.obsolete.csv` (merge-csv.sh) | **H16** — rewrite the ref |
| vendor step-3 = composer.json fallback (vendor-resolution.md) | not implemented | M9 |
| raw-CDP is a working backend (smoke-runner.md) | removed (smoke-browser.mjs) | M14 |
| production guarded by branch-match (pre-flight-checks.md) | not implemented | M2 |
| slow log at a configurable path (debug SKILL.md) | hardcoded `/var/log/mysql/slow.log` (ref) | M20 |
| `slow_query` check exists (perf SKILL.md) | no probe | M18 |
| cache key = `lock;json;claude` (context SKILL.md) | `…;m2;env` (resolve-context.sh:85) | O — update docs |
| tools schema = 13 keys (context SKILL.md) | 15 (resolve-context.sh) | B4 |

---

## 5. Test-coverage gaps (why the suite is green despite the above)

The 33 tests validate **path existence, bash/PHP/XML/JS lint, JSON parse, token-registered lint, version-token sync, and emitter goldens** — all structural. They do not check: (a) reference prose vs script behaviour, (b) placeholder *case/registry* correctness inside string literals (so `{vendor}` vs `{Vendor}` and `{Attribute Label}` slip through), (c) GraphQL schema vs resolver field coverage, (d) emitted JSON against the *required-fields* schema, (e) cross-skill route/ACL/PK consistency. Three cheap additions would catch most of this class:
1. **Schema-conformance test** — validate each emitter's golden output against `findings-schema.md` required fields (catches H9, M15).
2. **Placeholder-case test** — assert every `{...}` token in a template exists in the registry *with matching case* (catches H15, M5; the spaced-token gap is already invisible to today's grammar).
3. **GraphQL field-coverage test** — every non-null schema field must appear as a key in at least one resolver return (catches C1).

---

## 6. Per-skill verdict

| Skill | Verdict |
|-------|---------|
| magento2-context | Strongest infra; portable + defensive. Issues are doc drift (B4, M9, cache-key) + two low-reach code paths (M8 injection, B2 cross-project runner). |
| magento2-module-create | Broadest; admin-form surface is the weak spot — duplicate-on-edit Save (H1), half-wired persistor (M12), conventions that drift from the specialists (R1). |
| magento2-adminhtml-form | Internally correct (CSRF, load-by-id Save); defects are external — route/ACL/menu divergence with the listing skill (H2, H3) + hardcoded PK (M10). |
| magento2-adminhtml-listing | Cleanest of the three internally; risks are hardcoded PK (M10) and deprecated, unguarded mass-action `save()` (M11). |
| magento2-webapi-create | Solid, internally consistent (routes↔contract↔acl↔di align, exception mapping correct); main issue is duplication with module-create. |
| magento2-graphql-create | **One Critical** (C1 schema↔resolver) + overstated di.xml output (M6); auth/store-scope refs are accurate. |
| magento2-eav-attribute | Idempotency correct; class-name≠filename (H8), unsubstitutable label token (M5), heaviest/most-duplicative SKILL.md. |
| magento2-data-migration | Strongest templates (keyset-paginated transactional transform); only a misleading `--dry-run` (M7) + minor robustness nits. |
| magento2-feature-implement | Workflow logic sound, cross-skill calls verified correct; main issues are the 5xx coverage gap (H7), the model-name trailer (H6), and ~120 lines of removable bloat. |
| magento2-bug-fix | One real gap: `{slug}` join key never derived (M1). Otherwise clean. |
| magento2-module-upgrade | Cleanest of the orchestrators; no bugs found, only shared-template/version drift. |
| magento2-deploy | Solid core; smoke-status false-pass (H4), unimplemented branch guardrail (M2), `eval` regression (M3), dead rollback-script ref. |
| magento2-release | Logic mostly sound but the workflow never generates the notes file it consumes (H5) + SKILL/semver divergence (M4). |
| magento2-frontend-create | Templates correct; minor path/placeholder inconsistencies only. |
| magento2-i18n | Scripts are good; the `csv-format.md` reference actively contradicts the correct implementation (H16) + a `%s/%1` false-mismatch (Low). |
| magento2-module-review | Self-consistent (14 areas/3 tiers — note: described as "12 categories" in some descriptions); `scanner_errors` omission (H9) + `.phtml`-blind grep (H10). |
| magento2-security-audit | Confidence-gating/offline/SARIF correct; CVE patch false-negative (H11), category-vocab drift (H12), secret root misplaced (H13). |
| magento2-performance-audit | Static-first gating genuinely enforced; heuristics miss their own golden cases (M16, M17) + off-schema/dead categories (M18). |
| magento2-debug | Read-only guarantee holds (clean); issues are routing (M19), hardcoded log path (M20), dead code. |
| magento2-test-generate | Real assertions + correct PSR-4; coverage double-count (H14), lowercase-vendor SOAP break (H15), fixtureless assertions (M21). |

---

## 7. Suggested remediation order

1. **C1, H1, H4, H5, H8, H15** — generated-output / release-breaking defects; small, localized fixes.
2. **H6, H16, M2, M14, M9 + the §4 drift table** — reference-vs-code drift (agents act on these); often a one-file doc edit.
3. **H9, H10, H11, H12, H13, H14** — audit/security correctness (false negatives erode trust in the reports).
4. **R1 template consolidation + R5 version strings** — removes whole *classes* of future drift.
5. **§3.1 hoist + §3.2 feature-implement trim** — token/maintenance optimization once correctness is settled.
6. **§5 three new tests** — lock the fixes so the classes can't regress.

*No new features or scope changes are proposed anywhere in this report, per the brief.*
