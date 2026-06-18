<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Console\Command;

use Magento\Framework\Console\Cli;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use {Vendor}\{Module}\Service\{ServiceName};

/**
 * Console command: {CommandName}
 *
 * Delegates all business logic to {ServiceName}.
 * Target: {Vendor}/{Module}/Console/Command/{CommandClass}.php
 *
 * Register in etc/di.xml under Magento\Framework\Console\CommandList.
 */
class {CommandClass} extends Command
{
    /**
     * @param \{Vendor}\{Module}\Service\{ServiceName} $service
     * @param string|null $name
     */
    public function __construct(
        private readonly {ServiceName} $service,
        string $name = null
    ) {
        parent::__construct($name);
    }

    /**
     * Configure the command name, description, arguments, and options.
     */
    protected function configure(): void
    {
        $this->setName('{CommandName}')
            ->setDescription('Execute the {CommandName} operation.');
    }

    /**
     * Execute the command.
     *
     * Reads arguments and options from $input, delegates to {ServiceName},
     * writes result messages to $output, and returns a Cli::RETURN_* exit code.
     *
     * @param InputInterface $input
     * @param OutputInterface $output
     * @return int Cli::RETURN_SUCCESS (0) or Cli::RETURN_FAILURE (1)
     */
    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        try {
            $this->service->execute();
            $output->writeln('<info>{CommandName}: completed successfully.</info>');
            return Cli::RETURN_SUCCESS;
        } catch (\Exception $e) {
            $output->writeln('<error>{CommandName}: ' . $e->getMessage() . '</error>');
            return Cli::RETURN_FAILURE;
        }
    }
}
