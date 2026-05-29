<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Service;

use {Vendor}\{Module}\Service\{Service};
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

final class {Service}Test extends TestCase
{
    /** @var {Dep1FQCN}&MockObject */
    private MockObject $dep1;

    private {Service} $subject;

    protected function setUp(): void
    {
        $this->dep1 = $this->createMock(\{Dep1FQCN}::class);
        $this->subject = new {Service}($this->dep1);
    }

    public function test{Method}HappyPath(): void
    {
        $this->dep1->method('{depMethod}')->willReturn({depReturn});

        $result = $this->subject->{method}({args});

        self::assertSame({expected}, $result);
    }

    public function test{Method}ThrowsOnInvalidInput(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->subject->{method}({invalidArgs});
    }
}
