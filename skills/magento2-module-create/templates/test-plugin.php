<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Plugin;

use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {TargetNamespace};
use {Vendor}\{ModuleName}\Plugin\{TargetShortName}{Method}Plugin;

/**
 * Unit tests for {TargetShortName}{Method}Plugin.
 */
class {TargetShortName}{Method}PluginTest extends TestCase
{
    private {TargetShortName}&MockObject $subjectMock;

    /**
     * @var {TargetShortName}{Method}Plugin
     */
    private {TargetShortName}{Method}Plugin $plugin;

    /**
     * Sets up the plugin subject mock and the plugin under test.
     */
    protected function setUp(): void
    {
        $this->subjectMock = $this->createMock({TargetShortName}::class);
        $this->plugin      = new {TargetShortName}{Method}Plugin();
    }

    /**
     * Asserts the before plugin returns the arguments unchanged.
     */
    public function testBefore{Method}ReturnsArguments(): void
    {
        $args = ['arg1', 'arg2'];
        $result = $this->plugin->before{Method}($this->subjectMock, ...$args);
        $this->assertSame($args, $result);
    }

    /**
     * Asserts the after plugin returns the result unchanged.
     */
    public function testAfter{Method}ReturnsResultUnchanged(): void
    {
        $input = 'value';
        $result = $this->plugin->after{Method}($this->subjectMock, $input);
        $this->assertSame($input, $result);
    }
}
