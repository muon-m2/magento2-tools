<?php
/**
 * Preference replacement for {PreferenceFor}.
 * Target: {Vendor}/{Module}/Model/{EntityName}.php
 *
 * This class is bound to {PreferenceFor} via etc/{area}/di.xml.
 * Extend or implement the target so existing consumers are not broken.
 *
 * CAUTION: if another module declares a preference for the same interface,
 * only one will win. Use a plugin on the concrete class when possible.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Model;

use {PreferenceFor};

class {EntityName} implements {PreferenceForShort}
{
    /**
     * Override or extend methods here.
     * Delegate to the original implementation when not overriding.
     * If extending a concrete class, change `implements` to `extends` and adjust the import.
     */
}
