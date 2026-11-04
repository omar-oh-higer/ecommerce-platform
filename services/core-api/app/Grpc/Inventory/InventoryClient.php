<?php
// GENERATED CODE -- DO NOT EDIT!

namespace App\Grpc\Inventory;

/**
 * Inventory service contract.
 * Client: core-api (Laravel). Server: inventory-service (.NET).
 * The core app never touches the inventory database; it only talks through this contract.
 */
class InventoryClient extends \Grpc\BaseStub {

    /**
     * @param string $hostname hostname
     * @param array $opts channel options
     * @param \Grpc\Channel $channel (optional) re-use channel object
     */
    public function __construct($hostname, $opts, $channel = null) {
        parent::__construct($hostname, $opts, $channel);
    }

    /**
     * 1) Get quantity: how many units of this product are left?
     * @param \App\Grpc\Inventory\GetStockRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall
     */
    public function GetStock(\App\Grpc\Inventory\GetStockRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/inventory.v1.Inventory/GetStock',
        $argument,
        ['\App\Grpc\Inventory\StockReply', 'decode'],
        $metadata, $options);
    }

    /**
     * Same as GetStock for many products in one call (product listing pages).
     * @param \App\Grpc\Inventory\GetStockBatchRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall
     */
    public function GetStockBatch(\App\Grpc\Inventory\GetStockBatchRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/inventory.v1.Inventory/GetStockBatch',
        $argument,
        ['\App\Grpc\Inventory\GetStockBatchReply', 'decode'],
        $metadata, $options);
    }

    /**
     * 2) Reserve quantity: one call reserves ALL items of an order (all or nothing).
     *    Idempotent per reservation_id: repeating the call never deducts twice.
     * @param \App\Grpc\Inventory\ReserveStockRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall
     */
    public function ReserveStock(\App\Grpc\Inventory\ReserveStockRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/inventory.v1.Inventory/ReserveStock',
        $argument,
        ['\App\Grpc\Inventory\ReserveStockReply', 'decode'],
        $metadata, $options);
    }

    /**
     * 3) Release quantity: give back what was reserved if the order fails or is cancelled.
     *    Idempotent per reservation_id: releasing twice returns the stock only once.
     * @param \App\Grpc\Inventory\ReleaseStockRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall
     */
    public function ReleaseStock(\App\Grpc\Inventory\ReleaseStockRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/inventory.v1.Inventory/ReleaseStock',
        $argument,
        ['\App\Grpc\Inventory\ReleaseStockReply', 'decode'],
        $metadata, $options);
    }

    /**
     * Admin inventory management: set the absolute quantity of a product.
     * @param \App\Grpc\Inventory\SetStockRequest $argument input argument
     * @param array $metadata metadata
     * @param array $options call options
     * @return \Grpc\UnaryCall
     */
    public function SetStock(\App\Grpc\Inventory\SetStockRequest $argument,
      $metadata = [], $options = []) {
        return $this->_simpleRequest('/inventory.v1.Inventory/SetStock',
        $argument,
        ['\App\Grpc\Inventory\StockReply', 'decode'],
        $metadata, $options);
    }

}
