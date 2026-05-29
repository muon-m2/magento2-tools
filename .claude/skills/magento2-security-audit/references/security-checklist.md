# Security Audit Checklist

The full pattern catalogue for Phase 4 (Magento static pattern pass). Each item maps to
a finding category from `magento2-context/references/findings-schema.md`.

## CSRF (category: `csrf`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Admin POST without `HttpPostActionInterface` | Controller in `Controller/Adminhtml/` with `execute()` and no `implements HttpPostActionInterface` | High |
| FormKey validator not invoked | POST controller without `FormKeyValidator::validate()` | High |
| `_isAllowed` returns true unconditionally | `_isAllowed()` always returns true | High |
| Frontend POST without CSRF check | Frontend controller with `HttpPostActionInterface` but no `validateForCsrf()` | High |

## Auth (category: `auth`)

| Check | Pattern | Severity |
|-------|---------|---------|
| `anonymous` ACL on data-returning REST endpoint | `webapi.xml` resource=`anonymous` with GET/POST returning customer/order data | Critical |
| GraphQL mutation without auth check | Resolver class without `ContextInterface::getExtensionAttributes()->getIsCustomer()` check | Critical |
| Hardcoded admin token in code | grep for `Bearer\s+[A-Za-z0-9]{32,}` in source | Critical |

## Session (category: `session`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Session writes in observers | Observer modifying `$session->set*` | Medium |
| `setCookie` with `httpOnly=false` | grep `setHttpOnly\(false\)` | Medium |
| `setCookie` with `secure=false` outside dev | grep `setSecure\(false\)` | Medium |
| Long-lived session cookie | `lifetime` > 86400 in `session_cookie_lifetime` | Low |

## Cookie (category: `cookie`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Missing `SameSite` attribute | Cookie set without `setSameSite` | Medium |
| Cookie containing sensitive data | grep for cookie names like `auth_token`, `secret`, `pii` | High |

## ACL (category: `acl`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Wildcard ACL ID | grep `<resource id=".*\*"` in `etc/acl.xml` | Medium |
| Admin route without `_isAllowed` | Adminhtml controller missing `_isAllowed()` override | High |
| ACL granted to everyone via default config | `Magento_Backend::admin` granted in module's defaults | Medium |

## Preference Collision (category: `preference-collision`)

| Check | Pattern |
|-------|---------|
| Two modules declare `<preference for="X"/>` for the same X | Walk all `di.xml` files |
| `<preference>` on a payment/order/customer class | Audit each instance with extra scrutiny |

## Cron Ownership (category: `cron-ownership`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Cron running as web user | Process listing shows cron worker process owner | Medium |
| Cron job touches credentials file readable only by magento user | Permission mismatch | High |

## GraphQL Auth (category: `graphql-auth`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Mutation without `@auth` directive | Schema mutations missing `@auth` | High |
| Resolver doesn't check `ContextInterface::getUserType()` | Class scan | High |
| Customer mutation accessible to guests | Schema + resolver inconsistency | Critical |

## Input Validation (category: `input-validation`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Raw SQL with unescaped input | grep for `$connection->query("...$var...")` | Critical |
| `unserialize()` on user input | grep `unserialize(.*\$_REQUEST` or similar | Critical |
| Path traversal in file ops | grep file ops using user-controlled paths | High |
| XSS in template via raw output | grep `echo \$` or `?>...<?php echo` in `.phtml` | High |

## Encryption (category: `encryption`)

| Check | Pattern | Severity |
|-------|---------|---------|
| MD5/SHA1 for sensitive data | grep `md5(` or `sha1(` for passwords/PII | High |
| Hardcoded encryption key | grep for static keys in source | Critical |
| Custom encryption (not via Magento Crypt) | Class implementing own AES/RSA | Medium |

## Logging (category: `logging`)

| Check | Pattern | Severity |
|-------|---------|---------|
| PII logged in plain text | grep for `$logger->info("...$customer..."` patterns | High |
| Credit card data in logs | grep for CC patterns near `$logger->` | Critical |
| Authentication failures not logged | Admin login failures with no log call | Low |

## File System (category: `filesystem`)

| Check | Pattern | Severity |
|-------|---------|---------|
| Writable production paths | `chmod 777` in setup scripts | High |
| File operations without permission check | `file_put_contents` in production paths | Medium |

## How Each Item Becomes a Finding

```json
{
  "id": "security-audit-2026-05-24-001",
  "severity": "high",
  "category": "csrf",
  "subcategory": "admin-post-missing-formkey",
  "title": "POST controller missing form key validation",
  "evidence": [
    { "file": "Controller/Adminhtml/Order/Save.php", "line": 47 }
  ],
  "recommendation": "Implement HttpPostActionInterface and call FormKeyValidator::validate().",
  "verification": "Re-run audit; or run vendor/bin/phpunit Test/Unit/Controller/SaveTest.php"
}
```
