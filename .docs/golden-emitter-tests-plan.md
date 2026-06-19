# Golden-Render Tests for the Shared Emitters — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a golden/snapshot contract test that pins the full output shape of the shared findings emitters (`emit-json.sh` + `emit-sarif.sh`) against checked-in expected files, so any regression in the emitted JSON/SARIF structure fails loudly.

**Architecture:** One driver (`tests/test-golden-emitters.sh`) runs both emitters off fixed fixtures, normalizes the only non-deterministic field (`runAt` → a fixed placeholder), chains the normalized JSON into `emit-sarif` (so the SARIF is deterministic too), and diffs both outputs against goldens. `UPDATE_GOLDEN=1` regenerates the goldens. No production scripts change.

**Tech Stack:** Bash + `python3` (both emitters require it), the repo's `tests/run-all.sh` harness (`test-*.sh`, exit 0=PASS/77=SKIP/other=FAIL), `diff -u`, `sed`.

**Reference:** design spec at `.docs/golden-emitter-tests-design.md`.

---

### Task 1: Golden-test apparatus (fixtures + driver + goldens)

**Files:**
- Create: `tests/golden/fixtures/findings.json`
- Create: `tests/golden/fixtures/context.json`
- Create: `tests/test-golden-emitters.sh`
- Create (generated): `tests/golden/emit-json.expected.json`, `tests/golden/emit-sarif.expected.sarif`

- [ ] **Step 1: Create the findings fixture.** Create `tests/golden/fixtures/findings.json` with EXACTLY this content (5 findings engineered to exercise every emitter branch — all severities, repeated categories, a CWE, a `bulletin_url`, a `helpUri`, evidence with and without `endLine`, a finding with no evidence, and findings with no `description`):

```json
[
  {
    "id": "SEC-001",
    "severity": "critical",
    "category": "security",
    "title": "SQL injection in collection filter",
    "description": "Unsanitized request input concatenated into addFieldToFilter().",
    "cwe": "CWE-89",
    "bulletin_url": "https://example.test/advisories/sec-001",
    "evidence": [
      { "file": "Model/ResourceModel/Order/Collection.php", "line": 42, "endLine": 45 }
    ]
  },
  {
    "id": "SEC-002",
    "severity": "high",
    "category": "security",
    "title": "Admin controller missing ACL check"
  },
  {
    "id": "PERF-001",
    "severity": "medium",
    "category": "performance",
    "title": "N+1 query inside listing loop",
    "description": "Repository->getById called inside a foreach over collection items.",
    "evidence": [
      { "file": "Block/Adminhtml/Listing.php", "line": 88 }
    ]
  },
  {
    "id": "MNT-001",
    "severity": "low",
    "category": "maintainability",
    "title": "Method exceeds length guideline",
    "description": "export() is 73 lines; extract helpers.",
    "helpUri": "https://example.test/rules/mnt-001"
  },
  {
    "id": "MNT-002",
    "severity": "info",
    "category": "maintainability",
    "title": "Replace magic number with a named constant"
  }
]
```

- [ ] **Step 2: Create the context fixture.** Create `tests/golden/fixtures/context.json` with EXACTLY this content (the `extra_ignored` key proves `emit-json` projects only the five context keys):

```json
{
  "vendor": "Acme",
  "magento_version": "2.4.7-p3",
  "edition": "open-source",
  "php_version": "8.2.15",
  "runner": "docker compose exec -T php",
  "extra_ignored": "must NOT appear in emitter output"
}
```

- [ ] **Step 3: Create the test driver.** Create `tests/test-golden-emitters.sh` with EXACTLY this content:

```bash
#!/usr/bin/env bash
# test-golden-emitters.sh — golden/snapshot test for the shared findings emitters
# (emit-json.sh + emit-sarif.sh). Pins the full emitted shape against checked-in golden
# files so any regression in the document structure fails loudly.
#
# The only non-deterministic field is emit-json's `runAt` (a UTC timestamp); it is
# normalized to a fixed placeholder before comparison. emit-sarif derives its only
# timestamp (endTimeUtc) from that runAt, so feeding it the normalized JSON makes the
# SARIF deterministic too.
#
# Refresh goldens after an intentional emitter change:
#   UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip: python3 not on PATH"
    exit 77
fi

GOLDEN_DIR="tests/golden"
FIX_DIR="$GOLDEN_DIR/fixtures"
EMIT_JSON="skills/magento2-module-review/scripts/emit-json.sh"
EMIT_SARIF="skills/magento2-module-review/scripts/emit-sarif.sh"
PLACEHOLDER="1970-01-01T00:00:00Z"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# 1. Run emit-json.sh with fixed inputs; capture stdout (the JSON document).
FINDINGS_FILE="$FIX_DIR/findings.json" \
CONTEXT_FILE="$FIX_DIR/context.json" \
TARGET_MODULE="Acme_Golden" \
TARGET_PATH="src/app/code/Acme/Golden" \
MODE="full" \
SCOPE="module" \
OUTPUT_KIND="review" \
SKILL_NAME="magento2-module-review" \
SKILL_VERSION="2.3.0" \
SKILL_VERSIONS_JSON='["magento2-module-review@2.3.0","magento2-context@1.6.0"]' \
OUTPUT_DIR="$WORK" \
OUTPUT_BASENAME="golden" \
bash "$EMIT_JSON" > "$WORK/emit-json.raw.json" 2>/dev/null || {
    echo "FAIL: emit-json.sh exited non-zero"; exit 1; }

# 2. Normalize the runAt timestamp value.
sed 's#"runAt": "[^"]*"#"runAt": "'"$PLACEHOLDER"'"#' \
    "$WORK/emit-json.raw.json" > "$WORK/emit-json.norm.json"

# 3. Feed the normalized JSON into emit-sarif.sh; capture stdout (the SARIF).
OUTPUT_DIR="$WORK" bash "$EMIT_SARIF" "$WORK/emit-json.norm.json" \
    > "$WORK/emit-sarif.out.sarif" 2>/dev/null || {
    echo "FAIL: emit-sarif.sh exited non-zero"; exit 1; }

JSON_GOLDEN="$GOLDEN_DIR/emit-json.expected.json"
SARIF_GOLDEN="$GOLDEN_DIR/emit-sarif.expected.sarif"

# 4. Refresh mode.
if [ "${UPDATE_GOLDEN:-}" = "1" ]; then
    mkdir -p "$GOLDEN_DIR"
    cp "$WORK/emit-json.norm.json" "$JSON_GOLDEN"
    cp "$WORK/emit-sarif.out.sarif" "$SARIF_GOLDEN"
    echo "updated goldens: $JSON_GOLDEN, $SARIF_GOLDEN"
    exit 0
fi

# 5. Compare against goldens.
FAIL=0
compare() { # name actual golden
    local name="$1" actual="$2" golden="$3"
    if [ ! -f "$golden" ]; then
        echo "FAIL: $name golden missing: $golden (run UPDATE_GOLDEN=1 to create it)"
        FAIL=1
        return
    fi
    if ! diff -u "$golden" "$actual"; then
        echo "FAIL: $name output drifted from golden ($golden)."
        echo "      If intentional, regenerate: UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh"
        FAIL=1
    fi
}
compare emit-json  "$WORK/emit-json.norm.json"  "$JSON_GOLDEN"
compare emit-sarif "$WORK/emit-sarif.out.sarif" "$SARIF_GOLDEN"

[ "$FAIL" -eq 0 ] || exit 1
echo "golden emitters: emit-json + emit-sarif match goldens"
exit 0
```

- [ ] **Step 4: Run the test to verify it FAILS (RED — goldens absent).**

Run: `bash tests/test-golden-emitters.sh`
Expected: FAIL — two `FAIL: … golden missing …` lines (emit-json and emit-sarif), exit 1. This confirms the test does not vacuously pass without goldens.

- [ ] **Step 5: Generate the goldens.**

Run: `UPDATE_GOLDEN=1 bash tests/test-golden-emitters.sh`
Expected: `updated goldens: tests/golden/emit-json.expected.json, tests/golden/emit-sarif.expected.sarif`, exit 0. Two new files now exist.

- [ ] **Step 6: Inspect the generated goldens (the real validation — confirm they reflect the fixture).**

Run:
```bash
python3 - <<'PY'
import json
d = json.load(open('tests/golden/emit-json.expected.json'))
assert d['summary']['total'] == 5, d['summary']
assert d['summary']['bySeverity'] == {'critical':1,'high':1,'medium':1,'low':1,'info':1}, d['summary']['bySeverity']
assert d['summary']['byCategory'] == {'security':2,'performance':1,'maintainability':2}, d['summary']['byCategory']
assert d['runAt'] == '1970-01-01T00:00:00Z', d['runAt']
assert d['context'] == {'vendor':'Acme','magento_version':'2.4.7-p3','edition':'open-source','php_version':'8.2.15','runner':'docker compose exec -T php'}, d['context']
assert d['skill'] == 'magento2-module-review' and d['outputKind'] == 'review'
s = json.load(open('tests/golden/emit-sarif.expected.sarif'))
run = s['runs'][0]
assert run['invocations'][0]['endTimeUtc'] == '1970-01-01T00:00:00Z', run['invocations'][0]
assert any(t.get('name') == 'CWE' for t in run.get('taxonomies', [])), 'CWE taxonomy missing'
uris = [r['locations'][0]['physicalLocation']['artifactLocation']['uri'] for r in run['results']]
assert 'unknown' in uris, uris  # SEC-002 has no evidence -> unknown:1 fallback
print('golden inspection OK')
PY
```
Expected: `golden inspection OK` (no AssertionError). This verifies the goldens encode the intended shape — `extra_ignored` is dropped from `context`, severity/category tallies are right, `runAt`/`endTimeUtc` normalized, CWE taxonomy emitted, and the no-evidence fallback present.

- [ ] **Step 7: Run the test to verify it PASSES (GREEN), and the full suite.**

Run: `bash tests/test-golden-emitters.sh`
Expected: `golden emitters: emit-json + emit-sarif match goldens`, exit 0.

Run: `bash tests/run-all.sh`
Expected: a `PASS:` line with `FAIL: 0`; `test-golden-emitters.sh` shows `PASS`.

- [ ] **Step 8: Commit.**

```bash
chmod +x tests/test-golden-emitters.sh
git add tests/golden/fixtures/findings.json tests/golden/fixtures/context.json \
        tests/test-golden-emitters.sh \
        tests/golden/emit-json.expected.json tests/golden/emit-sarif.expected.sarif
git commit -m "test: add golden-render tests for the shared findings emitters"
```

- [ ] **Step 9: Non-vacuity check (prove the golden actually bites, then revert).**

Run:
```bash
# Perturb a committed fixture: flip SEC-001 from critical to high.
sed -i 's/"severity": "critical"/"severity": "high"/' tests/golden/fixtures/findings.json
bash tests/test-golden-emitters.sh; echo "exit=$?"
```
Expected: a `diff` showing the `bySeverity` / `endTimeUtc`-unrelated change (critical 1→0, high 1→2) and `FAIL: emit-json output drifted …`, `exit=1`. This proves the golden detects a real shape change.

Then revert and reconfirm green:
```bash
git checkout -- tests/golden/fixtures/findings.json
bash tests/test-golden-emitters.sh; echo "exit=$?"
```
Expected: `golden emitters: … match goldens`, `exit=0`. Working tree clean (`git status --short` shows nothing under `tests/`). No commit in this step.

---

### Task 2: Documentation

**Files:**
- Modify: `README.md` (Tests section)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add the golden tests to the README Tests list.**

In `README.md`, the Tests paragraph ends with `…plugin↔marketplace version sync, and skill-version-registry consistency.` Use the Edit tool with this exact replacement (single-line substring, appears once):

OLD:
```
sync, and skill-version-registry consistency.
```
NEW:
```
sync, skill-version-registry consistency, and golden-output snapshots of the shared findings emitters (`emit-json` / `emit-sarif`).
```

(If that exact substring is not found verbatim, STOP and report NEEDS_CONTEXT with the actual Tests-paragraph text — do not improvise.)

- [ ] **Step 2: Add a CHANGELOG `[Unreleased]` entry.**

In `CHANGELOG.md`, insert between the `This project adheres to [Semantic Versioning](https://semver.org/).` line and the `## [1.7.0] …` line. Use the Edit tool:

OLD:
```
This project adheres to [Semantic Versioning](https://semver.org/).

## [1.7.0] — 2026-06-16 — `magento2-adminhtml-form`: adminhtml UI-component form generator
```
NEW:
```
This project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- **Golden-render tests for the shared findings emitters** — `tests/test-golden-emitters.sh`
  pins the full output shape of `emit-json.sh` and `emit-sarif.sh` against checked-in golden
  files under `tests/golden/`, so any regression in the emitted JSON/SARIF structure fails
  loudly (the current field-probe test only checked three fields). The `runAt` timestamp is
  normalized; regenerate the goldens after an intentional emitter change with
  `UPDATE_GOLDEN=1`. Test-only — no skill or behaviour change.

## [1.7.0] — 2026-06-16 — `magento2-adminhtml-form`: adminhtml UI-component form generator
```

(If the OLD block is not found verbatim, STOP and report NEEDS_CONTEXT.)

- [ ] **Step 3: Verify and commit.**

Run: `grep -n 'golden-output snapshots' README.md && grep -n 'Unreleased' CHANGELOG.md && bash tests/run-all.sh | tail -3`
Expected: one README hit, one CHANGELOG hit, suite `FAIL: 0`.

```bash
git add README.md CHANGELOG.md
git commit -m "docs: note golden-emitter tests (README Tests + CHANGELOG)"
```

---

### Task 3: Final verification

- [ ] **Step 1: Full suite + clean tree.**

Run: `bash tests/run-all.sh | tail -4 && git status --short`
Expected: `FAIL: 0` with `test-golden-emitters.sh` PASS; `git status` shows only the pre-existing untracked `.gitignore`/`.claude/`/`.docs/` — nothing stray under `tests/`.

- [ ] **Step 2: Confirm the feature diff is in scope.**

Run: `git diff --stat 61b9628..HEAD`
Expected: only `tests/golden/fixtures/findings.json`, `tests/golden/fixtures/context.json`, `tests/test-golden-emitters.sh`, `tests/golden/emit-json.expected.json`, `tests/golden/emit-sarif.expected.sarif`, `README.md`, `CHANGELOG.md`. No production-script changes.

- [ ] **Step 3: shellcheck (if available; else CI covers it).**

Run: `command -v shellcheck >/dev/null && shellcheck --severity=error --exclude=SC1091 tests/test-golden-emitters.sh && echo CLEAN || echo "shellcheck absent — CI runs it"`
Expected: `CLEAN` or the absent note.

---

## Self-review

**Spec coverage** (`.docs/golden-emitter-tests-design.md`):
- §2 decisions (two emitters, runAt normalize, chain into SARIF, UPDATE_GOLDEN, SKIP-77) → Task 1 driver + steps.
- §4 fixtures (every branch) → Task 1 Steps 1–2; verified in Step 6.
- §5 driver behaviour (fixed env, normalize, chain, diff/refresh) → Task 1 Step 3 (verbatim script).
- §6 error handling (SKIP 77, non-zero propagate, diff+hint) → in the driver.
- §8 docs (README Tests + CHANGELOG; "17" untouched) → Task 2.
- Non-vacuity ("watch it fail") → Task 1 Steps 4 (RED) and 9 (perturb→fail→revert).

**Placeholder scan:** none — fixtures and driver are verbatim; goldens are generated (Step 5) and validated (Step 6) rather than hand-written (correct for snapshot files); doc edits give exact old/new strings.

**Type/name consistency:** paths (`tests/golden/fixtures/{findings,context}.json`, `tests/golden/emit-{json,sarif}.expected.*`, `tests/test-golden-emitters.sh`) and env-var names (`UPDATE_GOLDEN`, `OUTPUT_BASENAME`, `SKILL_VERSIONS_JSON`) are consistent across all tasks and match the emitters' documented interface.
