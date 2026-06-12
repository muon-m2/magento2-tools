<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Observer;

use Magento\Framework\Event\Observer;
use Magento\Framework\Event\ObserverInterface;
use Psr\Log\LoggerInterface;

/**
 * Observer for the {event_name} event.
 */
class {DescriptiveName}Observer implements ObserverInterface
{
    /**
     * @param \Psr\Log\LoggerInterface $logger
     */
    public function __construct(
        private readonly LoggerInterface $logger,
    ) {
    }

    /**
     * Handle the event.
     *
     * @param \Magento\Framework\Event\Observer $observer
     * @return void
     */
    public function execute(Observer $observer): void
    {
        try {
            /** @var \Magento\Framework\Event $event */
            $event = $observer->getEvent();
            // Observer logic using $event (e.g. $event->getData('...')). Observers never
            // modify the source event return value; use a plugin if you need to alter it.
        } catch (\Throwable $e) {
            $this->logger->error(
                '{vendor_lower}_{module_lower} observer {DescriptiveName}Observer failed: ' . $e->getMessage(),
                ['exception' => $e]
            );
            // Re-throw only when the event MUST roll back the source transaction.
            // Otherwise swallow to avoid breaking unrelated event consumers.
        }
    }
}
