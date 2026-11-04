<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Jobs\ReleaseReservation;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\Inventory\FakeInventoryClient;
use App\Services\Inventory\InventoryClient;
use App\Services\Inventory\InventoryUnavailableException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use RuntimeException;
use Tests\TestCase;

class OrderTest extends TestCase
{
    use RefreshDatabase;

    private InventoryClient $inventory;

    protected function setUp(): void
    {
        parent::setUp();

        $this->inventory = app(InventoryClient::class);
    }

    private function productWithStock(int $stock, string $price = '10.00'): Product
    {
        $product = Product::factory()->create(['price' => $price]);
        $this->inventory->setStock($product->id, $stock);

        return $product;
    }

    private function tokenFor(User $user): string
    {
        $this->app['auth']->forgetGuards();
        $this->app->forgetInstance('tymon.jwt');

        return auth('api')->login($user);
    }

    private function placeOrder(User $user, array $items)
    {
        return $this->withToken($this->tokenFor($user))->postJson('/api/v1/orders', ['items' => $items]);
    }

    // ---- Place an order ------------------------------------------------------

    public function test_customer_places_an_order_and_stock_is_reserved(): void
    {
        $mouse = $this->productWithStock(10, '25.50');
        $cable = $this->productWithStock(5, '4.25');

        $this->placeOrder(User::factory()->create(), [
            ['product_id' => $mouse->id, 'quantity' => 2],
            ['product_id' => $cable->id, 'quantity' => 3],
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.total', '63.75') // 2 × 25.50 + 3 × 4.25
            ->assertJsonCount(2, 'data.items')
            ->assertJsonPath('data.items.0.line_total', '51.00');

        $this->assertSame(8, $this->inventory->getStock($mouse->id));
        $this->assertSame(2, $this->inventory->getStock($cable->id));
    }

    public function test_prices_sent_by_the_client_are_ignored(): void
    {
        $product = $this->productWithStock(5, '100.00');

        $this->placeOrder(User::factory()->create(), [
            ['product_id' => $product->id, 'quantity' => 1, 'price' => '0.01', 'unit_price' => '0.01'],
        ])
            ->assertCreated()
            ->assertJsonPath('data.total', '100.00');
    }

    public function test_order_is_rejected_when_stock_is_not_enough(): void
    {
        $plenty = $this->productWithStock(10);
        $scarce = $this->productWithStock(1);

        $this->placeOrder(User::factory()->create(), [
            ['product_id' => $plenty->id, 'quantity' => 2],
            ['product_id' => $scarce->id, 'quantity' => 3],
        ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'INSUFFICIENT_STOCK')
            ->assertJsonPath('error.details.items.0.product_id', $scarce->id)
            ->assertJsonPath('error.details.items.0.requested', 3)
            ->assertJsonPath('error.details.items.0.available', 1);

        // All or nothing: no order, and even the available product was not touched.
        $this->assertDatabaseCount('orders', 0);
        $this->assertSame(10, $this->inventory->getStock($plenty->id));
        $this->assertSame(1, $this->inventory->getStock($scarce->id));
    }

    public function test_order_is_rejected_with_503_when_inventory_is_down(): void
    {
        $product = Product::factory()->create();
        $this->app->instance(InventoryClient::class, new FakeInventoryClient(app('cache')->store(), down: true));

        $this->placeOrder(User::factory()->create(), [['product_id' => $product->id, 'quantity' => 1]])
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'INVENTORY_UNAVAILABLE');

        $this->assertDatabaseCount('orders', 0);
    }

    public function test_stock_is_given_back_when_saving_the_order_fails(): void
    {
        $product = $this->productWithStock(5);
        Order::creating(fn () => throw new RuntimeException('database write failed'));

        $this->placeOrder(User::factory()->create(), [['product_id' => $product->id, 'quantity' => 2]])
            ->assertStatus(500);

        $this->assertDatabaseCount('orders', 0);
        $this->assertSame(5, $this->inventory->getStock($product->id), 'reserved stock was released');
    }

    public function test_release_is_retried_in_the_background_when_inventory_cannot_be_reached(): void
    {
        Queue::fake();
        $product = $this->productWithStock(5);
        // Inventory accepts the reservation, then becomes unreachable when we try to release it.
        $this->app->instance(InventoryClient::class, new class(app('cache')->store()) extends FakeInventoryClient
        {
            public function release(string $reservationId): void
            {
                throw new InventoryUnavailableException;
            }
        });
        Order::creating(fn () => throw new RuntimeException('database write failed'));

        $this->placeOrder(User::factory()->create(), [['product_id' => $product->id, 'quantity' => 2]])
            ->assertStatus(500);

        Queue::assertPushed(ReleaseReservation::class);
    }

    public function test_order_input_is_validated(): void
    {
        $product = $this->productWithStock(5);

        $this->placeOrder(User::factory()->create(), [
            ['product_id' => $product->id, 'quantity' => 0],
            ['product_id' => $product->id, 'quantity' => 1],
            ['product_id' => 99999, 'quantity' => 1],
        ])
            ->assertUnprocessable()
            ->assertJsonStructure(['error' => ['details' => ['items.0.quantity', 'items.0.product_id', 'items.2.product_id']]]);

        $this->placeOrder(User::factory()->create(), [])->assertUnprocessable();
    }

    public function test_guest_cannot_place_an_order(): void
    {
        $this->postJson('/api/v1/orders', ['items' => []])->assertUnauthorized();
    }

    // ---- See orders: each customer only sees their own -----------------------

    public function test_customer_lists_only_their_own_orders(): void
    {
        $me = User::factory()->create();
        Order::factory()->count(2)->for($me)->create();
        Order::factory()->count(3)->create(); // other customers

        $this->withToken($this->tokenFor($me))->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 2)
            ->assertJsonMissingPath('data.0.customer');
    }

    public function test_customer_can_view_their_own_order(): void
    {
        $me = User::factory()->create();
        $order = Order::factory()->for($me)->create();

        $this->withToken($this->tokenFor($me))->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.id', $order->id);
    }

    /** Required proof (slide 8): accessing someone else's order is refused. */
    public function test_customer_cannot_view_another_customers_order(): void
    {
        $someoneElsesOrder = Order::factory()->create();

        $this->withToken($this->tokenFor(User::factory()->create()))
            ->getJson("/api/v1/orders/{$someoneElsesOrder->id}")
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN')
            ->assertJsonPath('error.message', 'You are not allowed to view this order.');
    }

    public function test_admin_sees_every_order_with_customer_details(): void
    {
        Order::factory()->count(3)->create();
        $order = Order::factory()->create();

        $admin = User::factory()->admin()->create();

        $this->withToken($this->tokenFor($admin))->getJson('/api/v1/orders')
            ->assertOk()
            ->assertJsonPath('meta.total', 4)
            ->assertJsonStructure(['data' => [['customer' => ['id', 'name', 'email'], 'next_statuses']]]);

        $this->withToken($this->tokenFor($admin))->getJson("/api/v1/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.customer.id', $order->user_id)
            ->assertJsonPath('data.next_statuses', ['confirmed', 'cancelled']);
    }

    public function test_orders_can_be_filtered_by_status(): void
    {
        $me = User::factory()->create();
        Order::factory()->for($me)->status(OrderStatus::Delivered)->create();
        Order::factory()->for($me)->create();

        $this->withToken($this->tokenFor($me))->getJson('/api/v1/orders?status=delivered')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'delivered');
    }

    // ---- Change status: administrators only ----------------------------------

    /** Required proof (slide 8): an operation outside your role is refused. */
    public function test_customer_cannot_change_order_status_even_on_their_own_order(): void
    {
        $me = User::factory()->create();
        $order = Order::factory()->for($me)->create();

        $this->withToken($this->tokenFor($me))
            ->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'delivered'])
            ->assertForbidden();

        $this->assertSame(OrderStatus::Pending, $order->fresh()->status);
    }

    public function test_admin_moves_an_order_through_its_life_cycle(): void
    {
        $order = Order::factory()->create();
        $token = $this->tokenFor(User::factory()->admin()->create());

        foreach (['confirmed', 'shipped', 'delivered'] as $status) {
            $this->withToken($token)
                ->patchJson("/api/v1/orders/{$order->id}/status", ['status' => $status])
                ->assertOk()
                ->assertJsonPath('data.status', $status);
        }
    }

    public function test_invalid_status_transition_is_refused(): void
    {
        $order = Order::factory()->status(OrderStatus::Delivered)->create();

        $this->withToken($this->tokenFor(User::factory()->admin()->create()))
            ->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled'])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'INVALID_STATUS_TRANSITION')
            ->assertJsonPath('error.details.current', 'delivered');
    }

    public function test_cancelling_gives_the_stock_back_only_once(): void
    {
        $product = $this->productWithStock(5);
        $customer = User::factory()->create();
        $orderId = $this->placeOrder($customer, [['product_id' => $product->id, 'quantity' => 3]])->json('data.id');
        $this->assertSame(2, $this->inventory->getStock($product->id));

        $admin = $this->tokenFor(User::factory()->admin()->create());

        $this->withToken($admin)
            ->patchJson("/api/v1/orders/{$orderId}/status", ['status' => 'cancelled'])
            ->assertOk()
            ->assertJsonPath('data.status', 'cancelled');
        $this->assertSame(5, $this->inventory->getStock($product->id));

        // A second cancel is refused by the life cycle, and the stock is not returned twice.
        $this->withToken($admin)
            ->patchJson("/api/v1/orders/{$orderId}/status", ['status' => 'cancelled'])
            ->assertStatus(409);
        $this->assertSame(5, $this->inventory->getStock($product->id));
    }
}
