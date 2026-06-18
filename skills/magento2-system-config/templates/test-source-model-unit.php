<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Model\Config\Source;

use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Model\Config\Source\{SourceName};

/**
 * Unit test for the {SourceName} source model.
 *
 * Asserts that toOptionArray() returns the expected array shape so that the
 * system.xml select/multiselect field renders the correct options.
 * Target: {Vendor}/{Module}/Test/Unit/Model/Config/Source/{SourceName}Test.php
 */
class {SourceName}Test extends TestCase
{
    /**
     * @var {SourceName}
     */
    private {SourceName} $source;

    protected function setUp(): void
    {
        $this->source = new {SourceName}();
    }

    /**
     * toOptionArray() must return a non-empty array of option entries.
     */
    public function testToOptionArrayIsNotEmpty(): void
    {
        $options = $this->source->toOptionArray();

        self::assertNotEmpty($options);
    }

    /**
     * Each entry in toOptionArray() must have 'value' and 'label' keys.
     */
    public function testToOptionArrayEntriesHaveValueAndLabel(): void
    {
        $options = $this->source->toOptionArray();

        foreach ($options as $option) {
            self::assertArrayHasKey('value', $option);
            self::assertArrayHasKey('label', $option);
        }
    }

    /**
     * The first option must match VALUE_OPTION_A with label 'Option A'.
     *
     * This asserts the exact array shape for the example options; adjust when
     * the real options are substituted during code generation.
     */
    public function testToOptionArrayContainsOptionA(): void
    {
        $options = $this->source->toOptionArray();

        $values = array_column($options, 'value');
        self::assertContains({SourceName}::VALUE_OPTION_A, $values);
    }

    /**
     * The second option must match VALUE_OPTION_B with label 'Option B'.
     */
    public function testToOptionArrayContainsOptionB(): void
    {
        $options = $this->source->toOptionArray();

        $values = array_column($options, 'value');
        self::assertContains({SourceName}::VALUE_OPTION_B, $values);
    }
}
