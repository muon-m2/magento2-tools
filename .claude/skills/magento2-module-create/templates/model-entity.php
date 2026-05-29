<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model;

use Magento\Framework\Model\AbstractModel;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}Interface;
use {Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface;
use {Vendor}\{ModuleName}\Model\ResourceModel\{EntityName} as {EntityName}Resource;

/**
 * {EntityName} model.
 */
class {EntityName} extends AbstractModel implements {EntityName}Interface
{
    /**
     * @return void
     */
    protected function _construct(): void
    {
        $this->_init({EntityName}Resource::class);
    }

    /**
     * Get entity ID.
     *
     * @return int|null
     */
    public function getEntityId(): ?int
    {
        $value = $this->getData(self::ENTITY_ID);
        return $value !== null ? (int) $value : null;
    }

    /**
     * Set entity ID.
     *
     * @param int $entityId
     * @return $this
     */
    public function setEntityId(int $entityId): static
    {
        return $this->setData(self::ENTITY_ID, $entityId);
    }

    /**
     * Get name.
     *
     * @return string
     */
    public function getName(): string
    {
        return (string) $this->getData(self::NAME);
    }

    /**
     * Set name.
     *
     * @param string $name
     * @return $this
     */
    public function setName(string $name): static
    {
        return $this->setData(self::NAME, $name);
    }

    /**
     * Get created at timestamp.
     *
     * @return string|null
     */
    public function getCreatedAt(): ?string
    {
        return $this->getData(self::CREATED_AT);
    }

    /**
     * Get updated at timestamp.
     *
     * @return string|null
     */
    public function getUpdatedAt(): ?string
    {
        return $this->getData(self::UPDATED_AT);
    }

    /**
     * Get extension attributes.
     *
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null
     */
    public function getExtensionAttributes(): ?\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface
    {
        return $this->_getExtensionAttributes();
    }

    /**
     * Set extension attributes.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface $extensionAttributes
     * @return $this
     */
    public function setExtensionAttributes(
        \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface $extensionAttributes
    ): static {
        return $this->_setExtensionAttributes($extensionAttributes);
    }
}
