<?php
/**
 * Plugin for {TargetFqcn}::{Method}.
 * Target: {Vendor}/{Module}/Plugin/{PluginName}.php
 *
 * Choose ONE of the method stubs below and delete the others.
 * See skills/magento2-extension-point/references/plugin-types.md for semantics.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Plugin;

use {TargetFqcn};

class {PluginName}
{
    /**
     * Before plugin — modify incoming arguments.
     *
     * @param {TargetFqcn} $subject
     * @return array|null Return array of replacement args, or null to pass originals through.
     */
    public function before{Method}(
        {TargetFqcn} $subject
    ): ?array {
        // Modify arguments here. Return [$arg1, $arg2, ...] or null.
        return null;
    }

    /**
     * After plugin — modify the return value.
     *
     * @param {TargetFqcn} $subject
     * @param mixed $result
     * @return mixed
     */
    public function after{Method}(
        {TargetFqcn} $subject,
        mixed $result
    ): mixed {
        // Modify $result here and return it.
        return $result;
    }

    /**
     * Around plugin — wrap the call. Use only when before/after cannot express the logic.
     *
     * @param {TargetFqcn} $subject
     * @param callable $proceed
     * @return mixed
     */
    public function around{Method}(
        {TargetFqcn} $subject,
        callable $proceed
    ): mixed {
        // Optionally transform args, then call $proceed.
        $result = $proceed();
        // Optionally transform $result.
        return $result;
    }
}
