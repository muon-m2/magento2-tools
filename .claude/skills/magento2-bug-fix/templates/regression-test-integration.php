<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Integration\{SubNamespace};

use Magento\TestFramework\Helper\Bootstrap;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\{SubNamespace}\{ClassUnderTest};

/**
 * Integration regression test for bug: {Symptom one-liner}.
 *
 * Bug ID: {slug}
 * RCA: .docs/bug-fixes/{slug}/rca.md
 *
 * Requires a Magento integration-test bootstrap. Loads the relevant fixture before
 * exercising the production class.
 *
 * If a {ClassUnderTest}Test already exists, add testRegression{ShortDescription}() there
 * instead and delete this file; otherwise rename the class to {ClassUnderTest}Test.
 *
 * @magentoAppArea {frontend|adminhtml|webapi_rest}
 * @magentoDataFixture {Vendor}_{Module}::Test/Integration/_files/{fixture}.php
 */
final class {ClassUnderTest}RegressionTest extends TestCase
{
    private {ClassUnderTest} $subject;

    protected function setUp(): void
    {
        $this->subject = Bootstrap::getObjectManager()->create({ClassUnderTest}::class);
    }

    /**
     * The bug: {one-line description}.
     *
     * Before the fix, the query returned {actual}. After, it returns {expected}.
     */
    public function testRegression{ShortDescription}(): void
    {
        // Arrange — fixture loaded via @magentoDataFixture; no further setup.

        // Act
        $result = $this->subject->{methodUnderTest}({reproducedArgs});

        // Assert
        self::assertSame({expected}, $result, 'Bug {slug}: {short reminder}');
    }
}
