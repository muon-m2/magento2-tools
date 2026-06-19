# Packaging for Adobe Marketplace

Reference for how to structure, validate, and build a Marketplace-ready composer package.
`magento2-marketplace-prep` is read-only and never runs these commands; this document
explains what the checks in `check-readiness.sh` look for and what the vendor must do
before submitting.

## Composer Package Structure

A Marketplace extension package must be a self-contained `composer.json` directory with
the following structure:

```
{Module}/
├── composer.json          # type: magento2-module; declares version, license, autoload
├── LICENSE                # or LICENSE.txt
├── README.md
├── registration.php
├── etc/
│   └── module.xml
├── [additional source files]
└── Test/                  # included in source, excluded from production package
    ├── Unit/
    ├── Integration/
    └── Mftf/
```

## Required composer.json Fields

```json
{
  "name": "acme/module-order-export",
  "description": "A brief description of what the extension does.",
  "type": "magento2-module",
  "version": "1.0.0",
  "license": "OSL-3.0",
  "authors": [
    {
      "name": "Acme Corp",
      "email": "extensions@acme.example.com"
    }
  ],
  "require": {
    "php": ">=8.1",
    "magento/framework": ">=102.0 <104"
  },
  "autoload": {
    "psr-4": {
      "Acme\\OrderExport\\": ""
    },
    "files": ["registration.php"]
  },
  "archive": {
    "exclude": [
      "Test/Unit",
      "Test/Integration",
      ".github",
      "*.lock",
      ".gitignore",
      ".travis.yml"
    ]
  }
}
```

## Version Constraint Rules

Marketplace requires **stable** version constraints only:

| Pattern | Allowed | Notes |
|---------|---------|-------|
| `^1.0` | Yes | Semver caret range |
| `>=1.0 <2.0` | Yes | Explicit range |
| `1.0.*` | Yes | Minor wildcard |
| `dev-main` | **No** | Dev branch reference |
| `@dev` | **No** | Dev stability flag |
| `*` (wildcard alone) | **No** | Unbounded constraint |
| `~1.0.0` | Yes | Tilde range (patch only) |

## Validating the Package

Run these commands from the module root before submission. `magento2-marketplace-prep`
does **not** run them (read-only), but it checks the conditions they depend on:

```bash
# 1. Validate composer.json structure
composer validate --strict

# 2. Simulate package creation (no write — inspect the manifest)
composer archive --format=zip --dir=/tmp/pkg-test --dry-run 2>&1

# 3. Check for excluded files in the dry-run manifest
# Any test/, .github/, .env, node_modules/ should NOT appear.
```

## What to Exclude from the Package

Use `archive.exclude` in `composer.json` to omit:

- `Test/Unit`, `Test/Integration` — dev tests (MFTF may be included or excluded
  depending on Marketplace requirement; check the current EQP guidelines).
- `.github/`, `.travis.yml`, `.circleci/` — CI configuration.
- `*.lock`, `composer.lock` — dependency snapshots (consumers manage their own lockfile).
- `.env`, `.env.local`, `*.log` — environment and debug files.
- `node_modules/`, `vendor/` — never commit these.
- `*.DS_Store`, `Thumbs.db` — OS metadata files.

## Submission Checklist

Before uploading to Marketplace:

1. `composer validate --strict` exits 0.
2. `composer archive` produces a zip with no dev artifacts.
3. All blocker findings from `magento2-marketplace-prep` are resolved.
4. All blocker findings from `magento2-security-audit` (EQP static scan) are resolved.
5. Version in `composer.json` matches the Marketplace submission version.
6. `magento2-release` has been run to bump version and update `CHANGELOG.md`.

## Related References

- `eqp-checklist.md` — full EQP submission checklist.
- `readiness-scoring.md` — score formula and verdict.
- `magento2-security-audit/references/eqp-rules.md` — EQP static code rules.
- `magento2-release` — version bump, changelog, tag, and publish workflow.
