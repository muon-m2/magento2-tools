# {Vendor}_{Module} {Version}

Released: {YYYY-MM-DD}
Bump: {major | minor | patch}
Skill versions:

- magento2-release@1.2.0
- magento2-deploy@1.3.0
  - magento2-context@1.8.0

## Highlights

{One paragraph summary of what's in this release.}

## What's Changed

### Added

- ...

### Changed

- ...

### Deprecated

- ...

### Fixed

- ...

### Security

- ...

## Compatibility

- Magento: {minimum} – {maximum tested}
- PHP: {minimum} – {maximum tested}
- Edition: open-source / commerce

## Upgrade Notes

{If any BC breaks: paste the relevant section of UPGRADE.md here.}

## Verification

```bash
composer require {vendor}/{package}:{version}
{ctx.magento_cli} setup:upgrade
{ctx.magento_cli} cache:flush
```

## Commits

- {SHA1} feat: ...
- {SHA2} fix: ...
- ...

## Acknowledgements

Thanks to contributors {names if applicable}.
