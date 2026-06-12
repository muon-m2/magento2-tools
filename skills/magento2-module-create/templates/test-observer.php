<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Observer;

use Magento\Framework\Event;
use Magento\Framework\Event\Observer;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;
use {Vendor}\{ModuleName}\Observer\{DescriptiveName}Observer;

/**
 * Unit tests for {DescriptiveName}Observer.
 */
class {DescriptiveName}ObserverTest extends TestCase
{
    private LoggerInterface&MockObject $logger;

    /**
     * @var {DescriptiveName}Observer
     */
    private {DescriptiveName}Observer $subject;

    /**
     * Sets up the logger mock and the observer under test.
     */
    protected function setUp(): void
    {
        $this->logger  = $this->createMock(LoggerInterface::class);
        $this->subject = new {DescriptiveName}Observer($this->logger);
    }

    /**
     * Asserts the observer handles the event without logging an error.
     */
    public function testExecuteHandlesEvent(): void
    {
        $event = $this->createMock(Event::class);
        $observer = $this->createMock(Observer::class);
        $observer->method('getEvent')->willReturn($event);

        // Happy path must not log an error. expects($this->never()) IS the assertion,
        // verified at teardown — so this is not an assertion-free test.
        $this->logger->expects($this->never())->method('error');

        $this->subject->execute($observer);
    }

    /**
     * Asserts the observer logs the exception once and does not re-throw.
     */
    public function testExecuteLogsExceptionAndContinues(): void
    {
        $observer = $this->createMock(Observer::class);
        $observer->method('getEvent')->willThrowException(new \RuntimeException('boom'));

        // The exception thrown while handling the event must be logged exactly once.
        // This expectation is the assertion; do NOT add expectNotToPerformAssertions().
        $this->logger->expects($this->once())->method('error');

        // Observer must NOT re-throw by default — if it did, this call would error the test.
        $this->subject->execute($observer);
    }
}
