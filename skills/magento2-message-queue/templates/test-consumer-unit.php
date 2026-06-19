<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Model\Consumer;

use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Psr\Log\LoggerInterface;
use {Vendor}\{Module}\Api\Data\{EntityName}Interface;
use {Vendor}\{Module}\Model\Consumer\{ConsumerName};
use {Vendor}\{Module}\Service\{EntityName}Handler;

/**
 * Unit test for the {ConsumerName} message consumer.
 *
 * Asserts that process() decodes the typed {EntityName}Interface message and delegates to
 * {EntityName}Handler exactly once, and that a SECOND delivery of the same message is a
 * safe no-op (idempotency) because the handler reports it as already processed. The
 * handler and message are mocked, so no Magento bootstrap is required.
 * Target: {Vendor}/{Module}/Test/Unit/Model/Consumer/{ConsumerName}Test.php
 */
class {ConsumerName}Test extends TestCase
{
    /**
     * @var {EntityName}Handler&MockObject
     */
    private {EntityName}Handler $handlerMock;

    /**
     * @var LoggerInterface&MockObject
     */
    private LoggerInterface $loggerMock;

    /**
     * @var {ConsumerName}
     */
    private {ConsumerName} $consumer;

    /**
     * Build the consumer with mocked collaborators before each test.
     */
    protected function setUp(): void
    {
        $this->handlerMock = $this->createMock({EntityName}Handler::class);
        $this->loggerMock = $this->createMock(LoggerInterface::class);
        $this->consumer = new {ConsumerName}($this->handlerMock, $this->loggerMock);
    }

    /**
     * A fresh (not-yet-processed) message must be decoded and handed to the handler
     * exactly once.
     */
    public function testProcessDelegatesDecodedMessageToHandlerOnce(): void
    {
        $message = $this->createMock({EntityName}Interface::class);

        $this->handlerMock
            ->expects(self::once())
            ->method('isProcessed')
            ->with($message)
            ->willReturn(false);

        $this->handlerMock
            ->expects(self::once())
            ->method('process')
            ->with($message);

        $this->consumer->process($message);
    }

    /**
     * Idempotency: a SECOND delivery of the SAME message — one the handler reports as
     * already processed — must be a safe no-op. The handler's domain work runs zero times
     * on the redelivery.
     */
    public function testProcessIsNoOpForAlreadyProcessedMessage(): void
    {
        $message = $this->createMock({EntityName}Interface::class);

        $this->handlerMock
            ->expects(self::once())
            ->method('isProcessed')
            ->with($message)
            ->willReturn(true);

        $this->handlerMock
            ->expects(self::never())
            ->method('process');

        // Second delivery of the same message: the guard short-circuits, no domain work.
        $this->consumer->process($message);
    }

    /**
     * An un-retryable (bad-data) failure must be logged and swallowed, never re-thrown —
     * a poison message must not be re-queued forever.
     */
    public function testProcessLogsAndDropsUnprocessableMessage(): void
    {
        $message = $this->createMock({EntityName}Interface::class);
        $message->method('getEntityId')->willReturn(42);

        $this->handlerMock
            ->method('isProcessed')
            ->with($message)
            ->willReturn(false);

        $this->handlerMock
            ->expects(self::once())
            ->method('process')
            ->with($message)
            ->willThrowException(new \InvalidArgumentException('bad payload'));

        $this->loggerMock
            ->expects(self::once())
            ->method('error');

        // Must NOT throw — the consumer swallows the un-retryable failure.
        $this->consumer->process($message);
    }
}
