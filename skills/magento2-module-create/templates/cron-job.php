<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Cron;

use Psr\Log\LoggerInterface;

/**
 * Cron job: {description}.
 *
 * Idempotency: this job is safe to retry. Interrupted runs do not produce duplicate
 * work — each record is only processed when its state allows it.
 */
class {JobName}
{
    /**
     * @param \Psr\Log\LoggerInterface $logger
     */
    public function __construct(
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Run the job.
     *
     * @return void
     */
    public function execute(): void
    {
        try {
            // Job logic. Keep idempotent — check state before doing work.
        } catch (\Throwable $e) {
            $this->logger->error(
                '{vendor_lower}_{module_lower}_{description} cron failed: ' . $e->getMessage(),
                ['exception' => $e]
            );
            throw $e;
        }
    }
}
