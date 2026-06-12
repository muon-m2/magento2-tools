<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\{SubNamespace};

use {Vendor}\{Module}\{SubNamespace}\{ClassUnderTest};
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

/**
 * Regression test for bug: {Symptom one-liner}.
 *
 * Bug ID: {slug}
 * RCA: .docs/bug-fixes/{slug}/rca.md
 *
 * Pre-fix expectation: {what fails before the fix}.
 * Post-fix expectation: {what passes after the fix}.
 *
 * If a {ClassUnderTest}Test already exists, add testRegression{ShortDescription}() there
 * instead and delete this file; otherwise rename the class to {ClassUnderTest}Test.
 */
class {ClassUnderTest}RegressionTest extends TestCase
{
    /** @var {Dep1Type}&MockObject */
    private MockObject $dep1;

    /** @var {Dep2Type}&MockObject */
    private MockObject $dep2;

    /** @var {ClassUnderTest} */
    private {ClassUnderTest} $subject;

    /**
     * Builds the class under test with mocked dependencies.
     */
    protected function setUp(): void
    {
        $this->dep1 = $this->createMock(\{Dep1FQCN}::class);
        $this->dep2 = $this->createMock(\{Dep2FQCN}::class);

        $this->subject = new {ClassUnderTest}(
            $this->dep1,
            $this->dep2,
        );
    }

    /**
     * The bug: {one-line description}.
     *
     * Before the fix, this asserted {expected} but received {actual}.
     */
    public function testRegression{ShortDescription}(): void
    {
        // Arrange — set up the exact preconditions from the reproduction recipe.
        $this->dep1
            ->method('{method}')
            ->willReturn({reproducedReturn});

        // Act
        $result = $this->subject->{methodUnderTest}({reproducedArgs});

        // Assert — post-fix expectation.
        self::assertSame({expected}, $result, 'Bug {slug}: {short reminder}');
    }
}
