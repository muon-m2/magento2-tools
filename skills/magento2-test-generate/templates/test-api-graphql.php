<?php

declare(strict_types=1);

namespace {Vendor}\{Module}\Test\Api\GraphQl;

use Magento\TestFramework\TestCase\GraphQlAbstract;

class {Entity}QueryTest extends GraphQlAbstract
{
    /**
     * Asserts the GraphQL query returns the expected response shape.
     */
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

    /**
     * Asserts the GraphQL query surfaces an input error as an exception.
     */
    public function testQueryInputErrorThrows(): void
    {
        $query = <<<QUERY
query {
    {vendor_lower}{Entity}(id: -1) {
        id
    }
}
QUERY;

        // GraphQlAbstract surfaces server-side GraphQlInputException as a
        // \Exception whose message is prefixed "GraphQL response contains errors:".
        // Assert on that specific message rather than catching any \Exception.
        $this->expectException(\Exception::class);
        $this->expectExceptionMessageMatches('/GraphQL response contains errors/');
        $this->graphQlQuery($query);
    }
}
