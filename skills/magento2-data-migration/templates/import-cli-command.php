<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Console\Command;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;
use {Vendor}\{Module}\Service\Importer\{Entity}Importer;

/**
 * CLI: bin/magento {vendor}:{module}:import <source-path> [--dry-run]
 */
class Import{Entity}Command extends Command
{
    /**
     * Constructor.
     *
     * @param \{Vendor}\{Module}\Service\Importer\{Entity}Importer $importer
     * @param string|null $name
     */
    public function __construct(
        private readonly {Entity}Importer $importer,
        ?string $name = null,
    ) {
        parent::__construct($name);
    }

    /**
     * Configure the command name, description, arguments and options.
     *
     * @return void
     */
    protected function configure(): void
    {
        $this->setName('{vendor_lower}:{module_lower}:import')
             ->setDescription('Import {entities} from a CSV source')
             ->addArgument('source', InputArgument::REQUIRED, 'Path to the CSV file')
             ->addOption('dry-run', null, InputOption::VALUE_NONE, 'Report what would be imported without writing');
    }

    /**
     * Execute the import command.
     *
     * @param \Symfony\Component\Console\Input\InputInterface $input
     * @param \Symfony\Component\Console\Output\OutputInterface $output
     * @return int
     */
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $source = (string) $input->getArgument('source');
        $dryRun = (bool) $input->getOption('dry-run');

        if ($dryRun) {
            $output->writeln('<info>Dry-run mode — no rows will be written.</info>');
            // For a full dry-run, the importer needs a dryRun() method that returns stats
            // without inserting; the template's importer doesn't expose that — extend if needed.
            $stats = ['dry_run' => true, 'source' => $source];
        } else {
            $stats = $this->importer->import($source);
        }

        $output->writeln(json_encode($stats, JSON_THROW_ON_ERROR));
        return self::SUCCESS;
    }
}
