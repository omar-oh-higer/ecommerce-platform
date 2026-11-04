<?php

namespace App\Services\Inventory;

/**
 * The only way core-api talks to the inventory service.
 * Mirrors the RPCs in proto/inventory.proto.
 *
 * Implementations:
 *  - FakeInventoryClient: in-app stand-in used until the .NET service exists (INVENTORY_DRIVER=fake)
 *  - GrpcInventoryClient: the real gRPC client (added in the integration step)
 *
 * Every method throws InventoryUnavailableException when the service is down or too slow.
 */
interface InventoryClient
{
    /** Units available for one product (0 when the product has no stock record). */
    public function getStock(int $productId): int;

    /**
     * Units available for many products in one call.
     *
     * @param  int[]  $productIds
     * @return array<int, int> product id => quantity
     */
    public function getStockBatch(array $productIds): array;

    /** Set the absolute quantity of a product (admin inventory management). */
    public function setStock(int $productId, int $quantity): int;

    /**
     * Reserve every item of an order in one call: all items or none.
     * Repeating the call with the same reservation id never reserves twice.
     *
     * @param  array<int, int>  $items  product id => quantity
     */
    public function reserve(string $reservationId, array $items): ReservationResult;

    /** Give back a reservation. Releasing twice returns the stock only once. */
    public function release(string $reservationId): void;
}
