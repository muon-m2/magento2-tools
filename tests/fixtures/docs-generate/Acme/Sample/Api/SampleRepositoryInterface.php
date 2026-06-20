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
}
