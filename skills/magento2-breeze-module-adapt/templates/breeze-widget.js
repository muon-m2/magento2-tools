/**
 * Breeze widget for {Vendor}_{ModuleName}.
 *
 * Converted from the module's RequireJS/Knockout/jQuery behaviour so it runs on Breeze (Cash).
 * Registered on the breeze.js block via view/frontend/layout/breeze_default.xml. Breeze invokes
 * it for nodes carrying the matching data-mage-init / text/x-magento-init instruction.
 */
(function () {
    'use strict';

    $.widget('{moduleName}Widget', {
        component: '{Vendor}_{ModuleName}/js/breeze/widget',

        /**
         * Breeze lifecycle hook. `this.element` is a Cash collection for the bound node and
         * `this.options` holds the JSON config passed via data-mage-init / x-magento-init.
         */
        create: function () {
            var self = this;

            // TODO: port the original widget body here.
            // Reference original source: {Vendor}_{ModuleName}/view/frontend/web/js/<original>.js
            self.element.on('click', function () {
                // ... ported behaviour ...
            });
        }
    });
}());
