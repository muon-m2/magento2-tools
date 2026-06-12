<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Service;

use {Vendor}\{Module}\Service\{Service};
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

class {Service}Test extends TestCase
{
    /** @var {Dep1FQCN}&MockObject */
    private MockObject $dep1;

    /** @var {Service} */
    private {Service} $subject;

    /**
     * Builds the service under test with mocked dependencies.
     */
    protected function setUp(): void
    {
        $this->dep1 = $this->createMock(\{Dep1FQCN}::class);
        $this->subject = new {Service}($this->dep1);
    }

    /**
     * Asserts the service returns the expected result on valid input.
     */
    public function test{Method}HappyPath(): void
    {
        $this->dep1->method('{depMethod}')->willReturn({depReturn});

        $result = $this->subject->{method}({args});

        self::assertSame({expected}, $result);
    }

    /**
     * Asserts the service throws on invalid input.
     */
    public function test{Method}ThrowsOnInvalidInput(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->subject->{method}({invalidArgs});
    }
}
