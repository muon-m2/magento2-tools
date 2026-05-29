<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Unit\Controller\{Area};

use Magento\Framework\App\RequestInterface;
use Magento\Framework\App\ResponseInterface;
use Magento\Framework\Controller\Result\Forward;
use Magento\Framework\Controller\Result\ForwardFactory;
use Magento\Framework\Controller\Result\Redirect;
use Magento\Framework\Controller\Result\RedirectFactory;
use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\TestCase;
use {Vendor}\{Module}\Controller\{Area}\{Controller};

/**
 * Regression test for bug: {Symptom one-liner}.
 *
 * Bug ID: {slug}
 * RCA: .docs/bug-fixes/{slug}/rca.md
 *
 * If a {Controller}Test already exists, add testRegression{ShortDescription}() there
 * instead and delete this file; otherwise rename the class to {Controller}Test.
 */
final class {Controller}RegressionTest extends TestCase
{
    /** @var RequestInterface&MockObject */
    private MockObject $request;

    /** @var ResponseInterface&MockObject */
    private MockObject $response;

    /** @var RedirectFactory&MockObject */
    private MockObject $redirectFactory;

    private {Controller} $subject;

    protected function setUp(): void
    {
        $this->request = $this->createMock(RequestInterface::class);
        $this->response = $this->createMock(ResponseInterface::class);
        $this->redirectFactory = $this->createMock(RedirectFactory::class);

        $this->subject = new {Controller}(
            $this->request,
            $this->response,
            $this->redirectFactory,
        );
    }

    /**
     * The bug: {one-line description}.
     */
    public function testRegression{ShortDescription}(): void
    {
        // Arrange: emulate the reproduced request.
        $this->request
            ->method('getParam')
            ->willReturnMap([
                ['{paramName}', null, '{paramValue}'],
            ]);

        // Act
        $result = $this->subject->execute();

        // Assert: post-fix expectation (status code, redirect target, etc.)
        self::assertInstanceOf(Redirect::class, $result, 'Bug {slug}: should redirect, not return raw response');
    }
}
