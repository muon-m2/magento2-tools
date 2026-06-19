<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Console\Command;

use Magento\Framework\Console\Cli;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Console\Tester\CommandTester;
use {Vendor}\{Module}\Console\Command\{CommandClass};
use {Vendor}\{Module}\Service\{ServiceName};

/**
 * Unit test for {CommandClass}.
 *
 * Asserts that execute() delegates to {ServiceName}, returns RETURN_SUCCESS (0)
 * on success, returns RETURN_FAILURE (1) on exception, and writes the expected
 * message to output. The service is mocked so no Magento bootstrap is required.
 * Target: {Vendor}/{Module}/Test/Unit/Console/Command/{CommandClass}Test.php
 */
class {CommandClass}Test extends TestCase
{
    /**
     * @var {ServiceName}&MockObject
     */
    private {ServiceName} $serviceMock;

    /**
     * @var {CommandClass}
     */
    private {CommandClass} $command;

    /**
     * @var CommandTester
     */
    private CommandTester $tester;

    /**
     * Build the command with a mocked service before each test.
     */
    protected function setUp(): void
    {
        $this->serviceMock = $this->createMock({ServiceName}::class);
        $this->command = new {CommandClass}($this->serviceMock);
        $this->tester = new CommandTester($this->command);
    }

    /**
     * When {ServiceName}::execute() succeeds, the command returns RETURN_SUCCESS
     * and writes a success message to output.
     */
    public function testExecuteReturnSuccessWhenServiceSucceeds(): void
    {
        $this->serviceMock
            ->expects(self::once())
            ->method('execute');

        $this->tester->execute([]);

        self::assertSame(Cli::RETURN_SUCCESS, $this->tester->getStatusCode());
        self::assertStringContainsString('completed successfully', $this->tester->getDisplay());
    }

    /**
     * When {ServiceName}::execute() throws an exception, the command returns
     * RETURN_FAILURE and writes the exception message to output.
     */
    public function testExecuteReturnFailureWhenServiceThrows(): void
    {
        $this->serviceMock
            ->expects(self::once())
            ->method('execute')
            ->willThrowException(new \RuntimeException('Service error'));

        $this->tester->execute([]);

        self::assertSame(Cli::RETURN_FAILURE, $this->tester->getStatusCode());
        self::assertStringContainsString('Service error', $this->tester->getDisplay());
    }
}
