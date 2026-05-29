<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Api\GraphQl;

use Magento\TestFramework\TestCase\GraphQlAbstract;

class {Entity}QueryTest extends GraphQlAbstract
{
    public function testQueryReturnsShape(): void
    {
        $query = <<<QUERY
query {
    {vendor_lower}{Entity}(id: 1) {
        id
        name
    }
}
QUERY;

        $response = $this->graphQlQuery($query);

        self::assertArrayHasKey('{vendor_lower}{Entity}', $response);
        self::assertSame(1, $response['{vendor_lower}{Entity}']['id']);
    }

    public function testQueryInputErrorThrows(): void
    {
        $query = <<<QUERY
query {
    {vendor_lower}{Entity}(id: -1) {
        id
    }
}
QUERY;

        $this->expectException(\Exception::class);
        $this->graphQlQuery($query);
    }
}
