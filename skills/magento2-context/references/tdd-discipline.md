# Test-First Discipline (shared)

The canonical red → green → refactor loop for every `magento2-*` builder skill that emits
**behaviour**. This is the single source of truth; skills point here instead of restating it.
`magento2-bug-fix` already applies this loop to defect remediation — the same discipline, now
shared so feature and data-shaped work can reuse it.

## The loop

```
RED    → write ONE failing test for the behaviour you are about to add. Run it.
         Watch it fail for the RIGHT reason (assertion/feature missing — not a typo,
         missing class, or setup error). If it passes already, it tests existing behaviour
         or the wrong thing: fix the test before writing any production code.
GREEN  → write the MINIMAL production code that makes the test pass. No extra features.
REFACTOR → tidy only what you touched; keep the test green.
```

**The iron rule:** no behaviour-bearing production code without a failing test first. Tests
written *after* the code pass immediately and prove nothing — they cannot tell you the test
can actually fail, and they are biased by the implementation you already wrote (they answer
"what does this do?" instead of "what should this do?"). Watching the test fail is the whole
point.

## Where this applies — the behaviour / boilerplate line

Strict red-green on scaffolding is theatre. Apply the loop to **behaviour**; exempt the
**scaffold/config** (then cover it cheaply). This carve-out matches the canonical
`superpowers:test-driven-development` exceptions for *generated code* and *configuration files*.

| Test-first (RED before code) | Exempt — scaffold, then cover |
|------------------------------|-------------------------------|
| `Service/` and `Model/` methods that carry logic | `registration.php`, `etc/module.xml`, `composer.json` |
| `Plugin/`, `Observer/`, `Console/Command/` logic | `etc/di.xml` and other DI/config XML |
| GraphQL `Resolver/` (auth, scope, shape, batching) | Pure DTO interfaces + their getters/setters |
| Data-patch **transform / idempotency** logic | `db_schema.xml` (cover via integration, not unit) |
| EAV source/backend **model** behaviour | Plain CRUD repository wiring (one integration round-trip) |
| KO component public methods / view-model logic | `.phtml`, LESS, layout XML (cover via MFTF/smoke) |

When in doubt: if a reviewer could break it without any test going red, it is behaviour — write
the test first.

## The interface-first seam (for bulk-scaffolded code)

A failing test needs a type to bind to. When a generator emits a whole module at once, don't
emit a finished behavioural class. Instead:

1. Scaffold the **signature** — interface + a method body that `throw`s
   `new \RuntimeException('not implemented')`. (This is exempt scaffold.)
2. Write the test against that signature. Run it — it fails on the throw (RED, right reason).
3. Replace the throw with the **minimal real body** (GREEN).

This keeps test-first compatible with bulk generation instead of fighting it.

## Acceptance-criteria-as-tests

A task's acceptance criteria *are* the RED test list. Turn each criterion into a failing test
written before the implementing code. This reuses planning you already did — no new burden.

## Magento specifics

- **Unit** (`Test/Unit/`, `dev/tests/unit/phpunit.xml.dist`): mock constructor dependencies with
  `createMock()` + `MockObject&Interface` typing. Prefer real collaborators over mocks where
  cheap. Hard-to-test = too-coupled — inject dependencies, don't reach for `ObjectManager`.
- **Integration** (`Test/Integration/`): use attribute fixtures on Magento 2.4.5+
  (`#[DataFixture]`, `#[DbIsolation]`, `#[AppArea]`); legacy `@magento` annotations below that.
  Reach for integration (over unit) when the behaviour *is* the DB/EAV/DI round-trip —
  idempotency of a data patch, attribute scope after a patch runs, repository persistence.
- **No empty tests.** Every test has at least one real assertion. `markTestIncomplete()` and
  assertion-free stubs are forbidden — they are not a RED test.

## Tiered fallback when no Magento install is available

Integration test-first needs a running DB/Magento. When `{ctx.magento_cli}` is null or no test
DB exists, degrade honestly rather than skipping the discipline:

1. Prefer a **unit** test of the same logic (e.g. the importer's lookup-then-insert idempotency
   guard, the source model's `toOptionArray()`), written test-first.
2. If even that is impossible, write the integration test, mark it skipped with the exact reason,
   and record the gap in the skill's report. Never report untested behaviour as "done" silently.

## Checklist (before marking a behaviour task complete)

- [ ] A test for the behaviour existed and was watched to **fail** before the code.
- [ ] It failed for the right reason (assertion/feature missing, not setup error).
- [ ] Minimal code written to pass; no speculative extras.
- [ ] All tests green; output pristine.
- [ ] Real assertions; mocks only where unavoidable.

If you cannot check these, it was test-after — say so in the report; do not call it TDD.
