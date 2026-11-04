<?php

namespace App\Services\Inventory;

use Illuminate\Contracts\Cache\Repository as Cache;

/**
 * Temporary stand-in for the .NET inventory service, so the core app can be built and
 * tested before the real service exists. Quantities live in the application cache.
 *
 * Set INVENTORY_FAKE_DOWN=true to simulate an unavailable inventory service.
 */
class FakeInventoryClient implements InventoryClient
{
    public function __construct(
        private readonly Cache $cache,
        private readonly bool $down = false,
    ) {}

    public function getStock(int $productId): int
    {
        $this->ensureUp();

        return (int) $this->cache->get($this->stockKey($productId), 0);
    }

    public function getStockBatch(array $productIds): array
    {
        $this->ensureUp();

        $stock = [];
        foreach ($productIds as $id) {
            $stock[$id] = (int) $this->cache->get($this->stockKey($id), 0);
        }

        return $stock;
    }

    public function setStock(int $productId, int $quantity): int
    {
        $this->ensureUp();

        $this->cache->forever($this->stockKey($productId), $quantity);

        return $quantity;
    }

    public function reserve(string $reservationId, array $items): ReservationResult
    {
        $this->ensureUp();

        return $this->cache->lock('inventory:lock', 5)->block(5, function () use ($reservationId, $items) {
            if ($this->cache->has($this->reservationKey($reservationId))) {
                return ReservationResult::accepted(); // idempotent
            }

            $unavailable = [];
            foreach ($items as $productId => $quantity) {
                $available = (int) $this->cache->get($this->stockKey($productId), 0);
                if ($available < $quantity) {
                    $unavailable[$productId] = $available;
                }
            }

            if ($unavailable) {
                return ReservationResult::rejected($unavailable);
            }

            foreach ($items as $productId => $quantity) {
                $this->cache->decrement($this->stockKey($productId), $quantity);
            }
            $this->cache->forever($this->reservationKey($reservationId), ['items' => $items, 'released' => false]);

            return ReservationResult::accepted();
        });
    }

    public function release(string $reservationId): void
    {
        $this->ensureUp();

        $this->cache->lock('inventory:lock', 5)->block(5, function () use ($reservationId) {
            $reservation = $this->cache->get($this->reservationKey($reservationId));
            if (! $reservation || $reservation['released']) {
                return;
            }

            foreach ($reservation['items'] as $productId => $quantity) {
                $this->cache->increment($this->stockKey($productId), $quantity);
            }
            $this->cache->forever($this->reservationKey($reservationId), [...$reservation, 'released' => true]);
        });
    }

    private function ensureUp(): void
    {
        if ($this->down) {
            throw new InventoryUnavailableException;
        }
    }

    private function stockKey(int $productId): string
    {
        return "inventory:stock:{$productId}";
    }

    private function reservationKey(string $reservationId): string
    {
        return "inventory:reservation:{$reservationId}";
    }
}
