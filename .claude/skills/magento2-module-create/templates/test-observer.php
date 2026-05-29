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
    private {DescriptiveName}Observer $subject;

    protected function setUp(): void
    {
        $this->logger  = $this->createMock(LoggerInterface::class);
        $this->subject = new {DescriptiveName}Observer($this->logger);
    }

    public function testExecuteHandlesEvent(): void
    {
        $event = $this->createMock(Event::class);
        $observer = $this->createMock(Observer::class);
        $observer->method('getEvent')->willReturn($event);

        // No exception expected on happy path.
        $this->subject->execute($observer);
        $this->expectNotToPerformAssertions();
    }

    public function testExecuteLogsExceptionAndContinues(): void
    {
        $observer = $this->createMock(Observer::class);
        $observer->method('getEvent')->willThrowException(new \RuntimeException('boom'));

        $this->logger->expects($this->once())->method('error');

        // Observer must NOT re-throw by default — see template comment.
        $this->subject->execute($observer);
        $this->expectNotToPerformAssertions();
    }
}
