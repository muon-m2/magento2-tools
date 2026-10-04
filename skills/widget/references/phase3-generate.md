# Phase 3 — Test First, then Generate (Detail)

Part of the `widget` skill — read at Phase 3 (Test First, then Generate).

#### Phase 3 — Test First, then Generate

**3A — Write the failing tests (RED).** Write the tests that pin the parameter contract,
then scaffold only the block's *signature* so the tests have a type to bind to — the
interface-first seam from `context/references/tdd-discipline.md`:

1. Write `Test/Unit/Block/Widget/{WidgetName}Test.php` from
   `${CLAUDE_SKILL_DIR}/templates/test-widget-block-unit.php` and
   `Test/Integration/Widget/{WidgetName}DeclarationTest.php` from
   `${CLAUDE_SKILL_DIR}/templates/test-widget-declaration-integration.php`.
2. Write `Block/Widget/{WidgetName}.php` from
   `${CLAUDE_SKILL_DIR}/templates/widget-block.php` with the body of every accessor and of
   `getCacheKeyInfo()` replaced by `throw new \RuntimeException('not implemented');`. The
   class declaration, interface, constant and `$_template` stay as generated — that part is
   exempt scaffold.
3. Run the unit test:
   `{ctx.runner} vendor/bin/phpunit -c dev/tests/unit/phpunit.xml.dist app/code/{Vendor}/{Module}/Test/Unit/Block/Widget`
   — every behaviour test must fail on the `not implemented` exception (behaviour missing),
   not on an autoload path or PHPUnit setup error. Only the marker-interface test passes at
   this point, because the interface is part of the exempt scaffold.

The unit test must:

- Build the block with a mocked `Template\Context` whose `getStoreManager()`,
  `getResolver()`, `getAppState()`, and `getUrlBuilder()` return configured mocks — that
  is what `parent::getCacheKeyInfo()` touches. No Magento bootstrap required.
- Assert every accessor falls back to its default when the parameter is absent.
- Assert string coercion: `'12'` → `12`, `'0'` → `false`, `'1'` → `true`.
- Assert the invalid counts `'0'`, `'-3'`, `'abc'`, `''` each fall back to the default (one
  test, one assertion per value with a message naming the value).
- Assert `getCacheKeyInfo()`'s appended tail equals the parameter values exactly (order and
  types included — a bare `assertContains` can be satisfied by the parent's own entries), is
  identical for two blocks
  with identical parameters, and differs when **any** parameter differs (`title`,
  `items_count`, `show_title` each get a case).
- No `markTestIncomplete`, no `self::assertTrue(true)`.

The integration test covers the config XML the unit test cannot: the merged widget config
contains `{widget_id}`, its `type` is the block FQCN, the declared parameters are present,
and the block renders the title through the template in the `frontend` area. It carries a
`setUp()` guard that skips — with the exact reason — when the integration framework is not
loaded; keep the guard. On Magento < 2.4.5 replace `#[AppArea('frontend')]` with the
`@magentoAppArea frontend` annotation. Run it with
`{ctx.runner} vendor/bin/phpunit -c dev/tests/integration/phpunit.xml {ctx.magento_root}/app/code/{Vendor}/{Module}/Test/Integration`;
when `{ctx.magento_cli}` is null or `dev/tests/integration/etc/install-config-mysql.php` is
absent, the test cannot run — say so in the report (the tiered fallback in
`context/references/tdd-discipline.md`), never call it passed.

**3B — Generate implementation (GREEN).** Replace the throwing bodies in
`Block/Widget/{WidgetName}.php` with the real ones from the template and write the
remaining files:

- `${CLAUDE_SKILL_DIR}/templates/widget.xml`
- `${CLAUDE_SKILL_DIR}/templates/module.xml`
- `${CLAUDE_SKILL_DIR}/templates/widget-block.php`
- `${CLAUDE_SKILL_DIR}/templates/widget-template.phtml`

Keep the parameter artefacts in lockstep: every `<parameter name>` in `widget.xml` has one
typed accessor in the block, one assertion group in the unit test, and (when rendered) one
escaped output in the template — except `template`, which the framework consumes to pick
the `.phtml` and which no accessor reads. Adding a parameter means touching all three.

See `${CLAUDE_SKILL_DIR}/references/widget-anatomy.md`,
`${CLAUDE_SKILL_DIR}/references/parameter-types.md`, and
`${CLAUDE_SKILL_DIR}/references/pitfalls.md`.
