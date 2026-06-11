# Bug Fix Report: {Symptom one-liner}

Bug ID: {slug}
Date: {YYYY-MM-DD}
Status: Resolved

## Symptom

{One paragraph.}

## Severity

{critical | high | medium | low}

## Reproduction

Recipe: `.docs/bug-fixes/{slug}/reproduction.md`

## Root Cause

{One paragraph.} Full RCA: `.docs/bug-fixes/{slug}/rca.md`

## Fix Summary

{One paragraph describing the change.}

## Files Changed

| File                                                   | Change        |
|--------------------------------------------------------|---------------|
| `{ctx.magento_root}/app/code/{Vendor}/{Module}/{Path}` | {description} |

## Regression Test

Path: `{ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/{...}Test.php`
Pre-fix: failing assertion confirmed.
Post-fix: passing assertion confirmed.
Suite result: {N passed / 0 failed}.

## Review Findings

| Severity | Count | Notes                |
|----------|-------|----------------------|
| Critical | 0     | —                    |
| High     | 0     | —                    |
| Medium   | {N}   | {if any: brief list} |
| Low      | {N}   | {if any: brief list} |

Critical/High findings introduced by the fix: 0 (else: list and resolution).

## Deploy

{Did Phase 6 run? Environment? Smoke result? Path to deploy report.}

## Deferred Issues

{From RCA's Deferred Issues section; offer to start new bug-fix runs.}

## Verification Steps

1. Apply patch (commits listed below).
2. Run `{ctx.runner} vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit/{...}Test.php`.
3. Re-run the reproduction recipe — confirm success.

## Commits

- `{SHA1}` — {commit subject}
- `{SHA2}` — {commit subject}
