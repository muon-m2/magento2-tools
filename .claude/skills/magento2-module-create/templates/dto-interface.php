<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Api\Data;

use Magento\Framework\Api\ExtensibleDataInterface;

/**
 * {EntityName} data interface.
 *
 * @api
 */
interface {EntityName}Interface extends ExtensibleDataInterface
{
    // Field name constants — use these in getters/setters and resource model.
    public const ENTITY_ID  = 'entity_id';
    public const NAME       = 'name';
    public const CREATED_AT = 'created_at';
    public const UPDATED_AT = 'updated_at';

    /**
     * Get entity ID.
     *
     * @return int|null
     */
    public function getEntityId(): ?int;

    /**
     * Set entity ID.
     *
     * @param int $entityId
     * @return static
     */
    public function setEntityId(int $entityId): static;

    /**
     * Get name.
     *
     * @return string
     */
    public function getName(): string;

    /**
     * Set name.
     *
     * @param string $name
     * @return static
     */
    public function setName(string $name): static;

    /**
     * Get created at timestamp.
     *
     * @return string|null
     */
    public function getCreatedAt(): ?string;

    /**
     * Get updated at timestamp.
     *
     * @return string|null
     */
    public function getUpdatedAt(): ?string;

    /**
     * Get extension attributes.
     *
     * IMPORTANT: Return type MUST be the entity-specific generated interface,
     * NOT the generic \Magento\Framework\Api\ExtensionAttributesInterface.
     * Using the generic base causes setup:di:compile to fail.
     *
     * @return \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface|null
     */
    public function getExtensionAttributes(): ?\{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface;

    /**
     * Set extension attributes.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface $extensionAttributes
     * @return static
     */
    public function setExtensionAttributes(
        \{Vendor}\{ModuleName}\Api\Data\{EntityName}ExtensionInterface $extensionAttributes
    ): static;
}
