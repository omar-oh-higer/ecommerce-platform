<?php

namespace Tests\Feature;

use App\Services\Inventory\GrpcInventoryClient;
use App\Services\Inventory\InventoryUnavailableException;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Cross-language integration test: PHP (core-api) → gRPC → .NET inventory service.
 *
 * Runs only where ext-grpc and the service are available, i.e. inside Docker:
 *   docker compose exec core-api php artisan test --filter=GrpcInventoryClientTest
 * Uses random high product ids so it never touches real catalogue stock.
 */
class GrpcInventoryClientTest extends TestCase
{
    private GrpcInventoryClient $client;

    protected function setUp(): void
    {
        parent::setUp();

        $host = getenv('INVENTORY_GRPC_HOST') ?: null;

        if (! extension_loaded('grpc') || ! $host) {
            $this->markTestSkipped('Needs ext-grpc and the inventory service (run inside Docker).');
        }

        $this->client = new GrpcInventoryClient($host, 2000);
    }

    private function productId(): int
    {
        return random_int(50_000_000, 90_000_000);
    }

    public function test_set_and_get_stock(): void
    {
        $id = $this->productId();

        $this->assertSame(4, $this->client->setStock($id, 4));
        $this->assertSame(4, $this->client->getStock($id));
        $this->assertSame(0, $this->client->getStock($this->productId()), 'unknown product has 0');
    }

    public function test_stock_batch(): void
    {
        [$a, $b] = [$this->productId(), $this->productId()];
        $this->client->setStock($a, 3);
        $this->client->setStock($b, 9);

        $this->assertEquals([$a => 3, $b => 9], $this->client->getStockBatch([$a, $b]));
        $this->assertSame([], $this->client->getStockBatch([]));
    }

    public function test_reserve_accepts_and_rejects_with_details(): void
    {
        [$plenty, $scarce] = [$this->productId(), $this->productId()];
        $this->client->setStock($plenty, 10);
        $this->client->setStock($scarce, 1);

        $rejected = $this->client->reserve((string) Str::uuid(), [$plenty => 2, $scarce => 3]);
        $this->assertFalse($rejected->success);
        $this->assertSame([$scarce => 1], $rejected->unavailable);
        $this->assertSame(10, $this->client->getStock($plenty), 'all or nothing');

        $accepted = $this->client->reserve((string) Str::uuid(), [$plenty => 2, $scarce => 1]);
        $this->assertTrue($accepted->success);
        $this->assertSame(8, $this->client->getStock($plenty));
        $this->assertSame(0, $this->client->getStock($scarce));
    }

    public function test_release_gives_stock_back_once_and_ignores_unknown_ids(): void
    {
        $id = $this->productId();
        $this->client->setStock($id, 5);
        $reservation = (string) Str::uuid();
        $this->client->reserve($reservation, [$id => 3]);

        $this->client->release($reservation);
        $this->client->release($reservation);
        $this->client->release((string) Str::uuid()); // unknown: no error

        $this->assertSame(5, $this->client->getStock($id));
    }

    public function test_unreachable_service_fails_fast_with_inventory_unavailable(): void
    {
        $down = new GrpcInventoryClient('inventory-service:5999', 1000); // nothing listens there

        $started = microtime(true);

        try {
            $down->getStock(1);
            $this->fail('Expected InventoryUnavailableException');
        } catch (InventoryUnavailableException $e) {
            $this->assertSame(503, $e->status);
        }

        $this->assertLessThan(2.5, microtime(true) - $started, 'the deadline stopped the call');
    }
}
