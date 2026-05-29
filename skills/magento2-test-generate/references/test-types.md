# Test Types

When each test type is required, and how to detect that requirement from the module's
file inventory.

## Unit (Always)

Every PHP class in the module other than tests, registration, and pure data containers
gets a unit test. Source-class detection:

```
find {module}/Api {module}/Service {module}/Model {module}/Plugin {module}/Observer \
     {module}/Controller {module}/Cron {module}/Queue {module}/ViewModel {module}/Block \
     -name '*.php' -not -path '*/Test/*'
```

Skip:
- Interfaces (no implementation to test)
- Data containers (only getters/setters from a parent class)
- Constants-only classes

## Integration (Persistence Modules)

Generate when the module has any of:
- `etc/db_schema.xml`
- `Setup/Patch/Schema/*.php`
- `Setup/Patch/Data/*.php`

Tests required:
- **Schema test** — tables exist, columns match declaration, foreign keys present.
- **Repository test** — save → getById → getList → delete round-trip.
- **Data patch test** — patch applies cleanly to an isolated DB; assertions on seeded
  rows.

Requires Magento integration test bootstrap.

## API (REST/GraphQL Modules)

### REST

Generate when `etc/webapi.xml` exists. Per route:
- 200 happy path with auth
- 401 unauthorized when no token
- 403 forbidden when token lacks ACL
- 400 bad input for invalid payload
- 404 for non-existent resource

### GraphQL

Generate when `etc/schema.graphqls` exists. Per query/mutation:
- Positive shape (data structure matches schema)
- Auth fail (anonymous mutation → error)
- Input error (invalid args → GraphQlInputException)
- Pagination edge case (page beyond results)

## Jasmine (JS-Heavy Modules)

Generate when the module has any of:
- `view/frontend/web/js/*.js` (non-trivial — > 50 lines)
- `view/frontend/web/template/*.html` (KO templates)
- `view/frontend/requirejs-config.js`

Tests per RequireJS module / KO component:
- Module loads without error.
- Initial state matches default.
- Public method behaves per its contract.

## MFTF (Admin UI Modules)

Generate when the module has any of:
- `view/adminhtml/ui_component/*_listing.xml`
- `view/adminhtml/ui_component/*_form.xml`

Tests per listing + form pair:
- Listing renders without error.
- Add-new flow creates a record and verifies it appears in listing.
- Edit flow modifies an existing record and verifies the change.
- Delete flow removes a record and verifies its absence.

## Test Path Conventions

```
{ctx.magento_root}/app/code/{Vendor}/{Module}/
├── Test/Unit/                    # Unit tests
│   ├── Model/SomeServiceTest.php
│   └── Plugin/SomePluginTest.php
├── Test/Integration/             # Integration tests
│   └── Model/SomeRepositoryTest.php
├── Test/Api/                     # REST API tests
│   └── SomeApiTest.php
├── Test/Api/GraphQl/             # GraphQL API tests
│   └── SomeMutationTest.php
├── Test/Mftf/                    # MFTF tests
│   ├── Section/SomeSection.xml
│   ├── Page/SomePage.xml
│   └── Test/SomeTest.xml
└── view/frontend/web/js/test/    # Jasmine tests
    └── some-component.test.js
```

## Coverage Calculation

Coverage % = (lines covered by tests / lines in source) × 100

Source lines exclude:
- Blank lines
- Comment-only lines
- `<?php`, `declare`, `use`, `namespace` lines
- Class/interface/trait declarations
- Constant declarations

Use Clover XML from `vendor/bin/phpunit --coverage-clover` to measure. Cap at the
module's `Api/ Service/ Model/` directories — UI and config are typically excluded.
