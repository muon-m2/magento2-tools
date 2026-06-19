<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Model;

use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Model\Config;

/**
 * Unit test for the typed Config reader.
 *
 * Asserts that each getter delegates to ScopeConfigInterface with the exact
 * config path and scope, and that return values are cast to the declared type.
 * Target: {Vendor}/{Module}/Test/Unit/Model/ConfigTest.php
 */
class ConfigTest extends TestCase
{
    private const STORE_ID = 1;

    /**
     * @var ScopeConfigInterface&MockObject
     */
    private ScopeConfigInterface $scopeConfigMock;

    /**
     * @var Config
     */
    private Config $config;

    protected function setUp(): void
    {
        $this->scopeConfigMock = $this->createMock(ScopeConfigInterface::class);
        $this->config = new Config($this->scopeConfigMock);
    }

    /**
     * isEnabled() must call isSetFlag() with the correct path and store scope.
     */
    public function testIsEnabledReturnsTrueWhenFlagIsSet(): void
    {
        $this->scopeConfigMock
            ->expects(self::once())
            ->method('isSetFlag')
            ->with(
                '{vendor_lower}_{module_lower}/{GroupId}/enable',
                ScopeInterface::SCOPE_STORE,
                self::STORE_ID
            )
            ->willReturn(true);

        self::assertTrue($this->config->isEnabled(self::STORE_ID));
    }

    /**
     * isEnabled() must return false when the flag is not set.
     */
    public function testIsEnabledReturnsFalseWhenFlagIsNotSet(): void
    {
        $this->scopeConfigMock
            ->expects(self::once())
            ->method('isSetFlag')
            ->with(
                '{vendor_lower}_{module_lower}/{GroupId}/enable',
                ScopeInterface::SCOPE_STORE,
                null
            )
            ->willReturn(false);

        self::assertFalse($this->config->isEnabled());
    }

    /**
     * getFieldValue() must call getValue() with the correct path and cast to string.
     */
    public function testGetFieldValueReturnsStringFromScopeConfig(): void
    {
        $this->scopeConfigMock
            ->expects(self::once())
            ->method('getValue')
            ->with(
                '{vendor_lower}_{module_lower}/{GroupId}/{FieldId}',
                ScopeInterface::SCOPE_STORE,
                self::STORE_ID
            )
            ->willReturn('example-value');

        self::assertSame('example-value', $this->config->getFieldValue(self::STORE_ID));
    }

    /**
     * getFieldValue() must cast a null ScopeConfigInterface return to an empty string.
     */
    public function testGetFieldValueCastsNullToEmptyString(): void
    {
        $this->scopeConfigMock
            ->expects(self::once())
            ->method('getValue')
            ->with(
                '{vendor_lower}_{module_lower}/{GroupId}/{FieldId}',
                ScopeInterface::SCOPE_STORE,
                null
            )
            ->willReturn(null);

        self::assertSame('', $this->config->getFieldValue());
    }
}
