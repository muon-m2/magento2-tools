define([
    'jquery',
    'mage/translate',
], function ($, $t) {
    'use strict';

    return function (config, element) {
        var instance = {
            config: config,
            element: element,

            init: function () {
                // Initial setup
            }
        };

        instance.init();
        return instance;
    };
});
