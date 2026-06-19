<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model;

use Magento\Framework\App\Config\ScopeConfigInterface;
use Magento\Store\Model\ScopeInterface;

/**
 * Typed configuration reader for {Vendor}_{Module}.
 *
 * Single entry point for all ScopeConfigInterface reads in this module.
 * Business code injects this class instead of ScopeConfigInterface directly.
 *
 * Config path: {vendor_lower}_{module_lower}/{GroupId}/{FieldId}
 * Target: {Vendor}/{Module}/Model/Config.php
 */
class Config
{
    /**
     * Config path for the {FieldId} setting.
     *
     * Full path: {vendor_lower}_{module_lower}/{GroupId}/{FieldId}
     */
    private const XML_PATH_FIELD = '{vendor_lower}_{module_lower}/{GroupId}/{FieldId}';

    /**
     * Config path for an example boolean/toggle setting.
     *
     * Full path: {vendor_lower}_{module_lower}/{GroupId}/enable
     */
    private const XML_PATH_ENABLE = '{vendor_lower}_{module_lower}/{GroupId}/enable';

    public function __construct(
        private readonly ScopeConfigInterface $scopeConfig
    ) {
    }

    /**
     * Return whether the module feature is enabled for the given store.
     *
     * Uses isSetFlag() which interprets "1"/"yes" as true and "0"/"no"/"" as false.
     *
     * @param int|string|null $storeId Store view id or code; null falls back to default scope.
     */
    public function isEnabled($storeId = null): bool
    {
        return $this->scopeConfig->isSetFlag(
            self::XML_PATH_ENABLE,
            ScopeInterface::SCOPE_STORE,
            $storeId
        );
    }

    /**
     * Return the {FieldId} configuration value for the given store.
     *
     * @param int|string|null $storeId Store view id or code; null falls back to default scope.
     */
    public function getFieldValue($storeId = null): string
    {
        return (string) $this->scopeConfig->getValue(
            self::XML_PATH_FIELD,
            ScopeInterface::SCOPE_STORE,
            $storeId
        );
    }
}
