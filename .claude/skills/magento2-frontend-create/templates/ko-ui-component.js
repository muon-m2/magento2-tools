define([
    'uiComponent',
    'ko',
    'mage/translate',
], function (Component, ko, $t) {
    'use strict';

    return Component.extend({
        defaults: {
            template: '{Vendor}_{Module}/view/{component-name-kebab}',
            label: ''
        },

        initObservable: function () {
            this._super().observe(['label']);
            return this;
        },

        setLabel: function (text) {
            this.label(text);
        }
    });
});
