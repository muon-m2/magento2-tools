# Static Analysis Tool Matrix

Use tools opportunistically. Missing tools are skipped checks, not module defects.

## Safe File-Only Checks

```bash
php -l <php-file>
xmllint --noout <xml-file>
php -r 'json_decode(file_get_contents($argv[1]), true, 512, JSON_THROW_ON_ERROR);' <json-file>
composer validate <module-composer-json> --strict
# Add --with-dependencies when vendor/ is installed to catch unresolvable constraints:
composer validate <module-composer-json> --strict --with-dependencies
```

## Magento/PHP Quality Tools

```bash
vendor/bin/phpcs --standard=Magento2 <module-path>
vendor/bin/phpmd <module-path> text phpmd.xml
vendor/bin/phpstan analyse <module-path>
vendor/bin/psalm --show-info=false <module-path>
vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist <module-path>/Test/Unit
vendor/bin/rector process <module-path> --dry-run
```

## Fix Mode Only (run only when the user explicitly requests fixes)

```bash
vendor/bin/phpcbf --standard=Magento2 <module-path>
```

## Security Tools

```bash
semgrep scan <module-path>
composer audit
vendor/bin/security-checker security:check
```

## Frontend Tools

Use only when the project has matching scripts/config and the module contains frontend assets:

```bash
npm run lint
npm run test
npm run typecheck
```

## Optional Magento Runtime Checks

Run only when a working Magento installation is clearly available and the user wants validation:

```bash
bin/magento setup:di:compile
bin/magento setup:db-declaration:generate-whitelist --module-name=<Vendor_Module>
bin/magento i18n:collect-phrases <module-path> -o /tmp/<module>.csv
```

Classify failures carefully:

- Missing `vendor/`, missing `bin/magento`, missing DB, unsupported PHP, permissions, and absent env config are
  environment-blocked.
- DI compile errors pointing to module class signatures, invalid XML, or missing constructor args are module findings.
- Schema whitelist differences are module findings only when declarative schema is otherwise valid and the Magento CLI
  ran successfully.
- Composer warnings are usually Low/Info unless they break installation or package resolution.

