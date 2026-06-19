<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model;

use {Vendor}\{Module}\Api\Data\{EntityName}Interface;

/**
 * {EntityName} message DTO implementation.
 *
 * Bound to {EntityName}Interface by a di.xml <preference> so the message-queue framework
 * instantiates this concrete model for the topic's typed `request`.
 * Target: {Vendor}/{Module}/Model/{EntityName}.php
 */
class {EntityName} implements {EntityName}Interface
{
    /**
     * @var int|null
     */
    private ?int $entityId = null;

    /**
     * @var string
     */
    private string $status = '';

    /**
     * @inheritDoc
     */
    public function getEntityId(): ?int
    {
        return $this->entityId;
    }

    /**
     * @inheritDoc
     */
    public function setEntityId(int $entityId): void
    {
        $this->entityId = $entityId;
    }

    /**
     * @inheritDoc
     */
    public function getStatus(): string
    {
        return $this->status;
    }

    /**
     * @inheritDoc
     */
    public function setStatus(string $status): void
    {
        $this->status = $status;
    }
}
