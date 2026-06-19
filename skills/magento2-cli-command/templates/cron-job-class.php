<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Cron;

use {Vendor}\{Module}\Service\{ServiceName};

/**
 * Cron job class for {cron_job_name}.
 *
 * Declared in etc/crontab.xml; delegates all business logic to {ServiceName}.
 * Must be idempotent: running execute() more than once must be safe.
 * Target: {Vendor}/{Module}/Cron/{CronJobName}.php
 */
class {CronJobName}
{
    /**
     * @param \{Vendor}\{Module}\Service\{ServiceName} $service
     */
    public function __construct(
        private readonly {ServiceName} $service
    ) {
    }

    /**
     * Cron entry point — called by Magento\Cron\Observer\ProcessCronQueueObserver.
     *
     * Delegates to {ServiceName}; the job is safe to run more than once
     * because {ServiceName} is responsible for idempotency.
     */
    public function execute(): void
    {
        $this->service->execute();
    }
}
