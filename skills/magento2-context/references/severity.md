# Severity Scale (Shared)

The five-point severity scale used by **every** findings-producing magento2-* skill:
`magento2-module-review`, `magento2-security-audit`, `magento2-performance-audit`,
`magento2-module-upgrade`. Each consumer may add skill-specific calibration anchors;
the *meanings* of the levels are shared.

## Levels

| Level | Meaning |
|-------|---------|
| **Critical** | Exploitable auth/payment/data-loss issue, RCE, secret leak, or deployment-breaking defect. Block release; fix immediately. |
| **High** | Security bypass, broken public API, unsafe state mutation, serious data integrity issue, or DI/schema issue likely to break production. Block release; fix before merge. |
| **Medium** | Magento architectural violation, missing validation, maintainability issue likely to cause defects, or insufficient tests for risky logic. Should fix; documented if deferred. |
| **Low** | Style, documentation, naming, minor best-practice gap, optional hardening. Cosmetic; deferral acceptable. |
| **Info** | Positive observation, skipped check, context, or non-blocking recommendation. No action required. |

## Calibration Anchors (Cross-Skill)

| Severity | Example |
|----------|---------|
| Critical | Hardcoded credentials in committed code |
| Critical | `eval()` / `shell_exec()` on user-controlled input |
| Critical | Payment data path without auth check |
| Critical | RCE-class CVE in a direct dependency |
| Critical | DI-compile-failing class signature |
| High | Anonymous REST endpoint exposing non-public data |
| High | Admin controller missing `ADMIN_RESOURCE` constant |
| High | POST controller without form key validation |
| High | PHTML echoing `$_GET`/`$_POST` without `$escaper` |
| High | `ObjectManager::getInstance()` in production code |
| High | Raw SQL with user-interpolated values |
| High | `db_schema.xml` column drop without whitelist entry |
| High | External HTTP on storefront critical path without timeout |
| Medium | `<preference>` rewriting a core class without owning its interface |
| Medium | Repository loading full collection where `SearchCriteria` should be used |
| Medium | Data patch not checking for existing data before insert |
| Medium | Missing DB index on hot-path WHERE column |
| Medium | `csp_whitelist.xml` absent when external JS is loaded |
| Medium | ACL resource defined but not referenced |
| Medium | Missing tests for money / auth / data-mutation logic |
| Medium | GraphQL resolver loading entity per item instead of batching |
| Low | `etc/module.xml` has obsolete `setup_version` |
| Low | `i18n/en_US.csv` missing or incomplete |
| Low | `README.md` missing installation section |
| Low | PHPDoc `@param` uses short class name instead of FQCN |
| Info | Static analysis tool skipped because `vendor/bin/phpstan` absent |
| Info | All PHTML output passes through `$escaper` (positive) |

## Adjustment Rules

- **Raise one level** when:
  - The vulnerable path is reachable without authentication
  - Affected data includes PII or payment information
  - The defect is in a hot path that cannot be disabled

- **Lower one level** when:
  - The affected surface requires admin credentials
  - The issue is theoretical with no confirmed user-controlled input
  - The module is internal/not customer-facing

- **Never lower below Medium** for any confirmed XSS, CSRF, or SQL injection.

## Suspected-but-Unconfirmed Vulnerabilities

When static analysis can't trace the full attack path (e.g. `getParam()` flows through
multiple service layers before a query):

- Report as **Medium** with `[Needs verification]` flag.
- State exactly what is suspicious and which part of the chain is unconfirmed.
- Do not escalate to High without tracing the user-controlled value to the sink.
- Do not suppress to Info if the pattern matches a known dangerous API.
- Suggest a specific manual verification step.

## Output

Every finding must include impact, evidence, recommendation, and a verification or test
suggestion. Severity tagged at the title.
