<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model;

use Magento\Framework\MessageQueue\PublisherInterface;
use {Vendor}\{Module}\Api\Data\{EntityName}InterfaceFactory;

/**
 * Publishes {EntityName} messages onto the {TopicName} topic.
 *
 * Builds the typed DTO via its generated factory and hands it to the framework
 * PublisherInterface. The topic literal lives in exactly one place — the TOPIC constant —
 * which must be byte-identical to the topic in communication.xml, queue_topology.xml, and
 * queue_publisher.xml.
 * Target: {Vendor}/{Module}/Model/{PublisherName}.php
 */
class {PublisherName}
{
    /**
     * Queue topic name. Must match etc/communication.xml, etc/queue_topology.xml,
     * and etc/queue_publisher.xml.
     */
    public const TOPIC = '{TopicName}';

    /**
     * @param \Magento\Framework\MessageQueue\PublisherInterface $publisher
     * @param \{Vendor}\{Module}\Api\Data\{EntityName}InterfaceFactory $messageFactory
     */
    public function __construct(
        private readonly PublisherInterface $publisher,
        private readonly {EntityName}InterfaceFactory $messageFactory
    ) {
    }

    /**
     * Build a typed {EntityName} message and publish it onto the {TopicName} topic.
     *
     * @param int $entityId The entity the downstream consumer should process.
     * @param string $status The requested status / action.
     * @return void
     */
    public function publish(int $entityId, string $status): void
    {
        $message = $this->messageFactory->create();
        $message->setEntityId($entityId);
        $message->setStatus($status);

        $this->publisher->publish(self::TOPIC, $message);
    }
}
