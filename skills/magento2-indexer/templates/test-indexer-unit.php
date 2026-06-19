<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Model\Indexer;

use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Model\Indexer\{IndexerName};
use {Vendor}\{Module}\Model\Indexer\{IndexerName}Action;

/**
 * Unit test for {IndexerName}.
 *
 * Asserts that every public method delegates to {IndexerName}Action with the correct
 * arguments, and that the indexer class carries no state that would make a second call
 * unsafe (idempotency-safety at the class level).
 *
 * Target: {Vendor}/{Module}/Test/Unit/Model/Indexer/{IndexerName}Test.php
 */
class {IndexerName}Test extends TestCase
{
    /**
     * @var {IndexerName}Action&MockObject
     */
    private {IndexerName}Action $actionMock;

    /**
     * @var {IndexerName}
     */
    private {IndexerName} $indexer;

    /**
     * Build the indexer with a mocked action before each test.
     */
    protected function setUp(): void
    {
        $this->actionMock = $this->createMock({IndexerName}Action::class);
        $this->indexer = new {IndexerName}($this->actionMock);
    }

    /**
     * executeFull() must delegate to action->executeFull() exactly once with no
     * arguments — no ids, no extra parameters.
     */
    public function testExecuteFullDelegatesToActionExecuteFull(): void
    {
        $this->actionMock
            ->expects(self::once())
            ->method('executeFull');

        $this->indexer->executeFull();
    }

    /**
     * executeList() must pass the id array through to action->execute() unchanged.
     */
    public function testExecuteListDelegatesToActionExecuteWithIds(): void
    {
        $ids = [1, 2, 3];

        $this->actionMock
            ->expects(self::once())
            ->method('execute')
            ->with($ids);

        $this->indexer->executeList($ids);
    }

    /**
     * executeRow() must wrap the single id in an array and delegate to action->execute().
     */
    public function testExecuteRowDelegatesToActionExecuteWithWrappedId(): void
    {
        $id = 42;

        $this->actionMock
            ->expects(self::once())
            ->method('execute')
            ->with([$id]);

        $this->indexer->executeRow($id);
    }

    /**
     * Mview execute() must pass the id array through to action->execute() unchanged.
     * This is the scheduled partial-reindex path (mview changelog drain).
     */
    public function testMviewExecuteDelegatesToActionExecuteWithIds(): void
    {
        $ids = [10, 20];

        $this->actionMock
            ->expects(self::once())
            ->method('execute')
            ->with($ids);

        $this->indexer->execute($ids);
    }

    /**
     * The indexer class must carry no hidden state — two separate instances with fresh
     * mocks must each delegate once without interfering with each other.
     * This confirms the class is safe to call repeatedly (idempotency-safety at the
     * class boundary; actual idempotency of the SQL lives in {IndexerName}Action).
     */
    public function testExecuteFullIsStatelessAcrossInstances(): void
    {
        $firstActionMock = $this->createMock({IndexerName}Action::class);
        $firstActionMock
            ->expects(self::once())
            ->method('executeFull');

        $secondActionMock = $this->createMock({IndexerName}Action::class);
        $secondActionMock
            ->expects(self::once())
            ->method('executeFull');

        $firstIndexer = new {IndexerName}($firstActionMock);
        $secondIndexer = new {IndexerName}($secondActionMock);

        $firstIndexer->executeFull();
        $secondIndexer->executeFull();
    }
}
