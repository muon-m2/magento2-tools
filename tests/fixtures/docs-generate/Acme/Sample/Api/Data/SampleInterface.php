<?php
declare(strict_types=1);
namespace Acme\Sample\Api\Data;

/** @api */
interface SampleInterface
{
    public function getEntityId(): int;
    public function getCustomerEmail(): string;
    public function isActive(): bool;

    /** A getter whose type lives outside this module — the example walker cannot
     *  resolve it and must degrade the field to a "string" placeholder. */
    public function getStore(): \Magento\Store\Api\Data\StoreInterface;
}
