# Regression Test Patterns by Bug Class

Every bug fix requires a test that fails before the fix and passes after. The test class
location and shape depend on the bug's class.

**File convention.** Prefer adding a `testRegression{Behaviour}()` method to the module's
**existing** test class for the subject under test (e.g. an existing
`{TargetClass}Test.php`) — this keeps related tests together and discoverable. Only when
no test class exists for that subject do you create a new file, named per the locations
below (e.g. `Test/Unit/Observer/{Name}Test.php`). The `templates/regression-test-*.php`
skeletons are starting points; rename the class to match the module's convention rather
than forcing a `RegressionTest` suffix. All paths are rooted at
`{ctx.magento_root}/app/code/{Vendor}/{Module}/`.

## Class: Plugin / Interceptor Bug

Test the plugin in isolation. Mock the target object and assert plugin behaviour.

Location: `Test/Unit/Plugin/{TargetClass}Plugin{Name}Test.php`

Skeleton: `templates/regression-test-unit.php` (uses MockObject pattern).

Key assertions:
- The `before*` / `around*` / `after*` method is called with the expected args.
- The plugin returns the expected value.
- The plugin does NOT swallow exceptions when the target throws.

## Class: Observer Bug

Test the observer with a mocked `Event` and `Observer` object.

Location: `Test/Unit/Observer/{Name}Test.php`

Skeleton: `templates/regression-test-unit.php`.

Key assertions:
- The observer reads the expected event data.
- The observer mutates state via the expected service.
- The observer does NOT throw on missing event data (use `getData('key', null)` then
  null-check).

## Class: DI / Construction Bug

When the bug is in `__construct` (e.g. wrong service injected, missing default), test the
class instantiates correctly with the real DI graph.

Location: `Test/Unit/{Module-path}/{Class}Test.php`

Key assertions:
- Class can be instantiated.
- Required collaborators are non-null.
- Optional collaborators have their default values applied.

For deeper DI graph issues (preference collisions, circular deps), this is an integration
test, not a unit test — see "Integration Test" below.

## Class: Query / Persistence Bug

When the bug is in a `ResourceModel` query, collection filter, or repository `getList`,
test against real DB state.

Location: `Test/Integration/{Module-path}/{Class}Test.php`

Skeleton: `templates/regression-test-integration.php`.

Key assertions:
- The query returns the expected rows.
- The query uses a parameterized binding (assert no raw SQL injection vector).
- The query handles edge cases (empty result, large result set).

Use Magento test fixtures (`@magentoDataFixture`) for predictable DB state.

## Class: Controller Bug

When the bug is in a `Controller\Action` execute() method, test with mocked `Request` /
`Response` / dependency objects.

Location: `Test/Unit/Controller/{Area}/{Name}Test.php`

Skeleton: `templates/regression-test-controller.php`.

Key assertions:
- 200 vs 302 vs 404 vs 500 return for the relevant inputs.
- For POST controllers: form key validation enforced.
- For admin controllers: ACL check enforced.

## Class: API (REST/GraphQL) Bug

Test the request → response flow at the API layer.

Location: `Test/Api/{Route}Test.php` (REST) or `Test/Api/GraphQl/{Operation}Test.php`.

Skeleton: derive from existing API tests in the module.

Key assertions:
- Status code matches expected.
- Response body shape matches expected JSON schema.
- Auth errors return 401, not 200 with empty body.

## Class: Cron Bug

Test the cron job's `execute()` method directly.

Location: `Test/Unit/Cron/{Name}Test.php`.

Key assertions:
- The job processes the expected batch size.
- The job advances state correctly between runs.
- The job logs and continues on per-item failure rather than crashing the whole run.

## Class: Queue Consumer Bug

Test the consumer's `process()` (or equivalent) method with a synthetic message.

Location: `Test/Unit/Queue/{Consumer}Test.php`.

Key assertions:
- Message decoded correctly.
- Bad messages routed to dead-letter / logged appropriately.
- Idempotency: processing the same message twice doesn't double-apply.

## Class: GraphQL Resolver Bug

Test the resolver class directly with mocked `ContextInterface` and `Field`.

Location: `Test/Unit/Model/Resolver/{Name}Test.php`.

Skeleton: see `magento2-test-generate/templates/test-resolver.php`.

Key assertions:
- Resolver returns the expected shape.
- Auth check: anonymous request rejected when not allowed.
- Input error: invalid args throw `GraphQlInputException`.

## Class: Frontend (Block / ViewModel) Bug

Test the block/view-model in isolation.

Location: `Test/Unit/Block/{Name}Test.php` or `Test/Unit/ViewModel/{Name}Test.php`.

Key assertions:
- Block returns expected data.
- Escaping: any output is run through `$escaper->escapeHtml(...)`.
- Cache identities: `getIdentities()` returns the expected cache tags.

## Class: Config / XML Bug

When the bug is in `etc/*.xml` or `etc/config.xml`, the regression test is the validation
of the XML against the matching XSD, OR a unit test that loads the config and asserts the
resolved value matches the expected.

Location: `Test/Unit/Config/{Name}Test.php`.

Key assertions:
- XML is well-formed (`xmllint --noout`).
- Validates against the published XSD (`xmllint --schema`).
- Resolved config value matches expectation when loaded by Magento's Config\Reader.

## Class: Untestable

If the bug genuinely cannot be tested in a regression test (e.g. third-party gateway
outage, environment-specific timing race), document why in the RCA and ask the user to
confirm the waiver before applying the fix without a test.

Untestable bugs are rare — most "untestable" bugs are actually testable with a different
approach (mock the third party, inject a clock, etc.). Push back on declaring untestable
before accepting.
