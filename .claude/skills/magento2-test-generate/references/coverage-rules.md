# Coverage Rules

## Target

≥ 80% line coverage across `Api/`, `Service/`, `Model/` for every module.

## Exemptions

The following are NOT counted against coverage:
- `registration.php`
- `etc/*.xml` (config; tested separately via schema validation)
- `view/**/*.phtml` (rendering; tested via MFTF / integration)
- `Test/**/*.php` (tests are not tested)
- Data containers with only getters/setters from a parent

## Per-File Floor

A single file should be ≥ 70% covered to count as "tested." A module with one 95%-covered
file and four 0%-covered files is NOT 80% — it's 19% on average.

## How to Measure

```bash
{ctx.runner} XDEBUG_MODE=coverage vendor/bin/phpunit \
    --coverage-clover var/log/coverage-{Vendor}_{Module}.xml \
    {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Unit
```

Then parse the Clover XML for per-file coverage. Total coverage is line-weighted, not
file-averaged.

## When 80% Is Not Reachable

Some modules genuinely can't hit 80% (heavy XML config + thin PHP wrapper). Document the
gap with a per-file justification:

```markdown
## Coverage Exemptions

| File | Coverage | Justification |
|------|----------|---------------|
| Block/Adminhtml/Form.php | 32% | Tightly coupled to admin layout; tested via MFTF instead. |
| Helper/Data.php | 0% | Empty class extending AbstractHelper; will be removed in next refactor. |
```

The user decides whether to accept the gap.

## Coverage Reports Are Snapshots

Coverage % is a snapshot at one point in time. If the source class changes and the test
doesn't, coverage degrades silently. Re-measure on every CI run.

## Coverage Without Xdebug

If Xdebug is unavailable:
- PCOV (`{ctx.runner} php -d pcov.enabled=1`) is a faster alternative.
- Without either: skip coverage measurement; report "coverage unmeasurable in this
  environment" but still verify tests pass.

## Don't Optimize for Coverage

Coverage % is a useful number but not the goal. A test that asserts `true === true` to
boost coverage is worse than no test. The goal is **meaningful** coverage — tests that
catch real bugs.

When generating tests, prefer one assertion that nails a behaviour over five assertions
that pad coverage with trivia.
