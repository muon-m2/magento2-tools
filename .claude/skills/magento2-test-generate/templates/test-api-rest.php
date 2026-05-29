<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Api;

use Magento\TestFramework\TestCase\WebapiAbstract;

class {Entity}ApiTest extends WebapiAbstract
{
    private const RESOURCE_PATH = '/V1/{vendor_lower}/{route}';
    private const SERVICE_NAME = '{vendor}{Module}{Entity}RepositoryV1';

    public function testGetByIdReturnsExpectedShape(): void
    {
        $id = 1;
        $info = [
            'rest' => ['resourcePath' => self::RESOURCE_PATH . '/' . $id, 'httpMethod' => 'GET'],
            'soap' => ['service' => self::SERVICE_NAME, 'operation' => self::SERVICE_NAME . 'GetById'],
        ];

        $response = $this->_webApiCall($info, ['id' => $id]);

        self::assertArrayHasKey('id', $response);
        self::assertSame($id, $response['id']);
    }

    public function testGetByIdNotFoundReturns404(): void
    {
        $info = [
            'rest' => ['resourcePath' => self::RESOURCE_PATH . '/999999', 'httpMethod' => 'GET'],
            'soap' => ['service' => self::SERVICE_NAME, 'operation' => self::SERVICE_NAME . 'GetById'],
        ];

        try {
            $this->_webApiCall($info, ['id' => 999999]);
            self::fail('Expected NoSuchEntityException');
        } catch (\Exception $e) {
            self::assertStringContainsStringIgnoringCase('not found', $e->getMessage());
        }
    }
}
