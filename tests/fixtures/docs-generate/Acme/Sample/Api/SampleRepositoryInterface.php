<?php
declare(strict_types=1);
namespace Acme\Sample\Api;

use Magento\Framework\Exception\NoSuchEntityException;

/** @api */
interface SampleRepositoryInterface
{
    /**
     * @throws NoSuchEntityException
     */
    public function getById(int $id): \Acme\Sample\Api\Data\SampleInterface;

    public function save(\Acme\Sample\Api\Data\SampleInterface $sample): \Acme\Sample\Api\Data\SampleInterface;
}
