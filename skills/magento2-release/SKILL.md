---
name: magento2-release
description:
    Release a Magento 2 module — bump version, update CHANGELOG, tag, push, publish.
    Use when the user wants to cut a release for a module. Detects the next version from
    conventional commits or accepts an explicit version. Validates before tagging,
    generates release notes from commits since last tag, and optionally creates a GitHub
    release.
---

# Magento 2 Release

Cut a release for a Magento 2 module that lives in this repo.

## Core Rules

- **Validate first.** No release happens if pre-flight validation fails (
  `magento2-deploy --validate-only --strict --env=local`). The release MUST use `--validate-only` — never a
  state-changing deploy invocation.
- **Semver from commits.** Detect the next version from conventional commits, then let
  the user override.
- **Module-prefixed tags.** Multi-module repos need disambiguating tags:
  `{Vendor}_{Module}-{Version}`.
- **CHANGELOG kept in sync.** Bump CHANGELOG.md per module with grouped entries.
- **Confirm before push.** Tag pushing and GitHub Release creation require explicit
  user approval.
- **Never push to main without authorization.** This skill respects the project's branch
  protection rules.

## Workflow

### Phase 0 — Context Resolution

Invoke `magento2-context`. Capture `gh` CLI availability.

### Phase 1 — Determine Version

- Read current `composer.json` version.
- Read commits since last git tag matching `{Vendor}_{Module}-*` (or fall back to
  the initial commit if no prior tag). **Path-filter to this module** so commits from
  sibling modules in the same repo are excluded:
  `git log {lastTag}..HEAD -- {module_path}`.
- Classify each commit per conventional commits:
    - `feat:` → minor bump
    - `fix:` → patch bump
    - `BREAKING CHANGE:` or `feat!:` → major bump
- Propose next version. User can override with `--version=X.Y.Z`.
    - **Downgrade guard:** if an explicit `--version` is passed, refuse it unless it is
      strictly greater than the latest existing tag for this module (use the version
      comparison in `references/semver-rules.md`). A forced *upward* jump is still allowed
      (with a warning); a downgrade or equal version is rejected.

### Phase 2 — Validate

Run `magento2-deploy --validate-only --strict --env=local` against the local environment.
This is preflight-only — the deploy MUST NOT execute any state-changing step. All required
checks must pass before the release proceeds.

### Phase 3 — Update Files

- Bump `composer.json` version.
- Update `CHANGELOG.md` with grouped entries per `references/changelog-format.md`.
- Commit with message `release({Module}): {Version}`.

### Phase 4 — Tag

```
git tag -a {Vendor}_{Module}-{Version} -m "Release {Vendor}_{Module} {Version}"
```

Module-prefixed to disambiguate multi-module repos.

### Phase 5 — Push (APPROVAL GATE)

Confirm with user before pushing:

```
git push origin {current_branch}
git push origin {tag}
```

The user types **`release`** to confirm. Anything else cancels.

### Phase 5.5 — Render Release Notes

Render `templates/release-notes.md` from the Phase 1 classified commits to
`{output_root}/releases/{Module}-{Version}.md` (under the project-root, never under
`{magento_root}`; `{output_root}` is the `--docs-root` value or `{ctx.docs_root}`). This
file is the `--notes-file` source for Phase 6 **and** the durable release-notes artefact
listed in Outputs, so render it even when Phase 6 is skipped — otherwise Phase 6's
`gh release create --notes-file …` points at a path nothing created.

### Phase 6 — GitHub Release (Optional)

If `gh` is available and the user authorizes:

```
gh release create {tag} \
    --title "{Vendor}_{Module} {Version}" \
    --notes-file {output_root}/releases/{Module}-{Version}.md
```

### Phase 7 — Publish (Optional)

There is no `composer publish` command. "Publishing" means making the pushed tag
resolvable by a Composer source:

- **Packagist / Private Packagist:** the GitHub→registry webhook (or registry sync) picks
  up the tag automatically — no extra command. Verify on the package page if needed.
- **Satis:** regenerate the static repo with `satis build`.
- **Plain VCS source:** nothing to do — the consumer resolves the tag directly from git.
- **Marketplace (EQP):** prepare the zip artefact; the user uploads it via the Marketplace
  developer portal manually.

See `references/publish-targets.md`. Mostly a no-op for project-internal modules.

## Inputs

```
/magento2-release [--version=X.Y.Z] [--no-publish] [--no-github-release] [--dry-run] [--docs-root=<path>] <Vendor>_<Module>
```

| Flag                  | Default       | Meaning                           |
|-----------------------|---------------|-----------------------------------|
| `--version`           | auto-detected | Override the proposed version     |
| `--no-publish`        | off           | Skip Phase 7                      |
| `--no-github-release` | off           | Skip Phase 6                      |
| `--dry-run`           | off           | Print everything; make no changes |
| `--docs-root`         | unset         | Output-root override; see "Output root" below |

## Outputs

```
composer.json (updated)
CHANGELOG.md (updated)
git tag {Vendor}_{Module}-{Version}
GitHub Release page (if Phase 6 ran)

{output_root}/releases/{Module}-{Version}.md       # Generated release notes
```

`{output_root}` defaults to `.docs` (`{ctx.docs_root}`); see the `--docs-root`/`DOCS_ROOT`
recipe in `magento2-context/references/artifact-layout.md`.

### Output root (`--docs-root`)

This skill accepts `--docs-root=<path>` (see
`magento2-context/references/artifact-layout.md`). When set, write the run report (and any
report artifacts) under `<path>/releases/`; otherwise default to
`{ctx.docs_root}/releases/`. `magento2-feature-implement` passes this so a feature run's
reports collect under its folder.

## Reference Files

- `references/semver-rules.md` — conventional commit → version bump rules.
- `references/changelog-format.md` — commit → category mapping and entry-generation
  procedure; cites `magento2-context/references/changelog-format.md` for structure.
- `references/tag-format.md` — multi-module tag prefix rules.
- `references/publish-targets.md` — Packagist, private Composer registries (Private Packagist / Satis / VCS),
  Marketplace EQP.

## Templates

- `templates/release-notes.md` — release notes structure.

## Acceptance Criteria

- Version bump matches semver convention.
- CHANGELOG entries reflect actual commits since last tag.
- No release happens if Phase 2 validate fails.
- Tag is signed if `git config tag.gpgsign` is true (tag signing reads `tag.gpgsign`, not `commit.gpgsign`).
- Release notes paste cleanly into GitHub Release.

## Multi-Module Repo

If multiple modules live in the same repo:

- Tag prefix disambiguates (`Acme_OrderExport-1.4.0` vs `Acme_Inventory-2.0.1`)
- Each module's `composer.json` is independent
- `CHANGELOG.md` lives in each module folder
- The skill releases ONE module per invocation

## Related Skills

| Phase | Skill                                                  |
|-------|--------------------------------------------------------|
| 0     | `magento2-context`                                     |
| 2     | `magento2-deploy --validate-only --strict --env=local` |
| 6     | external: `gh` CLI                                     |
