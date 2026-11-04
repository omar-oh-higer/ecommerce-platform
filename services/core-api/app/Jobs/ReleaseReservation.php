<?php

namespace App\Jobs;

use App\Services\Inventory\InventoryClient;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Gives a reservation back to the inventory service in the background.
 *
 * Used when the immediate release failed (e.g. inventory was down at that moment):
 * the queue retries until the stock is returned. Release is idempotent, so retries are safe.
 */
class ReleaseReservation implements ShouldQueue
{
    use Queueable;

    public int $tries = 10;

    /** Seconds to wait between attempts. */
    public array $backoff = [5, 15, 30, 60, 120];

    public function __construct(public readonly string $reservationId) {}

    public function handle(InventoryClient $inventory): void
    {
        $inventory->release($this->reservationId);
    }
}
