<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Api\Data;

/**
 * {EntityName} message DTO — the typed payload published to the queue topic.
 *
 * Declared as the topic `request` in etc/communication.xml. The framework reflects over
 * the getters to (de)serialize the payload, so every round-tripped field needs a typed
 * getter. Field-name constants double as the serialized keys. Keep fields scalar — pass
 * an id and re-load the entity inside the handler rather than nesting full objects.
 * Target: {Vendor}/{Module}/Api/Data/{EntityName}Interface.php
 *
 * @api
 */
interface {EntityName}Interface
{
    // Field-name constants — also the serialized JSON keys.
    public const ENTITY_ID = 'entity_id';
    public const STATUS    = 'status';

    /**
     * Get the entity ID this message refers to.
     *
     * @return int|null
     */
    public function getEntityId(): ?int;

    /**
     * Set the entity ID this message refers to.
     *
     * @param int $entityId
     * @return void
     */
    public function setEntityId(int $entityId): void;

    /**
     * Get the requested status / action carried by the message.
     *
     * @return string
     */
    public function getStatus(): string;

    /**
     * Set the requested status / action carried by the message.
     *
     * @param string $status
     * @return void
     */
    public function setStatus(string $status): void;
}
