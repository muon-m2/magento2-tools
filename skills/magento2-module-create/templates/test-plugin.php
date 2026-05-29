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
    private {TargetShortName}{Method}Plugin $plugin;

    protected function setUp(): void
    {
        $this->subjectMock = $this->createMock({TargetShortName}::class);
        $this->plugin      = new {TargetShortName}{Method}Plugin();
    }

    public function testBefore{Method}ReturnsArguments(): void
    {
        $args = ['arg1', 'arg2'];
        $result = $this->plugin->before{Method}($this->subjectMock, ...$args);
        $this->assertSame($args, $result);
    }

    public function testAfter{Method}ReturnsResultUnchanged(): void
    {
        $input = 'value';
        $result = $this->plugin->after{Method}($this->subjectMock, $input);
        $this->assertSame($input, $result);
    }
}
