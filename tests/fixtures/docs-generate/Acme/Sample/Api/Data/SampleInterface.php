<?php
declare(strict_types=1);
namespace Acme\Sample\Api\Data;

/** @api */
interface SampleInterface
{
    public function getEntityId(): int;
    public function getCustomerEmail(): string;
    public function isActive(): bool;
}
