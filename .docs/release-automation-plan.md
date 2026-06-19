# Tag-Triggered Release Automation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On pushing a `v*` tag, automatically publish a GitHub Release — gated on the contract suite + version consistency, with notes from the matching CHANGELOG section — via a tested helper script.

**Architecture:** thin `.github/workflows/release.yml` over a tested `scripts/release-notes.sh` (version-assert + CHANGELOG extraction). The deterministic logic is unit-tested by `tests/test-release-notes.sh`; the workflow wiring is verified on the next real tag push. No skill changes.

**Tech Stack:** GitHub Actions, bash + python3 helper, the repo's `tests/run-all.sh` harness, `gh release create`.

**Reference:** spec `.docs/release-automation-design.md`.

---

### Task 1: helper script + test + workflow + lint coverage (TDD)

**Files:** create `scripts/release-notes.sh`, `tests/test-release-notes.sh`, `.github/workflows/release.yml`; modify `tests/test-bash-syntax.sh`, `.github/workflows/tests.yml`.

- [ ] **Step 1: Write the test.** Create `tests/test-release-notes.sh`:

```bash
#!/usr/bin/env bash
# test-release-notes.sh — scripts/release-notes.sh: version-consistency assert + CHANGELOG extraction.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if ! command -v python3 >/dev/null 2>&1; then echo "skip: python3 not on PATH"; exit 77; fi

H="scripts/release-notes.sh"
FAIL=0

# 1. real repo, current plugin.json version -> non-empty body + title, exit 0
VER="$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json"))["version"])')"
body="$(bash "$H" "$VER")"        || { echo "FAIL: helper non-zero for current version $VER"; FAIL=1; }
[ -n "${body:-}" ]                || { echo "FAIL: empty notes body for $VER"; FAIL=1; }
title="$(bash "$H" --title "$VER")" || { echo "FAIL: --title non-zero for $VER"; FAIL=1; }
[ -n "${title:-}" ]               || { echo "FAIL: empty title for $VER"; FAIL=1; }

# 2. non-existent version -> non-zero
rc=0; bash "$H" 0.0.0-nope >/dev/null 2>&1 || rc=$?
[ "$rc" -ne 0 ] || { echo "FAIL: expected non-zero for bogus version"; FAIL=1; }

# 3. fixture: CHANGELOG has [9.9.9] but manifests at 1.0.0 -> exit 3 (version mismatch)
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/.claude-plugin"
printf '{\n  "name": "magento2-tools",\n  "version": "1.0.0"\n}\n' > "$tmp/.claude-plugin/plugin.json"
printf '{\n  "plugins": [ { "name": "magento2-tools", "version": "1.0.0" } ]\n}\n' > "$tmp/.claude-plugin/marketplace.json"
printf '# Changelog\n\n## [9.9.9] — test\n\n### Added\n\n- thing\n\n## [1.0.0] — old\n' > "$tmp/CHANGELOG.md"
rc=0; RELEASE_NOTES_ROOT="$tmp" bash "$H" 9.9.9 >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 3 ] || { echo "FAIL: expected exit 3 (version mismatch) got $rc"; FAIL=1; }

# 4. fixture happy path: manifests at 9.9.9 -> exit 0, body contains 'thing'
sed -i 's/"version": "1.0.0"/"version": "9.9.9"/' "$tmp/.claude-plugin/plugin.json"
sed -i 's/"version": "1.0.0"/"version": "9.9.9"/' "$tmp/.claude-plugin/marketplace.json"
out="$(RELEASE_NOTES_ROOT="$tmp" bash "$H" 9.9.9 2>/dev/null)" || { echo "FAIL: fixture happy path non-zero"; FAIL=1; }
printf '%s' "$out" | grep -q 'thing' || { echo "FAIL: fixture body missing expected content"; FAIL=1; }

[ "$FAIL" -eq 0 ] || { echo "RESULT: FAIL"; exit 1; }
echo "release-notes: version-assert + changelog extraction verified"
exit 0
```

- [ ] **Step 2: RED.** Run `bash tests/test-release-notes.sh` → expect failure (the helper doesn't exist; `bash scripts/release-notes.sh …` errors), exit 1.

- [ ] **Step 3: Write the helper.** Create `scripts/release-notes.sh`:

```bash
#!/usr/bin/env bash
# release-notes.sh — validate version consistency and emit GitHub-release notes for a tag.
#
# Usage:
#   scripts/release-notes.sh <version>          # print the CHANGELOG [<version>] section BODY (notes)
#   scripts/release-notes.sh --title <version>  # print the section HEADING text (release title)
#
# Files are read under RELEASE_NOTES_ROOT (default: repo root) so tests can use a fixture.
# Exits: 2 = no python3; 3 = a manifest is not at <version>; 4 = no CHANGELOG [<version>] section.
set -euo pipefail

MODE=body
if [ "${1:-}" = "--title" ]; then MODE=title; shift; fi
VERSION="${1:?usage: release-notes.sh [--title] <version>}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="${RELEASE_NOTES_ROOT:-$HERE}"
CHANGELOG="$ROOT/CHANGELOG.md"

command -v python3 >/dev/null 2>&1 || { echo "release-notes: python3 required" >&2; exit 2; }

# 1. both manifests must be at <version>
for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    ok="$(python3 - "$ROOT/$f" "$VERSION" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1])); want = sys.argv[2]
vers = []
if isinstance(doc.get("version"), str): vers.append(doc["version"])
for p in (doc.get("plugins") or []):
    if isinstance(p.get("version"), str): vers.append(p["version"])
print("yes" if want in vers else "no")
PY
)" || { echo "release-notes: cannot read $ROOT/$f" >&2; exit 3; }
    [ "$ok" = "yes" ] || { echo "release-notes: $f is not at version $VERSION" >&2; exit 3; }
done

# 2. a CHANGELOG section for <version> must exist
[ -f "$CHANGELOG" ] || { echo "release-notes: $CHANGELOG not found" >&2; exit 4; }
grep -qF "## [$VERSION]" "$CHANGELOG" || { echo "release-notes: no CHANGELOG section [$VERSION]" >&2; exit 4; }

# 3. emit heading (title) or body (notes)
awk -v ver="$VERSION" -v mode="$MODE" '
    index($0, "## [" ver "]") == 1 {
        insec=1
        if (mode == "title") { h=$0; sub(/^## /, "", h); print h }
        next
    }
    insec && /^## \[/ { insec=0 }
    insec && mode == "body" { print }
' "$CHANGELOG"
```

- [ ] **Step 4: GREEN.** Run `bash tests/test-release-notes.sh` → expect `release-notes: version-assert + changelog extraction verified`, exit 0. (Current CHANGELOG has a `## [Unreleased]` and `## [1.8.0]` but plugin.json is at `1.8.0`, so the real-version case extracts the `[1.8.0]` section.)

- [ ] **Step 5: Write the workflow.** Create `.github/workflows/release.yml`:

```yaml
name: release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install php-cli and xmllint
        run: |
          sudo apt-get update
          sudo apt-get install -y --no-install-recommends php-cli libxml2-utils

      - name: Contract test gate
        run: bash tests/run-all.sh

      - name: Build release notes
        id: notes
        run: |
          VERSION="${GITHUB_REF_NAME#v}"
          bash scripts/release-notes.sh "$VERSION" > "$RUNNER_TEMP/notes.md"
          echo "title=$(bash scripts/release-notes.sh --title "$VERSION")" >> "$GITHUB_OUTPUT"

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
          REL_TITLE: ${{ steps.notes.outputs.title }}
        run: |
          gh release create "$GITHUB_REF_NAME" --title "$REL_TITLE" --notes-file "$RUNNER_TEMP/notes.md"
```

(NOTE: the title is passed via the `REL_TITLE` env var — NOT interpolated into the bash script body — so backticks/em-dashes in the CHANGELOG heading can't be shell-evaluated.)

- [ ] **Step 6: Extend lint coverage to `scripts/`.**

(a) `tests/test-bash-syntax.sh` — replace the find line:
OLD:
```bash
done < <(find skills -path '*/scripts/*.sh' -type f; find hooks -name '*.sh' -type f 2>/dev/null)
```
NEW:
```bash
done < <(find skills -path '*/scripts/*.sh' -type f; find hooks -name '*.sh' -type f 2>/dev/null; find scripts -name '*.sh' -type f 2>/dev/null)
```
And the header comment:
OLD:
```bash
# Every script under skills/*/scripts/ and hooks/ must pass `bash -n`.
```
NEW:
```bash
# Every script under skills/*/scripts/, hooks/, and scripts/ must pass `bash -n`.
```

(b) `.github/workflows/tests.yml` — replace the shellcheck find line:
OLD:
```bash
          files=$(find skills tests hooks -name '*.sh' -type f | sort)
```
NEW:
```bash
          files=$(find skills tests hooks scripts -name '*.sh' -type f | sort)
```
(Preserve the exact leading indentation — it's inside a `run: |` block.)

- [ ] **Step 7: Verify.**
```bash
bash -n scripts/release-notes.sh && echo "syntax ok"
bash tests/test-bash-syntax.sh && echo "bash-syntax ok"   # now also scans scripts/
python3 -c "import sys; open('.github/workflows/release.yml').read(); print('release.yml readable')"
# optional: python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/release.yml')); print('yaml ok')"  (if pyyaml present)
bash tests/run-all.sh | tail -3   # expect FAIL: 0, with test-release-notes.sh PASS
command -v shellcheck >/dev/null && shellcheck --severity=error --exclude=SC1091 scripts/release-notes.sh tests/test-release-notes.sh && echo CLEAN || echo "shellcheck absent — CI runs it"
```
Expected: syntax ok; bash-syntax ok; release.yml readable; suite `FAIL: 0`; shellcheck clean/absent.

- [ ] **Step 8: Commit.**
```bash
chmod +x scripts/release-notes.sh tests/test-release-notes.sh
git add scripts/release-notes.sh tests/test-release-notes.sh .github/workflows/release.yml \
        tests/test-bash-syntax.sh .github/workflows/tests.yml
git commit -m "ci(release): tag-triggered GitHub Release workflow + tested release-notes helper"
```

---

### Task 2: Documentation

**Files:** modify `README.md`, `CHANGELOG.md`.

- [ ] **Step 1: README layout line.** Edit `README.md`:
OLD:
```
tests/               # contract test harness
```
NEW:
```
tests/               # contract test harness
scripts/             # release-notes helper (used by .github/workflows/release.yml)
```

- [ ] **Step 2: README "Releasing" section.** Insert before the `## Versioning` heading (Edit: old_string `## Versioning`, new_string = the block below + `## Versioning`):
```markdown
## Releasing

Bump `.claude-plugin/plugin.json` + `marketplace.json`, convert the CHANGELOG `[Unreleased]`
section to `## [X.Y.Z]`, commit `Release vX.Y.Z`, then push an annotated `vX.Y.Z` tag. The tag push
triggers [`.github/workflows/release.yml`](.github/workflows/release.yml), which runs the contract
suite, asserts the tag matches both manifest versions, and publishes a GitHub Release with the
matching CHANGELOG section as its notes (extracted by `scripts/release-notes.sh`). The bump,
CHANGELOG, and tag stay manual.

## Versioning
```

- [ ] **Step 3: CHANGELOG bullet.** Edit `CHANGELOG.md` (add under the existing `## [Unreleased]` → `### Added`, after the slash-command bullet):
OLD:
```
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```
NEW:
```
  Contract test: `tests/test-command-routing.sh`. No skill behaviour changes.
- **Release automation** — `.github/workflows/release.yml` publishes a GitHub Release when a `v*`
  tag is pushed: it runs the contract suite, asserts the tag matches `plugin.json` +
  `marketplace.json`, and uses `scripts/release-notes.sh` to extract the matching CHANGELOG section
  as the release notes. Version bump / CHANGELOG / tag stay manual. CI/infra only — no skill change.

## [1.8.0] — 2026-06-17 — `.docs/` path-guard hook, golden emitter tests, deferral policy
```
(If the OLD block isn't found verbatim, STOP → NEEDS_CONTEXT.)

- [ ] **Step 4: Verify & commit.**
```bash
grep -n 'scripts/ ' README.md | head -1
grep -n '## Releasing' README.md
grep -n 'Release automation' CHANGELOG.md
bash tests/run-all.sh | tail -3   # expect FAIL: 0
git add README.md CHANGELOG.md
git commit -m "docs(release): document the release workflow (README Releasing + CHANGELOG)"
```

---

### Task 3: Final verification

- [ ] **Step 1: Full suite + clean tree.** `bash tests/run-all.sh | tail -4 && git status --short`. Expect `FAIL: 0` (incl. `test-release-notes.sh` PASS); only pre-existing untracked `.gitignore`/`.claude/`/`.docs/`.
- [ ] **Step 2: Scope check.** `git diff --stat $(git merge-base HEAD main)..HEAD` → only: `scripts/release-notes.sh`, `tests/test-release-notes.sh`, `.github/workflows/release.yml`, `tests/test-bash-syntax.sh`, `.github/workflows/tests.yml`, `README.md`, `CHANGELOG.md`. No skills/ change.
- [ ] **Step 3: Helper smoke against the real repo.** `bash scripts/release-notes.sh 1.8.0 | head -3 && bash scripts/release-notes.sh --title 1.8.0`. Expect the `[1.8.0]` section body + heading text. Then `bash scripts/release-notes.sh 1.7.0; echo "exit=$?"` → expect exit 3 (plugin.json is 1.8.0, not 1.7.0 — the version-consistency assert fires).

---

## Self-review

**Spec coverage** (`.docs/release-automation-design.md`):
- §3 workflow → Task 1 Step 5 (thin YAML; title via env var, not `${{ }}` interpolation, per the backtick-safety note).
- §4 helper (ROOT override, exit 2/3/4, body/--title) → Step 3.
- §5 test (4 cases incl. mismatch fixture via `RELEASE_NOTES_ROOT`) → Step 1.
- §6 lint extension → Step 6 (test-bash-syntax + tests.yml).
- §7 docs → Task 2.
- §8 error handling → encoded in the helper exits + the suite gate.

**Placeholder scan:** the helper, test, and workflow are verbatim; docs give exact OLD/NEW. The only un-automatable bit (workflow wiring) is explicitly a next-release manual check, not a placeholder.

**Type/name consistency:** `RELEASE_NOTES_ROOT`, the exit codes (2/3/4), `scripts/release-notes.sh`, and `tests/test-release-notes.sh` are used identically across the helper, the test, the workflow, and the lint extension; the workflow calls the helper with the same `<version>` / `--title <version>` interface the test exercises.
