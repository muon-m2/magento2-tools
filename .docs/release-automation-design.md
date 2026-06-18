# Design: tag-triggered release automation

**Status:** Approved design (2026-06-17) — pending spec review, then implementation plan.
**Scope:** the `magento2-tools` plugin. Adds a `.github/workflows/release.yml` + a tested helper script + a contract test + lint-scan extension + docs. No skill changes.
**Author:** drafted via Claude Code for the magento2-tools plugin.

---

## 1. Why

Releases (v1.5.0–v1.8.0) are cut by hand: bump `plugin.json`+`marketplace.json`, convert the CHANGELOG `[Unreleased]` section, commit `Release vX`, tag, push, then `gh release create` with the CHANGELOG section as notes. The repeatable, error-prone tail — *turn a pushed tag into a published GitHub Release with the right notes, only if the repo is consistent and green* — should be automated. The human-judgment steps (version, CHANGELOG, tag) stay manual.

## 2. Decisions (locked)

- **Trigger:** `push` of a `v*` tag. The maintainer still bumps + edits CHANGELOG + tags; pushing the tag publishes the Release.
- **Gate:** the workflow runs `tests/run-all.sh` and asserts the tag version equals both manifest versions before releasing.
- **Notes:** extracted from the matching `## [X.Y.Z]` CHANGELOG section; the release title is that heading's text.
- **Tested-helper split:** the deterministic logic lives in `scripts/release-notes.sh` and is unit-tested by `tests/test-release-notes.sh`; the YAML stays thin.
- **No** full CI-side bump/commit (rejected "full dispatch" option). No skill/version changes.

## 3. Component 1 — `.github/workflows/release.yml`

```
name: release
on:
  push:
    tags: ['v*']
permissions:
  contents: write          # create the GitHub Release
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - checkout (fetch tags)
      - install php-cli + libxml2-utils         # so run-all.sh can run (mirrors tests.yml)
      - run: bash tests/run-all.sh               # GATE — red ⇒ job fails ⇒ no release
      - run: |
          VERSION="${GITHUB_REF_NAME#v}"
          bash scripts/release-notes.sh "$VERSION" > "$RUNNER_TEMP/notes.md"   # asserts + body
          TITLE="$(bash scripts/release-notes.sh --title "$VERSION")"
      - run: gh release create "$GITHUB_REF_NAME" --title "$TITLE" --notes-file "$RUNNER_TEMP/notes.md"
        env: { GH_TOKEN: ${{ github.token }} }
```

(Exact YAML written in the plan. `shellcheck` already runs in `tests.yml`; this workflow's bash is minimal and delegates to the tested helper.)

## 4. Component 2 — `scripts/release-notes.sh`

```
Usage:
  scripts/release-notes.sh <version>            # prints the CHANGELOG section BODY (notes) to stdout
  scripts/release-notes.sh --title <version>    # prints the section HEADING text (release title)

Behaviour:
  0. Resolve a base dir: ROOT="${RELEASE_NOTES_ROOT:-<repo root via BASH_SOURCE>}". All files are
     read under ROOT — so a test can point it at a fixture dir. Default is the real repo.
  1. Read version from $ROOT/.claude-plugin/plugin.json and $ROOT/.claude-plugin/marketplace.json.
  2. Assert both equal <version>; else stderr error + exit 3 (tagged without bumping).
  3. Find the '## [<version>] …' line in $ROOT/CHANGELOG.md; capture until the next '## [' line.
     If absent/empty → stderr error + exit 4.
  4. Default mode: print the section body (everything after the heading line, trimmed).
     --title mode: print the heading text with the leading '## ' removed.
  set -euo pipefail; python3 required (consistent with the repo's other emitters); exit 2 if absent.
```

This is the only non-trivial logic and is fully unit-testable without GitHub.

## 5. Component 3 — `tests/test-release-notes.sh`

Drives the helper (no network); SKIP (77) if `python3` absent; runs in `tests/run-all.sh`:
- **Real repo, current version** (`RELEASE_NOTES_ROOT` unset → repo root): read the version from
  `plugin.json`, run the helper with it → body non-empty AND `--title` non-empty, exit 0.
- **Missing CHANGELOG section**: run with `0.0.0-nope` → exit non-zero (exit 4 path).
- **Version mismatch** (the key safety assert, via a fixture under `RELEASE_NOTES_ROOT`): build a
  temp dir with a `CHANGELOG.md` containing `## [9.9.9] — x` and `.claude-plugin/{plugin,marketplace}.json`
  at version `1.0.0`; run `RELEASE_NOTES_ROOT=$tmp release-notes.sh 9.9.9` → exit 3 (CHANGELOG has
  the section but manifests don't match).
- **Fixture happy path**: same fixture but manifests at `9.9.9` → exit 0, body printed (proves the
  ROOT override + extraction work together).

## 6. Component 4 — extend lint coverage to `scripts/`

- `tests/test-bash-syntax.sh`: add `find scripts -name '*.sh'` to the `bash -n` set.
- `.github/workflows/tests.yml`: add `scripts` to the shellcheck `find skills tests hooks` list.

## 7. Component 5 — docs

- README: add a `scripts/` line to the Layout block and a short "Releasing" note (bump manifests → update CHANGELOG `[Unreleased]` → `Release vX` commit → annotated `vX` tag → push tag → the workflow validates + publishes the GitHub Release).
- CHANGELOG `[Unreleased]` entry.

## 8. Error handling / non-goals

- Every failure path is explicit: red suite → job fails; version mismatch → exit 3; missing CHANGELOG section → exit 4; missing python3 → exit 2. No release is published on any failure.
- **Non-goal:** CI-side version bump / CHANGELOG editing / committing / tagging — those stay manual (human judgment).
- **Non-goal:** publishing anywhere other than a GitHub Release (no marketplace push; the repo *is* its own marketplace via `marketplace.json`, which is already version-synced).
- **Testability caveat:** the workflow *wiring* (trigger, token, gh) is only fully exercised by a real `v*` tag push — a documented manual verification on the next release. The logic (Component 2) is unit-tested (Component 3).

## 9. Versioning & docs

- Test/CI/infra only — no skill-version bumps. CHANGELOG `[Unreleased]` entry; README "Releasing" + layout line.
- This workflow will itself publish the **next** release (e.g. v1.9.0 bundling the slash-commands + routing + this automation), validating it end-to-end.
