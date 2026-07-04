# CHANGELOG Format (Canonical)

This is the single structural authority for every module `CHANGELOG.md` produced or
touched by the `magento2-*` skill pack. `magento2-docs-generate` renders it (scaffold),
`magento2-release` populates it (commit → category mapping, generation procedure), and
`magento2-module-create` delegates to `magento2-docs-generate` for it. Do not fork this
structure elsewhere — skills that need CHANGELOG behaviour cite this file.

Following Keep a Changelog (https://keepachangelog.com).

## Structure

```markdown
# Changelog

All notable changes to {Vendor}_{Module} are documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [Unreleased]

### Added
- ...

## [1.5.0] - 2026-05-24

### Added
- Support for batch GraphQL resolvers in the orders module.
- New REST endpoint `/V1/acme/orders/health`.

### Changed
- Bumped Magento minimum to 2.4.7.

### Deprecated
- `OrderRepository::loadByIncrementId()` — use `getByIncrementId()` instead. Removed in 2.0.

### Fixed
- N+1 in checkout totals collection (CVE-2024-XXXX impact mitigated).

### Removed
- Legacy `Setup/InstallData.php`.

### Security
- Tightened CSP for admin order save controller.

## [1.4.2] - 2026-04-30

### Fixed
- Bug fix description.

## [1.4.1] - 2026-04-15
...
```

## Entry Categories

| Category   | When to use                            |
|------------|----------------------------------------|
| Added      | New feature, new public API            |
| Changed    | Behaviour change in existing feature   |
| Deprecated | Marked for removal in a future release |
| Removed    | Removed in this release                |
| Fixed      | Bug fix                                |
| Security   | Security-related fix or hardening      |

Skip empty categories — don't list "### Added" with no items.

## Linking

Add reference links at the bottom for tag comparison:

```markdown
[Unreleased]: https://github.com/vendor/repo/compare/Vendor_Module-1.5.0...HEAD
[1.5.0]: https://github.com/vendor/repo/compare/Vendor_Module-1.4.2...Vendor_Module-1.5.0
[1.4.2]: https://github.com/vendor/repo/compare/Vendor_Module-1.4.1...Vendor_Module-1.4.2
```

## Multi-Module Repos

Each module's `CHANGELOG.md` lives in the module folder:

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/CHANGELOG.md
```

The skill updates one file per release.
