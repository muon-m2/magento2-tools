<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Unit\Controller\{ControllerArea}\{Entity};

use Magento\Framework\Controller\ResultFactory;
use Magento\Framework\Controller\ResultInterface;
use Magento\Framework\View\Result\Page;
use Magento\Framework\View\Page\Config;
use Magento\Framework\View\Page\Title;
use {Vendor}\{ModuleName}\Controller\{ControllerArea}\{Entity}\{ActionName};
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;

/**
 * Unit tests for {ActionName} controller.
 */
class {ActionName}Test extends TestCase
{
    private ResultFactory&MockObject $resultFactory;
    private {ActionName} $subject;

    protected function setUp(): void
    {
        $this->resultFactory = $this->createMock(ResultFactory::class);
        $this->subject       = new {ActionName}($this->resultFactory);
    }

    public function testExecuteReturnsPageResult(): void
    {
        $title = $this->createMock(Title::class);
        $title->expects($this->once())->method('set');

        $config = $this->createMock(Config::class);
        $config->method('getTitle')->willReturn($title);

        $page = $this->createMock(Page::class);
        $page->method('getConfig')->willReturn($config);

        $this->resultFactory
            ->expects($this->once())
            ->method('create')
            ->with(ResultFactory::TYPE_PAGE)
            ->willReturn($page);

        $result = $this->subject->execute();
        $this->assertInstanceOf(ResultInterface::class, $result);
    }
}
