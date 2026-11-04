<?php

namespace App\Services\Inventory;

use App\Grpc\Inventory\GetStockBatchRequest;
use App\Grpc\Inventory\GetStockRequest;
use App\Grpc\Inventory\InventoryClient as InventoryStub;
use App\Grpc\Inventory\ReleaseStockRequest;
use App\Grpc\Inventory\ReserveStockRequest;
use App\Grpc\Inventory\SetStockRequest;
use App\Grpc\Inventory\StockItem;
use Google\Protobuf\Internal\Message;
use Grpc\ChannelCredentials;
use Grpc\UnaryCall;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Talks to the .NET inventory service over gRPC (proto/inventory.proto).
 *
 * Every call has a deadline: the user never waits forever. When the service is down
 * (UNAVAILABLE), too slow (DEADLINE_EXCEEDED) or fails, the call throws
 * InventoryUnavailableException, which the API renders as 503 INVENTORY_UNAVAILABLE.
 */
class GrpcInventoryClient implements InventoryClient
{
    private ?InventoryStub $stub = null;

    public function __construct(
        private readonly string $host,
        private readonly int $timeoutMs,
    ) {}

    public function getStock(int $productId): int
    {
        $reply = $this->call('GetStock', fn (InventoryStub $s, array $o) => $s->GetStock(
            new GetStockRequest(['product_id' => $productId]), [], $o,
        ));

        return (int) $reply->getQuantity();
    }

    public function getStockBatch(array $productIds): array
    {
        if ($productIds === []) {
            return [];
        }

        $reply = $this->call('GetStockBatch', fn (InventoryStub $s, array $o) => $s->GetStockBatch(
            new GetStockBatchRequest(['product_ids' => array_values($productIds)]), [], $o,
        ));

        $stock = [];
        foreach ($reply->getItems() as $item) {
            $stock[(int) $item->getProductId()] = (int) $item->getQuantity();
        }

        return $stock;
    }

    public function setStock(int $productId, int $quantity): int
    {
        $reply = $this->call('SetStock', fn (InventoryStub $s, array $o) => $s->SetStock(
            new SetStockRequest(['product_id' => $productId, 'quantity' => $quantity]), [], $o,
        ));

        return (int) $reply->getQuantity();
    }

    public function reserve(string $reservationId, array $items): ReservationResult
    {
        $request = new ReserveStockRequest([
            'reservation_id' => $reservationId,
            'items' => array_map(
                fn (int $productId, int $quantity) => new StockItem(['product_id' => $productId, 'quantity' => $quantity]),
                array_keys($items),
                array_values($items),
            ),
        ]);

        $reply = $this->call('ReserveStock', fn (InventoryStub $s, array $o) => $s->ReserveStock($request, [], $o));

        if ($reply->getSuccess()) {
            return ReservationResult::accepted();
        }

        $unavailable = [];
        foreach ($reply->getUnavailableItems() as $item) {
            $unavailable[(int) $item->getProductId()] = (int) $item->getQuantity();
        }

        return ReservationResult::rejected($unavailable);
    }

    public function release(string $reservationId): void
    {
        $reply = $this->call('ReleaseStock', fn (InventoryStub $s, array $o) => $s->ReleaseStock(
            new ReleaseStockRequest(['reservation_id' => $reservationId]), [], $o,
        ));

        if (! $reply->getSuccess()) {
            // Unknown reservation: nothing to give back (same behaviour as the fake client).
            Log::info('Inventory release ignored', ['reservation_id' => $reservationId, 'reason' => $reply->getMessage()]);
        }
    }

    /**
     * Run one unary call with the deadline and translate gRPC failures.
     *
     * @template T of Message
     *
     * @param  callable(InventoryStub, array): UnaryCall  $start
     * @return T
     */
    private function call(string $method, callable $start): Message
    {
        $started = microtime(true);

        try {
            /** @var UnaryCall $call */
            $call = $start($this->stub(), ['timeout' => $this->timeoutMs * 1000]); // microseconds
            [$reply, $status] = $call->wait();
        } catch (\Throwable $e) {
            throw new InventoryUnavailableException($e);
        }

        if ($status->code !== \Grpc\STATUS_OK) {
            $reason = new RuntimeException(sprintf(
                'Inventory %s failed: %s (code %d) after %d ms',
                $method, $status->details, $status->code, (int) ((microtime(true) - $started) * 1000),
            ));

            // A bad request is our bug, not an outage: surface it as a 500.
            if ($status->code === \Grpc\STATUS_INVALID_ARGUMENT) {
                throw $reason;
            }

            throw new InventoryUnavailableException($reason);
        }

        return $reply;
    }

    private function stub(): InventoryStub
    {
        return $this->stub ??= new InventoryStub($this->host, [
            'credentials' => ChannelCredentials::createInsecure(), // internal Docker network
            // Fail fast when the service is down instead of waiting to reconnect.
            'grpc.initial_reconnect_backoff_ms' => 200,
            'grpc.max_reconnect_backoff_ms' => 1000,
        ]);
    }
}
