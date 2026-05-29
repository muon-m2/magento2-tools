<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Model\Consumer;

use Psr\Log\LoggerInterface;
use {Vendor}\{ModuleName}\Api\Data\{MessageName}Interface;

/**
 * Queue consumer: processes one {MessageName} message at a time.
 *
 * Idempotency: each message processing path checks state before mutating. Re-delivery
 * of a message after partial failure is safe.
 */
class {ConsumerName}
{
    /**
     * @param \Psr\Log\LoggerInterface $logger
     */
    public function __construct(
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Process one message.
     *
     * @param \{Vendor}\{ModuleName}\Api\Data\{MessageName}Interface $message
     * @return void
     */
    public function process({MessageName}Interface $message): void
    {
        try {
            // Consumer logic. Keep idempotent.
        } catch (\Throwable $e) {
            $this->logger->error(
                '{vendor_lower}.{module_lower}.{consumer_description} consumer failed: ' . $e->getMessage(),
                ['exception' => $e]
            );
            throw $e;
        }
    }
}
