<?php
/**
 * Observer for the dispatched event registered in events.xml.
 * Target: {Vendor}/{Module}/Observer/{ObserverName}.php
 *
 * Access event data:
 *   $observer->getEvent()->getData('key')   // explicit event object
 *   $observer->getData('key')               // shortcut — delegates to getEvent()
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Observer;

use Magento\Framework\Event\Observer;
use Magento\Framework\Event\ObserverInterface;

class {ObserverName} implements ObserverInterface
{
    /**
     * Execute the observer logic.
     *
     * @param Observer $observer
     * @return void
     */
    public function execute(Observer $observer): void
    {
        $event = $observer->getEvent();

        // Retrieve dispatched data — replace 'key' with the actual parameter name.
        $data = $event->getData('key');

        // Implement observer logic here.
        // Avoid DB writes on events that fire per-collection-item (performance risk).
    }
}
