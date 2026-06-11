# Evidence Citation Rules

Every finding must cite concrete evidence. The citation form depends on finding type.

## Grep / Code Match

Cite `file:line` and quote the matched fragment:

```
Evidence: `Model/Service/OrderProcessor.php:47` — `ObjectManager::getInstance()->get(...)` used directly.
```

For multi-line matches, cite the opening line and describe the span:

```
Evidence: `Model/ResourceModel/Report.php:89–104` — raw SQL built by string concatenation with `$customerId`
          passed directly from request param with no bind or quote.
```

## XML Structure

Cite the nearest named ancestor element (type, id, name, or for attribute) so the location is unambiguous without a line
number:

```
Evidence: `etc/di.xml` — <type name="Acme\OrderGrid\Model\Service"> configures a concrete Session
          dependency without a Proxy, causing full session bootstrap on every DI graph instantiation.
```

For `webapi.xml`:

```
Evidence: `etc/webapi.xml` — <route url="/V1/acme/orders" method="GET"> declares resource="anonymous";
          endpoint returns full order data including customer email.
```

## Missing Required File

State what was expected, what command confirmed absence, and what the impact is:

```
Evidence: `etc/acl.xml` absent — verified with `find etc/ -name 'acl.xml'` (no output).
          Admin routes in `Controller/Adminhtml/` reference ADMIN_RESOURCE but no ACL tree declares it.
```

```
Evidence: `i18n/en_US.csv` absent — verified with `find i18n/ -name '*.csv'` (no output).
          7 `__()` calls found in templates with no translation file present.
```

## Missing Required Pattern (absence in existing files)

Cite the file and the check that confirmed absence:

```
Evidence: `Controller/Adminhtml/Order/Save.php` — no call to `$this->_isAllowed()` or
          `ADMIN_RESOURCE` constant. Grep: `grep -n "ADMIN_RESOURCE\|_isAllowed" Controller/Adminhtml/Order/Save.php`
          returned no matches.
```

## Cross-File Architectural Finding

Cite the declaration point first, then the consumption point:

```
Evidence: Declaration — `etc/di.xml:23` configures <preference for="Magento\Catalog\Api\ProductRepositoryInterface"
          type="Acme\Catalog\Model\ProductRepository">.
          Impact — `Model/Service/SyncService.php:15` injects the interface; the concrete substitution overrides
          all third-party plugins registered on the original implementation.
```

## Config Default

Cite the `config.xml` or `system.xml` field that sets the default:

```
Evidence: `etc/config.xml:18` — <api_key>hardcoded_default_value</api_key> under path
          acme_integration/settings/api_key. Any store that does not reconfigure this key
          sends requests with a shared credential.
```

## Skipped Check / Environment Limitation

Cite the reason, not a finding:

```
Evidence: SKIPPED — `vendor/bin/phpstan` not present in this environment.
          Static type analysis results are unavailable; findings in this area are based on code inspection only.
```

## General Rules

- Never cite only a directory. Always cite a file or a confirmed absence command.
- For large files (>200 lines), include the line number even for XML findings.
- Quote enough of the problematic code or config that the finding is self-contained without opening the file.
- For "absence" findings, always show the command used to verify absence, not just assert it.
