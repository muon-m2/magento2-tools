# Importer Patterns

For bulk imports (CSV / JSON / external API) > 100 rows.

## Chunked Processing

```php
namespace {Vendor}\{Module}\Service\Importer;

use Magento\Framework\Filesystem\Driver\File;

final class CustomerImporter
{
    private const CHUNK_SIZE = 500;

    public function __construct(
        private readonly File $file,
        private readonly CustomerRepositoryInterface $repository,
        private readonly LoggerInterface $logger,
    ) {
    }

    public function import(string $sourcePath): array
    {
        if (!$this->file->isExists($sourcePath)) {
            throw new \InvalidArgumentException("Source not found: {$sourcePath}");
        }

        $handle = fopen($sourcePath, 'r');
        $header = fgetcsv($handle);
        $chunk = [];
        $stats = ['processed' => 0, 'failed' => 0, 'skipped' => 0];

        while (($row = fgetcsv($handle)) !== false) {
            $chunk[] = array_combine($header, $row);
            if (count($chunk) >= self::CHUNK_SIZE) {
                $this->processChunk($chunk, $stats);
                $chunk = [];
            }
        }
        if ($chunk) {
            $this->processChunk($chunk, $stats);
        }
        fclose($handle);

        return $stats;
    }

    private function processChunk(array $rows, array &$stats): void
    {
        foreach ($rows as $row) {
            try {
                if ($this->alreadyExists($row)) {
                    $stats['skipped']++;
                    continue;
                }
                $this->createCustomer($row);
                $stats['processed']++;
            } catch (\Exception $e) {
                $stats['failed']++;
                $this->logger->error("Import row failed", ['row' => $row, 'error' => $e->getMessage()]);
            }
        }
    }
}
```

## Idempotency in Importer

Check `alreadyExists()` before insert. Use a unique attribute (email for customers, SKU
for products) as the lookup key.

## Per-Row Failure Handling

A failing row does NOT abort the import. Log + continue. Stats track failures.

## Progress Reporting

For CLI:

```php
$output->writeln("Processed {$stats['processed']}, skipped {$stats['skipped']}, failed {$stats['failed']}");
```

For long-running imports, emit progress every N chunks.

## Memory

`fgetcsv()` reads one row at a time; doesn't load the file into memory. Avoid
`file_get_contents()` for files > 10MB.

If the source is JSON, prefer streaming parsing (`JsonStreamingParser`) over
`json_decode($entireFile)`.

## Driving from Setup Patch

```php
public function apply(): self
{
    $sourcePath = $this->moduleDir->getDir(__DIR__) . '/files/seed-customers.csv';
    $stats = $this->importer->import($sourcePath);
    $this->logger->info("Customer seed import", $stats);
    return $this;
}
```

This calls the importer from the patch. The patch becomes idempotent because the
importer checks existing state per row.

## Driving from CLI

For interactive runs:

```php
namespace {Vendor}\{Module}\Console\Command;

final class ImportCommand extends Command
{
    protected function configure(): void
    {
        $this->setName('{vendor}:{module}:import')
             ->addArgument('source', InputArgument::REQUIRED)
             ->addOption('dry-run', null, InputOption::VALUE_NONE);
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $source = $input->getArgument('source');
        $dryRun = $input->getOption('dry-run');

        $stats = $dryRun ? $this->importer->dryRun($source) : $this->importer->import($source);

        $output->writeln(json_encode($stats));
        return self::SUCCESS;
    }
}
```

Register the command in `etc/di.xml`.
