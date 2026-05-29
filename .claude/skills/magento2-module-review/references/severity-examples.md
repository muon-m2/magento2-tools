# Magento Severity Calibration Matrix

Use these canonical examples to calibrate severity consistently. When a finding resembles an entry, use that severity as the baseline and adjust up or down only when concrete contextual evidence justifies it.

## Critical

| Finding | Why Critical |
|---|---|
| Hardcoded credentials, tokens, or API keys in committed PHP or XML | Direct secret leak; immediately exploitable by anyone with repo access |
| `eval()`, `shell_exec()`, `exec()` on user-controlled input | Remote code execution |
| Payment or order data written/read without authentication check | Data loss or financial fraud path |
| `unserialize()` on untrusted input with no class allowlist | PHP object injection; potential RCE |
| Deployment-breaking DI compile error (missing class, invalid constructor arg) | Blocks `setup:di:compile`; prevents deployment |

## High

| Finding | Why High |
|---|---|
| REST endpoint in `webapi.xml` with `resource="anonymous"` exposing non-public data | Unauthenticated data access |
| Admin controller missing `ADMIN_RESOURCE` constant or `_isAllowed()` | Any authenticated user can reach admin functionality |
| POST controller not validating form key and not implementing `CsrfAwareActionInterface` | CSRF; state mutation without consent |
| GET controller that writes to DB or sends email | Idempotency violation; exploitable via link/image embed |
| PHTML template echoing `$_GET`/`$_POST` or `getParam()` without `$escaper` | Stored or reflected XSS |
| `ObjectManager::getInstance()` injecting a concrete class in production code | Bypasses DI; untestable; breaks compile-time graph validation |
| Raw SQL with user-controlled interpolation (no bind/quote) | SQL injection |
| Schema `db_schema.xml` column or table dropped without a whitelist entry | Irreversible migration failure on upgrade |
| External HTTP call on a storefront critical path with no timeout | Storefront outage when third party is slow |

## Medium

| Finding | Why Medium |
|---|---|
| `<preference>` rewriting a Magento core class without owning its interface | Plugin conflicts; upgrade fragility |
| Repository method loading full collection when `SearchCriteria` with pagination should be used | Memory exhaustion on large catalogs |
| Data patch not checking whether data already exists before inserting | Duplicate data on repeated `setup:upgrade` |
| `etc/config.xml` default for a sensitive field (API key, password) set to a non-empty value | Credential present in default state |
| Missing DB index on a column used in a `WHERE` clause by a hot query | Query slowdown at scale; not immediate but predictable |
| `csp_whitelist.xml` absent when module loads external JS or makes XHR to a third-party domain | CSP violation in strict-mode stores |
| ACL resource defined but not referenced in `system.xml` `<resource>` or admin route | Config section accessible to any admin role |
| Unit tests absent for service or repository logic that handles money, auth, or data mutation | No regression safety for the highest-risk code paths |
| GraphQL resolver loading full product/customer object per item instead of batching | N+1 query; DoS vector on public queries |

## Low

| Finding | Why Low |
|---|---|
| `etc/module.xml` has `setup_version` attribute on a module that uses declarative schema | Harmless legacy attribute; generates a deprecation notice |
| `i18n/en_US.csv` absent or incomplete | User-facing strings not translatable; Low unless release gate requires it |
| `README.md` missing installation or configuration instructions | Documentation gap; no runtime impact |
| Constructor parameter order differs from `di.xml` argument order | Confusing but not a runtime failure if types are unambiguous |
| PHPDoc `@param` uses a short class name instead of FQCN | Violates Magento standard; no runtime impact |
| `composer.json` version constraint uses `*` for a Magento package | Resolution risk on `composer update`; Low if lock file is committed |

## Info

| Finding | Why Info |
|---|---|
| Tool skipped because `vendor/bin/phpstan` not present | Environment limitation; not a module defect |
| Module uses `Magento\Framework\DataObject` instead of a typed DTO | Acceptable pattern in many Magento contexts; note only if API is public |
| Positive: all PHTML output passes through `$escaper` | Confirms correct escaping practice |
| Positive: all admin routes declare `ADMIN_RESOURCE` | Confirms ACL coverage |

## Adjustment Rules

- **Raise one level** when: the vulnerable path is reachable without authentication, the affected data includes PII or payment info, or the defect is in a hot path that cannot be disabled.
- **Lower one level** when: the affected surface requires admin credentials, the issue is theoretical with no confirmed user-controlled input, or the module is internal/not customer-facing.
- **Never lower below Medium** for any confirmed XSS, CSRF, or SQL injection, regardless of perceived exploitability.

## Suspected but Unconfirmed Vulnerabilities

When a pattern looks risky but the full attack path cannot be traced through static analysis alone (e.g., a
`getParam()` value passes through multiple service layers before reaching a query):

- Report as **Medium** with a `[Needs verification]` flag.
- State exactly what is suspicious and which part of the call chain could not be confirmed.
- Do not escalate to High without tracing the user-controlled value to the sink.
- Do not suppress to Info if the pattern matches a known dangerous API (raw SQL, `exec`, `unserialize`, `eval`).
- Suggest a specific manual verification step: e.g., "trace `$customerId` from `getParam('id')` through
  `OrderService::load()` to confirm whether it reaches the raw query on line 47."
