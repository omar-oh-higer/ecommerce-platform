<?php

namespace App\Jobs;

use App\Services\Inventory\InventoryClient;
use App\Services\OrderService;
use DateTimeInterface;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Gives a reservation back to the inventory service in the background.
 *
 * Used when the immediate release failed (e.g. the inventory service was down when an order
 * was cancelled or could not be saved). The queue keeps retrying until the service is back,
 * so the stock is never lost — however long the outage. Release is idempotent, so retries are safe.
 */
class ReleaseReservation implements ShouldQueue
{
    use Queueable;

    /**
     * Seconds to wait between attempts. After the last value the queue keeps using it,
     * so once the service is back the stock returns within about a minute.
     */
    public array $backoff = [5, 15, 30, 60];

    public function __construct(public readonly string $reservationId) {}

    /** Keep trying for a whole day instead of a fixed number of attempts. */
    public function retryUntil(): DateTimeInterface
    {
        return now()->addDay();
    }

    public function handle(InventoryClient $inventory): void
    {
        $inventory->release($this->reservationId);

        OrderService::markStockReleased($this->reservationId);
    }
}
