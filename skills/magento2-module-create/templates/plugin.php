<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Plugin;

use {TargetNamespace};

/**
 * Plugin for \{TargetNamespace}::{method}.
 *
 * Plugin type: before / around / after — pick the minimal type that satisfies the goal.
 *   before  — validate / transform arguments
 *   after   — transform return value
 *   around  — wrap the entire call; use only when before+after cannot express the intent
 */
class {TargetShortName}{Method}Plugin
{
    /**
     * Example: before plugin that validates / transforms arguments.
     *
     * @param \{TargetNamespace} $subject
     * @param mixed $args
     * @return array
     */
    public function before{Method}(
        {TargetShortName} $subject,
        ...$args
    ): array {
        // Adjust or validate $args. Return must be an array matching the target signature.
        return $args;
    }

    /**
     * Example: after plugin that transforms the return value.
     *
     * @param \{TargetNamespace} $subject
     * @param mixed $result
     * @return mixed
     */
    public function after{Method}(
        {TargetShortName} $subject,
        $result
    ) {
        // Adjust $result and return it.
        return $result;
    }
}
