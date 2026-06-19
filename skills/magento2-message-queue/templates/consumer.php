<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Consumer;

use Psr\Log\LoggerInterface;
use {Vendor}\{Module}\Api\Data\{EntityName}Interface;
use {Vendor}\{Module}\Service\{EntityName}Handler;

/**
 * Consumer for the {TopicName} topic.
 *
 * Declared in etc/queue_consumer.xml as {ConsumerName}; its handler is
 * {ConsumerName}::process. Decodes the typed {EntityName}Interface message and delegates
 * the domain work to {EntityName}Handler — the consumer itself contains no business logic.
 *
 * Idempotency: message delivery is at-least-once, so process() MUST be safe to call twice
 * with the same message. {EntityName}Handler::isProcessed() is the guard — a redelivered
 * message that is already processed is a no-op. Un-retryable failures are logged and
 * dropped (not re-thrown) so a poison message cannot block the queue.
 * Target: {Vendor}/{Module}/Model/Consumer/{ConsumerName}.php
 */
class {ConsumerName}
{
    /**
     * @param \{Vendor}\{Module}\Service\{EntityName}Handler $handler
     * @param \Psr\Log\LoggerInterface $logger
     */
    public function __construct(
        private readonly {EntityName}Handler $handler,
        private readonly LoggerInterface $logger
    ) {
    }

    /**
     * Process a single {EntityName} message.
     *
     * @param \{Vendor}\{Module}\Api\Data\{EntityName}Interface $message
     * @return void
     */
    public function process({EntityName}Interface $message): void
    {
        // Idempotency guard: a redelivered, already-processed message is a safe no-op.
        if ($this->handler->isProcessed($message)) {
            return;
        }

        try {
            $this->handler->process($message);
        } catch (\InvalidArgumentException $e) {
            // Un-retryable (bad data): log and drop so the poison message cannot block the
            // queue. Do NOT re-throw — re-throwing would re-queue it forever.
            $this->logger->error(
                'Dropping un-processable {TopicName} message: ' . $e->getMessage(),
                ['entity_id' => $message->getEntityId()]
            );
        }
    }
}
