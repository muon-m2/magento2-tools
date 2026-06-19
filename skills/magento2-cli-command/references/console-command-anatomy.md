# Console Command Anatomy

A `bin/magento` command is a `Symfony\Component\Console\Command\Command` subclass wired
into Magento's `CommandList` via DI. Magento discovers all commands registered there on
every `bin/magento` invocation.

## Class skeleton

```php
namespace {Vendor}\{Module}\Console\Command;

use Magento\Framework\Console\Cli;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

class {CommandClass} extends Command
{
    // Constants keep the argument/option names in one place
    private const ARG_ENTITY_ID = 'entity-id';
    private const OPT_DRY_RUN   = 'dry-run';

    public function __construct(
        private readonly {ServiceName} $service,
        string $name = null
    ) {
        parent::__construct($name);
    }

    protected function configure(): void
    {
        $this->setName('{CommandName}')
            ->setDescription('{description}')
            ->addArgument(self::ARG_ENTITY_ID, InputArgument::REQUIRED, 'Entity ID to process')
            ->addOption(self::OPT_DRY_RUN, 'd', InputOption::VALUE_NONE, 'Simulate without saving');
    }

    protected function execute(InputInterface $input, OutputInterface $output): int
    {
        $entityId = (int) $input->getArgument(self::ARG_ENTITY_ID);
        $dryRun   = (bool) $input->getOption(self::OPT_DRY_RUN);

        try {
            $this->service->run($entityId, $dryRun);
            $output->writeln('<info>Done.</info>');
            return Cli::RETURN_SUCCESS;
        } catch (\Exception $e) {
            $output->writeln('<error>' . $e->getMessage() . '</error>');
            return Cli::RETURN_FAILURE;
        }
    }
}
```

## configure() rules

- `setName(string)` — the namespaced CLI name (`{vendor_lower}:{module_lower}:{action}`).
- `setDescription(string)` — shown in `bin/magento list`; keep it to one sentence.
- `addArgument(name, mode, description)` — `InputArgument::REQUIRED` or `OPTIONAL`.
- `addOption(name, shortcut, mode, description)` — `InputOption::VALUE_NONE` for flags,
  `InputOption::VALUE_REQUIRED` / `VALUE_OPTIONAL` for value options.

## execute() rules

- Always declare `int` return type (Symfony ≥ 5 enforces it).
- Return **`Cli::RETURN_SUCCESS`** (0) or **`Cli::RETURN_FAILURE`** (1) — never bare
  integer literals; the constants are in `Magento\Framework\Console\Cli`.
- Wrap all business logic in try/catch and write errors via `$output->writeln('<error>…')`.
- Use `$output->writeln('<info>…')` for success and `<comment>` for warnings.

## CommandList DI registration

Add the command to `etc/di.xml` as a virtual type item under
`Magento\Framework\Console\CommandList`:

```xml
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:noNamespaceSchemaLocation="urn:magento:framework:ObjectManager/etc/config.xsd">
    <type name="Magento\Framework\Console\CommandList">
        <arguments>
            <argument name="commands" xsi:type="array">
                <item name="{command_name}" xsi:type="object">
                    {Vendor}\{Module}\Console\Command\{CommandClass}
                </item>
            </argument>
        </arguments>
    </type>
</config>
```

The `name` attribute on `<item>` is a unique string key in the DI array — use
`{command_name}` (snake_case). The value is the fully-qualified class name.

## Testing with CommandTester

```php
use Symfony\Component\Console\Tester\CommandTester;

$tester = new CommandTester($command);
$tester->execute(['entity-id' => '42', '--dry-run' => true]);

self::assertSame(0, $tester->getStatusCode());
self::assertStringContainsString('Done.', $tester->getDisplay());
```

`CommandTester::getStatusCode()` returns the integer returned by `execute()`.
`CommandTester::getDisplay()` returns the buffered output text.
