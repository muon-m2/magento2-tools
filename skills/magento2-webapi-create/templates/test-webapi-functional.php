<?php

declare(strict_types=1);

namespace {Vendor}\{ModuleName}\Test\Api;

use Magento\Framework\Webapi\Rest\Request;
use Magento\TestFramework\TestCase\WebapiAbstract;

/**
 * Web API functional tests for the {EntityName} REST endpoints.
 *
 * Exercises the CRUD round-trip (POST create -> GET by id -> DELETE) plus a getList read through
 * the REST adapter. Place under the module's Test/Api and run with Magento's api-functional suite
 * (dev/tests/api-functional). See references/webapi-testing.md.
 */
class {EntityName}RepositoryTest extends WebapiAbstract
{
    private const RESOURCE_PATH = '/V1/{vendor_lower}/{route}';
    private const SERVICE_NAME  = '{vendor_lower}{ModuleName}{EntityName}RepositoryV1';

    /**
     * Full CRUD round-trip: create (POST), read (GET), update (PUT), delete (DELETE) — asserting
     * each transition.
     */
    public function testCrudRoundTrip(): void
    {
        // --- create (POST) ---
        $createInfo = [
            'rest' => [
                'resourcePath' => self::RESOURCE_PATH,
                'httpMethod'   => Request::HTTP_METHOD_POST,
            ],
            'soap' => [
                'service'        => self::SERVICE_NAME,
                'serviceVersion' => 'V1',
                'operation'      => self::SERVICE_NAME . 'Save',
            ],
        ];
        $created = $this->_webApiCall($createInfo, ['entity' => ['name' => 'Test {EntityName}']]);

        $this->assertArrayHasKey('entity_id', $created);
        $this->assertSame('Test {EntityName}', $created['name']);
        $entityId = (int) $created['entity_id'];

        // --- read (GET by id) ---
        $getInfo = [
            'rest' => [
                'resourcePath' => self::RESOURCE_PATH . '/' . $entityId,
                'httpMethod'   => Request::HTTP_METHOD_GET,
            ],
            'soap' => [
                'service'        => self::SERVICE_NAME,
                'serviceVersion' => 'V1',
                'operation'      => self::SERVICE_NAME . 'GetById',
            ],
        ];
        $fetched = $this->_webApiCall($getInfo, ['entityId' => $entityId]);
        $this->assertSame($entityId, (int) $fetched['entity_id']);

        // --- update (PUT) ---
        $updateInfo = [
            'rest' => [
                'resourcePath' => self::RESOURCE_PATH . '/' . $entityId,
                'httpMethod'   => Request::HTTP_METHOD_PUT,
            ],
            'soap' => [
                'service'        => self::SERVICE_NAME,
                'serviceVersion' => 'V1',
                'operation'      => self::SERVICE_NAME . 'Save',
            ],
        ];
        $updated = $this->_webApiCall(
            $updateInfo,
            ['entity' => ['entity_id' => $entityId, 'name' => 'Updated {EntityName}']]
        );
        $this->assertSame('Updated {EntityName}', $updated['name']);

        // --- delete (DELETE) ---
        $deleteInfo = [
            'rest' => [
                'resourcePath' => self::RESOURCE_PATH . '/' . $entityId,
                'httpMethod'   => Request::HTTP_METHOD_DELETE,
            ],
            'soap' => [
                'service'        => self::SERVICE_NAME,
                'serviceVersion' => 'V1',
                'operation'      => self::SERVICE_NAME . 'DeleteById',
            ],
        ];
        $this->assertTrue($this->_webApiCall($deleteInfo, ['entityId' => $entityId]));
    }

    /**
     * Asserts getList returns a paginated envelope (items + search_criteria + total_count).
     */
    public function testGetList(): void
    {
        $serviceInfo = [
            'rest' => [
                'resourcePath' => self::RESOURCE_PATH
                    . '?searchCriteria[pageSize]=10&searchCriteria[currentPage]=1',
                'httpMethod'   => Request::HTTP_METHOD_GET,
            ],
            'soap' => [
                'service'        => self::SERVICE_NAME,
                'serviceVersion' => 'V1',
                'operation'      => self::SERVICE_NAME . 'GetList',
            ],
        ];
        $searchCriteria = ['searchCriteria' => ['pageSize' => 10, 'currentPage' => 1]];

        $response = $this->_webApiCall($serviceInfo, $searchCriteria);

        $this->assertArrayHasKey('items', $response);
        $this->assertArrayHasKey('search_criteria', $response);
        $this->assertArrayHasKey('total_count', $response);
    }
}
