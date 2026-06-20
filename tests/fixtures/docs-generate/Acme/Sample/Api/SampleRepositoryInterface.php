<?php
declare(strict_types=1);
namespace Acme\Sample\Api;

use Acme\Sample\Api\Data\SampleInterface;
use Magento\Framework\Exception\NoSuchEntityException;

/** @api */
interface SampleRepositoryInterface
{
    /**
     * @throws NoSuchEntityException
     */
    public function getById(int $id): SampleInterface;

    public function save(SampleInterface $sample): SampleInterface;

    /** PHP 8 union types — request_shape must resolve the DTO, not degrade to "string". */
    public function upsert(SampleInterface|null $sample): SampleInterface|null;
}
