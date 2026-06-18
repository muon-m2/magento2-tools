<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Cron;

use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Cron\{CronJobName};
use {Vendor}\{Module}\Service\{ServiceName};

/**
 * Unit test for {CronJobName}.
 *
 * Asserts that execute() delegates to {ServiceName} exactly once per invocation,
 * and that constructing a fresh instance and calling execute() a second time is safe
 * (class-level idempotency: the cron class itself carries no state that breaks on
 * a second call — idempotency of the side-effects is {ServiceName}'s responsibility).
 * No Magento bootstrap required: {ServiceName} is mocked.
 * Target: {Vendor}/{Module}/Test/Unit/Cron/{CronJobName}Test.php
 */
class {CronJobName}Test extends TestCase
{
    /**
     * @var {ServiceName}&MockObject
     */
    private {ServiceName} $serviceMock;

    /**
     * @var {CronJobName}
     */
    private {CronJobName} $job;

    /**
     * Build the cron job with a mocked service before each test.
     */
    protected function setUp(): void
    {
        $this->serviceMock = $this->createMock({ServiceName}::class);
        $this->job = new {CronJobName}($this->serviceMock);
    }

    /**
     * execute() must delegate to {ServiceName}::execute() exactly once.
     */
    public function testExecuteDelegatesToService(): void
    {
        $this->serviceMock
            ->expects(self::once())
            ->method('execute');

        $this->job->execute();
    }

    /**
     * Calling execute() on a new instance is safe (the cron class itself holds no
     * state that would corrupt a second invocation).
     *
     * Note: this test demonstrates class-level safety. Whether the underlying
     * {ServiceName}::execute() is idempotent for the same data set is tested in
     * the {ServiceName} unit/integration tests.
     */
    public function testExecuteIsStatelessBetweenInstances(): void
    {
        // First instance — first invocation
        $firstMock = $this->createMock({ServiceName}::class);
        $firstMock->expects(self::once())->method('execute');
        $firstJob = new {CronJobName}($firstMock);
        $firstJob->execute();

        // Second instance — simulates a second cron dispatch with a fresh object graph
        $secondMock = $this->createMock({ServiceName}::class);
        $secondMock->expects(self::once())->method('execute');
        $secondJob = new {CronJobName}($secondMock);
        $secondJob->execute();

        // Both invocations completed without exception — the cron class does not
        // carry cross-invocation state that would cause the second call to fail.
        self::assertInstanceOf({CronJobName}::class, $secondJob);
    }
}
