define([
    'ko',
    '{Vendor}_{Module}/js/view/{component}',
], function (ko, Component) {
    'use strict';

    describe('{Vendor}_{Module}/js/view/{component}', function () {
        var component;

        beforeEach(function () {
            component = new Component({});
        });

        it('loads without error', function () {
            expect(component).toBeDefined();
        });

        it('initializes observables', function () {
            expect(ko.isObservable(component.label)).toBe(true);
        });

        it('setLabel updates observable', function () {
            component.setLabel('hello');
            expect(component.label()).toBe('hello');
        });
    });
});
