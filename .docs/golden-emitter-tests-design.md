# Design: golden-render tests for the shared findings emitters

**Status:** Approved design (2026-06-17) — pending spec review, then implementation plan.
**Scope:** the `magento2-tools` plugin. Adds one contract test + fixtures + golden files. No production-script changes.
**Author:** drafted via Claude Code for the magento2-tools plugin.

---

## 1. Why

`emit-json.sh` and `emit-sarif.sh` (under `skills/magento2-module-review/scripts/`) are the **shared findings emitters**: `magento2-module-review`, `magento2-security-audit`, `magento2-performance-audit`, and `magento2-module-upgrade` all funnel their findings through them. A silent regression in the emitted *shape* — a renamed/removed/new field, a `summarize` miscount, a category-tally bug, a SARIF level-mapping change, a broken CWE-taxonomy block — would corrupt every consumer's output, and the current tests would not catch it: `test-emit-json-skill-agnostic.sh` only probes three fields (`skill`, `outputKind`, `skillVersions`).

A golden/snapshot test pins the **entire** emitted document against a checked-in expected output, so any shape drift fails loudly.

## 2. Decisions (locked)

- **Scope:** the two shared emitters only — `emit-json.sh` and `emit-sarif.sh`. (Not i18n-merge or the build-findings wrappers.)
- **Determinism via normalization:** the only non-deterministic field is `emit-json.sh`'s `runAt` (a UTC timestamp). Normalize it to the fixed placeholder `1970-01-01T00:00:00Z` before diffing.
- **Chain, don't double-normalize:** `emit-sarif.sh` derives its only timestamp (`invocations[].endTimeUtc`) from the input document's `runAt`. Feed the *normalized* emit-json output into emit-sarif, so the SARIF is deterministic with no SARIF-specific normalization.
- **Refresh mechanism:** `UPDATE_GOLDEN=1` regenerates the golden files instead of diffing (standard snapshot-refresh, so a legitimate emitter change is a one-command update + review of the diff).
- **One new test**, `tests/test-golden-emitters.sh`, registered implicitly via `run-all.sh`'s `test-*.sh` glob. SKIP (exit 77) when `python3` is absent (matches repo convention; both emitters require python3).

## 3. How the emitters behave (verified by reading the scripts)

`emit-json.sh` — env-driven; emits a JSON document to stdout (and a file). Deterministic given fixed inputs **except** `runAt` (`datetime.now(timezone.utc)`). The date in the output *filename* is already overridable via `OUTPUT_BASENAME`, so it does not affect stdout. Relevant env: `FINDINGS_FILE`, `TARGET_MODULE`, `TARGET_PATH`, `MODE`, `SCOPE`, `SKILL_NAME`, `SKILL_VERSION`, `SKILL_VERSIONS_JSON`, `OUTPUT_KIND`, `CONTEXT_FILE`, `SKIPPED_FILE`, `TOOLS_FILE`, `OUTPUT_DIR`, `OUTPUT_BASENAME`.

`emit-sarif.sh` — takes the emit-json output JSON as `$1`; emits SARIF 2.1.0. Its only timestamp, `endTimeUtc`, is copied from the document's `runAt` (omitted when absent). So a normalized-`runAt` input yields a deterministic SARIF.

## 4. Components / files

1. `tests/golden/fixtures/findings.json` — one findings array engineered to exercise every branch of both emitters:
   - all five severities `critical|high|medium|low|info` → exercises `summarize().bySeverity` and `SEVERITY_TO_LEVEL` (error/warning/note);
   - at least two distinct `category` values → exercises `byCategory` tally and SARIF `rule.name`;
   - one finding with a `cwe` → exercises SARIF `taxonomies[]`, `rule.relationships`, and `result.taxa`;
   - one finding with a `bulletin_url` (and/or `helpUri`) → exercises `rule.helpUri`;
   - one finding with `evidence` (`file`, `line`, `endLine`) → exercises `physicalLocation` incl. `endLine`;
   - one finding with **no** `evidence` → exercises the `unknown:1` location fallback;
   - one finding with empty/absent `description` → exercises `fullDescription`→`title` fallback.
2. `tests/golden/fixtures/context.json` — a fixed context object (the keys `emit-json` projects: `vendor`, `magento_version`, `edition`, `php_version`, `runner`).
3. `tests/golden/emit-json.expected.json` — checked-in golden (normalized `runAt`).
4. `tests/golden/emit-sarif.expected.sarif` — checked-in golden.
5. `tests/test-golden-emitters.sh` — the driver (below).

## 5. The test driver (behaviour spec)

```
1. cd to repo root. If python3 absent -> echo skip; exit 77.
2. Work in a mktemp -d (trap-cleaned).
3. Run emit-json.sh with FIXED env:
     FINDINGS_FILE = tests/golden/fixtures/findings.json
     CONTEXT_FILE  = tests/golden/fixtures/context.json
     TARGET_MODULE = Acme_Golden,  TARGET_PATH = src/app/code/Acme/Golden
     MODE=full SCOPE=module OUTPUT_KIND=review
     SKILL_NAME=magento2-module-review SKILL_VERSION=2.3.0
     SKILL_VERSIONS_JSON='["magento2-module-review@2.3.0","magento2-context@1.6.0"]'
     OUTPUT_DIR=$WORK OUTPUT_BASENAME=golden
   Capture stdout.
4. Normalize: sed-replace the runAt VALUE with 1970-01-01T00:00:00Z. Write to $WORK/emit-json.norm.json.
5. Run emit-sarif.sh $WORK/emit-json.norm.json (OUTPUT_DIR=$WORK). Capture stdout -> $WORK/emit-sarif.out.sarif.
6. If UPDATE_GOLDEN=1: copy $WORK/emit-json.norm.json -> tests/golden/emit-json.expected.json
   and $WORK/emit-sarif.out.sarif -> tests/golden/emit-sarif.expected.sarif; echo "updated
   goldens"; exit 0.
7. Else: diff each output against its golden. On any diff: print it and the
   "regenerate with UPDATE_GOLDEN=1 if intentional" hint; exit 1. Else exit 0.
```

Notes:
- The `runAt` normalization is a single targeted substitution on the `"runAt": "<value>"` line; it does not reformat the document, so the golden stays byte-faithful to real emitter output.
- The SKILL_VERSIONS_JSON and SKILL_VERSION are pinned so a routine skill-version bump does NOT churn the golden. (If the emitter's *default* version logic is what changed, the golden intentionally updates.)

## 6. Error handling

Every failure path is explicit: missing python3 → SKIP 77; emitter non-zero exit → propagate FAIL with the emitter's stderr; output mismatch → print unified `diff` + regenerate hint → exit 1. No silent passes.

## 7. Out of scope / non-goals

- No changes to `emit-json.sh` / `emit-sarif.sh` or any other production script.
- No golden coverage for `resolve-context.sh` (non-deterministic: machine paths + tool probes + timestamp), i18n-merge (already behaviorally tested), or build-findings wrappers (deferred — `mktemp`/tool-dependent).
- Not a schema validator: it pins the *current* output, not an external SARIF/JSON schema. (Schema conformance is a separate concern.)

## 8. Versioning & docs

- Test-only addition; no skill behaviour change → no skill-version bumps, no plugin version bump.
- Mention the new test in the README "Tests" paragraph (it enumerates coverage areas) and add a CHANGELOG `[Unreleased]` line. The "17 skills" count is NOT touched (separate PR #12).
