<?php
/**
 * OPTIONAL form data Modifier for {Vendor}\{Module} entity {Entity}.
 * Target: {Vendor}/{Module}/Ui/{Entity}/Form/Modifier/{Entity}Modifier.php
 *
 * Only generate the modifier surface when fields must be built/altered dynamically or when
 * extending an existing core form (product/customer). When used, the DataProvider must extend
 * Magento\Ui\DataProvider\ModifierPoolDataProvider and the pool is wired via di-modifier-pool.xml.
 * See references/modifier-patterns.md.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Ui\{Entity}\Form\Modifier;

use Magento\Ui\DataProvider\Modifier\ModifierInterface;

class {Entity}Modifier implements ModifierInterface
{
    /**
     * Modify the form's data values (keyed by entity id).
     *
     * @param array $data
     * @return array
     */
    public function modifyData(array $data): array
    {
        return $data;
    }

    /**
     * Modify the form's metadata (fields, fieldsets, labels, visibility).
     *
     * @param array $meta
     * @return array
     */
    public function modifyMeta(array $meta): array
    {
        return $meta;
    }
}
