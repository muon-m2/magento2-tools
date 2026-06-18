<?php
/**
 * Unit test for the {ObserverName} observer.
 * Target: {Vendor}/{Module}/Test/Unit/Observer/{ObserverName}Test.php
 *
 * Mocks \Magento\Framework\Event\Observer and \Magento\Framework\Event so that
 * no Magento bootstrap is required. Asserts that execute() reacts correctly to
 * the event payload.
 */
declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Observer;

use Magento\Framework\Event;
use Magento\Framework\Event\Observer;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Observer\{ObserverName};

class {ObserverName}Test extends TestCase
{
    /**
     * @var {ObserverName}
     */
    private {ObserverName} $observer;

    /**
     * @var MockObject&Observer
     */
    private MockObject $observerMock;

    /**
     * @var MockObject&Event
     */
    private MockObject $eventMock;

    /**
     * Set up the observer and mock event infrastructure for each test.
     */
    protected function setUp(): void
    {
        $this->observer = new {ObserverName}();

        $this->eventMock = $this->createMock(Event::class);

        $this->observerMock = $this->createMock(Observer::class);
        $this->observerMock->method('getEvent')->willReturn($this->eventMock);
    }

    /**
     * Test that execute() reads the dispatched event payload.
     *
     * The mock expectation below is a real assertion (PHPUnit verifies it at
     * tear-down): the observer must read the event data. Adjust 'key' to your
     * event's parameter, then add an assertion on the side effect your execute()
     * produces (e.g. a mocked service call) to drive RED → GREEN.
     */
    public function testExecuteReadsEventPayload(): void
    {
        // The observer must read this payload key exactly once.
        $this->eventMock->expects(self::once())
            ->method('getData')
            ->with('key')
            ->willReturn('expected-value');

        $this->observer->execute($this->observerMock);
    }
}
