<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Model\Indexer;

use Magento\Framework\Indexer\ActionInterface;
use Magento\Framework\Mview\ActionInterface as MviewActionInterface;

/**
 * Custom indexer for {Vendor}_{Module}.
 *
 * Implements both ActionInterfaces — the Indexer ActionInterface for full/list/row
 * reindex and the Mview ActionInterface for scheduled partial reindex via the mview
 * changelog. Contains zero reindex logic; all work is delegated to {IndexerName}Action.
 *
 * Target: {Vendor}/{Module}/Model/Indexer/{IndexerName}.php
 *
 * Declared in etc/indexer.xml (id) and etc/mview.xml (view id — must match).
 */
class {IndexerName} implements ActionInterface, MviewActionInterface
{
    /**
     * @param \{Vendor}\{Module}\Model\Indexer\{IndexerName}Action $action
     */
    public function __construct(
        private readonly {IndexerName}Action $action
    ) {
    }

    /**
     * Full reindex — rebuilds the entire index from the source table.
     *
     * Called by `bin/magento indexer:reindex {indexer_id}` and by the admin panel.
     * Delegates to {IndexerName}Action::executeFull() which performs idempotent
     * (delete-then-insert) rebuild.
     */
    public function executeFull(): void
    {
        $this->action->executeFull();
    }

    /**
     * Partial reindex for a list of entity ids — called in realtime ("Update on Save")
     * mode when multiple entities are saved together.
     *
     * Delegates to {IndexerName}Action::execute() which batches the ids internally.
     *
     * @param array $ids Entity primary key values
     */
    public function executeList(array $ids): void
    {
        $this->action->execute($ids);
    }

    /**
     * Single-entity reindex — called in realtime mode on each individual save.
     *
     * Wraps the id in an array and delegates to {IndexerName}Action::execute() so the
     * action only needs one code path. Keep this lightweight — it runs synchronously
     * during admin saves.
     *
     * @param int|string $id Entity primary key value
     */
    public function executeRow($id): void
    {
        $this->action->execute([$id]);
    }

    /**
     * Scheduled partial reindex — called by the mview cron to drain the changelog table.
     *
     * Implements Magento\Framework\Mview\ActionInterface::execute(). Delegates to
     * {IndexerName}Action::execute() which batches the ids internally.
     *
     * @param array $ids Entity primary key values from the mview changelog
     */
    public function execute(array $ids): void
    {
        $this->action->execute($ids);
    }
}
