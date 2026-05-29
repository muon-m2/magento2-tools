# JavaScript (Jasmine) Test Patterns

Magento 2 ships a Jasmine harness for testing RequireJS modules and Knockout components.

## File Layout

```
view/frontend/web/js/
├── component.js
└── test/
    └── component.test.js
```

## RequireJS Module Test

```js
define([
    '{Vendor}_{Module}/js/component',
], function (Component) {
    'use strict';

    describe('{Vendor}_{Module}/js/component', function () {
        it('loads without error', function () {
            expect(Component).toBeDefined();
        });

        it('initial state has empty items', function () {
            var instance = new Component();
            expect(instance.items.length).toBe(0);
        });

        it('addItem appends to items', function () {
            var instance = new Component();
            instance.addItem({id: 1});
            expect(instance.items.length).toBe(1);
            expect(instance.items[0].id).toBe(1);
        });
    });
});
```

## Knockout Component Test

```js
define([
    'ko',
    '{Vendor}_{Module}/js/view/component',
], function (ko, Component) {
    'use strict';

    describe('{Vendor}_{Module} KO component', function () {
        var component;

        beforeEach(function () {
            component = new Component({});
        });

        it('initializes observables', function () {
            expect(ko.isObservable(component.label)).toBe(true);
            expect(component.label()).toBe('');
        });

        it('setLabel updates observable', function () {
            component.setLabel('hello');
            expect(component.label()).toBe('hello');
        });
    });
});
```

## Running

Magento's `dev/tests/js` harness runs all `*.test.js` files under `view/frontend/web/js/test/`.

```bash
{ctx.runner} grunt test:js
```

Or per file:

```bash
{ctx.runner} grunt test:js --file=path/to/component.test.js
```

## Lint

```bash
node --check src/app/code/{Vendor}/{Module}/view/frontend/web/js/test/component.test.js
```

`node --check` validates syntax but does not run the test. The full test runner uses
Karma + Jasmine.

## Anti-Patterns

- **Calling production endpoints from tests.** Mock the AJAX layer; do not hit real
  REST/GraphQL in JS unit tests — they belong in API tests.
- **DOM-coupled tests without a fixture.** Tests requiring rendered HTML must set up
  the DOM in `beforeEach` and tear down in `afterEach`.
- **Hardcoded sleeps.** Use Jasmine's `done()` callback or `async/await` to wait for
  async events.
