<?php

namespace App\Services;

use App\Enums\OrderStatus;
use App\Events\OrderPlaced;
use App\Events\OrderStatusChanged;
use App\Exceptions\ApiException;
use App\Jobs\ReleaseReservation;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\Inventory\InventoryClient;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class OrderService
{
    public function __construct(private readonly InventoryClient $inventory) {}

    /**
     * Place an order (requirement 2 flow):
     *
     *   1. ONE call to the inventory service reserves every item (all or nothing).
     *        - rejected     → 409 INSUFFICIENT_STOCK, no order is created
     *        - down / slow  → 503 INVENTORY_UNAVAILABLE, no order is created
     *   2. The order is saved in one database transaction.
     *        - saving fails → the reservation is released, so the stock goes back
     *
     * @param  array<int, int>  $items  product id => quantity
     */
    public function place(User $user, array $items): Order
    {
        // Prices and names come from the database, never from the client.
        $products = Product::whereKey(array_keys($items))->get()->keyBy('id');

        $reservationId = (string) Str::uuid();

        // Step 1 — reserve. InventoryUnavailableException (503) bubbles up untouched.
        $reservation = $this->inventory->reserve($reservationId, $items);

        if (! $reservation->success) {
            throw new ApiException('INSUFFICIENT_STOCK', 'Some products do not have enough stock.', 409, [
                'items' => collect($reservation->unavailable)->map(fn (int $available, int $productId) => [
                    'product_id' => $productId,
                    'name' => $products[$productId]->name,
                    'requested' => $items[$productId],
                    'available' => $available,
                ])->values()->all(),
            ]);
        }

        // Step 2 — save. On any failure, give the stock back before reporting the error.
        try {
            return DB::transaction(function () use ($user, $items, $products, $reservationId) {
                $lines = collect($items)->map(function (int $quantity, int $productId) use ($products) {
                    $price = $products[$productId]->price;

                    return [
                        'product_id' => $productId,
                        'product_name' => $products[$productId]->name,
                        'unit_price' => $price,
                        'quantity' => $quantity,
                        'line_total' => bcmul((string) $price, (string) $quantity, 2),
                    ];
                })->values();

                $order = Order::create([
                    'user_id' => $user->id,
                    'reservation_id' => $reservationId,
                    'status' => OrderStatus::Pending,
                    'total' => $lines->reduce(fn (string $sum, array $line) => bcadd($sum, $line['line_total'], 2), '0.00'),
                ]);

                $order->items()->createMany($lines->all());

                // Sent only once the transaction commits (ShouldDispatchAfterCommit).
                OrderPlaced::dispatch($order);

                return $order;
            });
        } catch (Throwable $e) {
            $this->releaseOrRetry($reservationId);

            throw $e;
        }
    }

    /**
     * Admin changes the status. Only the transitions in OrderStatus::next() are allowed.
     *
     * Cancelling always succeeds, even when the inventory service is down: the order is cancelled
     * at once and its stock is given back now, or — if the service cannot be reached — by a queued
     * job as soon as it is back. `stock_released_at` stays NULL until the stock is really back.
     */
    public function changeStatus(Order $order, OrderStatus $status): Order
    {
        return DB::transaction(function () use ($order, $status) {
            // Lock the row: two admins cannot move the same order at the same moment.
            $order = Order::lockForUpdate()->findOrFail($order->id);

            if (! $order->status->canMoveTo($status)) {
                throw new ApiException(
                    'INVALID_STATUS_TRANSITION',
                    "An order cannot move from '{$order->status->value}' to '{$status->value}'.",
                    409,
                    ['current' => $order->status->value, 'allowed' => array_column($order->status->next(), 'value')],
                );
            }

            $from = $order->status;
            $order->update(['status' => $status]);

            OrderStatusChanged::dispatch($order, $from);

            if ($status === OrderStatus::Cancelled) {
                // After the commit: the cancellation is saved whatever happens to the inventory call.
                DB::afterCommit(fn () => $this->releaseOrRetry($order->reservation_id));
            }

            return $order;
        })->refresh();   // picks up stock_released_at written after the commit
    }

    /**
     * Try to release now; if the inventory service cannot be reached, queue a retry
     * so the stock is never lost.
     */
    private function releaseOrRetry(string $reservationId): void
    {
        try {
            $this->inventory->release($reservationId);
            self::markStockReleased($reservationId);
        } catch (Throwable $e) {
            Log::warning('Stock release failed, queued for retry', ['reservation_id' => $reservationId, 'error' => $e->getMessage()]);
            ReleaseReservation::dispatch($reservationId);
        }
    }

    /** Records that the order's stock is back in the inventory service (no-op if there is no order). */
    public static function markStockReleased(string $reservationId): void
    {
        Order::where('reservation_id', $reservationId)
            ->whereNull('stock_released_at')
            ->update(['stock_released_at' => now()]);
    }
}
