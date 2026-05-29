# Semver Rules

## Bump Detection (Conventional Commits)

| Commit prefix | Bump |
|---------------|------|
| `feat:` | minor |
| `fix:` | patch |
| `perf:` | patch |
| `refactor:` | patch |
| `docs:` | none (auto-skipped from CHANGELOG) |
| `test:` | none |
| `chore:` | none |
| `feat!:` or `fix!:` (with `!`) | major |
| `BREAKING CHANGE:` in body | major |

## Walk Algorithm

```
1. List commits since last tag matching {Vendor}_{Module}-*:
   git log {lastTag}..HEAD --pretty=format:"%H %s%n%b%n---"
2. Classify each. The highest bump wins:
   - any major → major bump
   - else any minor → minor bump
   - else patch bump (default for any non-skipped commit)
3. Compute new version from current:
   - current = "1.4.2"
   - major   → "2.0.0"
   - minor   → "1.5.0"
   - patch   → "1.4.3"
```

## Multiple BC Breaks Per Release

A release with multiple BC breaks still bumps major exactly once. The CHANGELOG lists
each.

## Pre-Release Identifiers

If the user passes `--version=2.0.0-rc.1`, the skill respects it. Otherwise stable
versions are the default.

Pre-release versions in `composer.json` REQUIRE `"minimum-stability": "RC"` (or lower) in
the consuming project's composer.json. Note this in the release report when the version
contains a pre-release identifier.

## Initial Release (`0.x.y`)

For a brand-new module:
- Start at `0.1.0`.
- Bump minor for `feat:` commits.
- Bump patch for everything else.
- BC breaks during 0.x do NOT trigger major bump — they bump minor (0.x is unstable by
  semver convention).
- First stable release: `1.0.0`.

## Version Comparison Edge Cases

- `1.4.0` < `1.4.1` < `1.5.0` < `2.0.0`
- `1.4.0` < `1.4.0-rc.1` is FALSE — pre-release sorts BEFORE the stable
- `1.4.0-alpha` < `1.4.0-beta` < `1.4.0-rc.1` < `1.4.0`

## Anti-Pattern: Forced Bump

If the user passes `--version=999.0.0` on a module that's at `1.2.3`, allow it but warn:

> Forced version jump: 1.2.3 → 999.0.0. Pre-flight will be done; tag will be applied.
> Confirm? (yes/no)

## Detecting "No Releasable Changes"

If all commits since last tag are `docs:`, `test:`, or `chore:`, refuse to release:

> No releasable changes since {lastTag}. All commits are docs/test/chore. Skipping
> release. To force, pass --force.

## Recording Bump Reasoning

The release notes include the bump reasoning so future readers understand:

```markdown
## [1.5.0] — 2026-05-24

Bump: minor (3 features added; no breaks).

### Added
- ...
```
