<?php

namespace Tests\Feature;

use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Notifications\NewOrderReceived;
use App\Notifications\OrderPlacedNotification;
use App\Notifications\OrderStatusChangedNotification;
use App\Services\Inventory\InventoryClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use RuntimeException;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    private function tokenFor(User $user): string
    {
        $this->app['auth']->forgetGuards();
        $this->app->forgetInstance('tymon.jwt');

        return auth('api')->login($user);
    }

    private function placeOrderAs(User $customer): int
    {
        $product = Product::factory()->create(['price' => '20.00']);
        app(InventoryClient::class)->setStock($product->id, 10);

        return $this->withToken($this->tokenFor($customer))
            ->postJson('/api/v1/orders', ['items' => [['product_id' => $product->id, 'quantity' => 2]]])
            ->assertCreated()
            ->json('data.id');
    }

    // ---- Who gets notified -----------------------------------------------------

    public function test_placing_an_order_notifies_the_customer_and_every_admin(): void
    {
        Notification::fake();
        $customer = User::factory()->create();
        $admins = User::factory()->admin()->count(2)->create();

        $orderId = $this->placeOrderAs($customer);

        Notification::assertSentTo($customer, OrderPlacedNotification::class, fn ($n) => $n->order->id === $orderId);
        Notification::assertSentTo($admins, NewOrderReceived::class);
        Notification::assertNotSentTo($customer, NewOrderReceived::class);
    }

    public function test_status_change_notifies_the_order_owner_only(): void
    {
        Notification::fake();
        $owner = User::factory()->create();
        $someoneElse = User::factory()->create();
        $order = Order::factory()->for($owner)->create();

        $this->withToken($this->tokenFor(User::factory()->admin()->create()))
            ->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'confirmed'])
            ->assertOk();

        Notification::assertSentTo($owner, OrderStatusChangedNotification::class,
            fn ($n) => $n->status->value === 'confirmed' && $n->from->value === 'pending');
        Notification::assertNotSentTo($someoneElse, OrderStatusChangedNotification::class);
    }

    public function test_no_notification_when_the_order_is_not_created(): void
    {
        Notification::fake();
        Order::creating(fn () => throw new RuntimeException('database write failed'));

        $product = Product::factory()->create();
        app(InventoryClient::class)->setStock($product->id, 10);

        $this->withToken($this->tokenFor(User::factory()->create()))
            ->postJson('/api/v1/orders', ['items' => [['product_id' => $product->id, 'quantity' => 1]]])
            ->assertStatus(500);

        Notification::assertNothingSent();
    }

    public function test_invalid_status_change_sends_nothing(): void
    {
        Notification::fake();
        $order = Order::factory()->create(['status' => 'delivered']);

        $this->withToken($this->tokenFor(User::factory()->admin()->create()))
            ->patchJson("/api/v1/orders/{$order->id}/status", ['status' => 'cancelled'])
            ->assertStatus(409);

        Notification::assertNothingSent();
    }

    // ---- Reading notifications through the API -----------------------------------

    public function test_customer_reads_their_notifications_end_to_end(): void
    {
        $customer = User::factory()->create();
        $orderId = $this->placeOrderAs($customer);
        $this->travel(1)->seconds(); // notifications are ordered by time

        $this->withToken($this->tokenFor(User::factory()->admin()->create()))
            ->patchJson("/api/v1/orders/{$orderId}/status", ['status' => 'shipped'])
            ->assertStatus(409); // pending cannot jump to shipped
        $this->withToken($this->tokenFor(User::factory()->admin()->create()))
            ->patchJson("/api/v1/orders/{$orderId}/status", ['status' => 'confirmed'])
            ->assertOk();

        $this->withToken($this->tokenFor($customer))->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.unread_count', 2)
            // newest first
            ->assertJsonPath('data.0.type', 'order.status_changed')
            ->assertJsonPath('data.0.payload.order_id', $orderId)
            ->assertJsonPath('data.0.payload.status', 'confirmed')
            ->assertJsonPath('data.0.payload.previous_status', 'pending')
            ->assertJsonPath('data.0.read', false)
            ->assertJsonPath('data.1.type', 'order.placed')
            ->assertJsonPath('data.1.payload.total', '40.00')
            ->assertJsonStructure(['data' => [['id', 'type', 'title', 'message', 'payload', 'read', 'read_at', 'created_at']]]);
    }

    public function test_unread_count_and_mark_as_read(): void
    {
        $customer = User::factory()->create();
        $this->placeOrderAs($customer);
        $this->placeOrderAs($customer);
        $token = $this->tokenFor($customer);

        $this->withToken($token)->getJson('/api/v1/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('data.unread_count', 2);

        $id = $customer->notifications()->first()->id;
        $this->withToken($token)->patchJson("/api/v1/notifications/{$id}/read")
            ->assertOk()
            ->assertJsonPath('data.read', true);

        $this->withToken($token)->getJson('/api/v1/notifications?unread=1')
            ->assertOk()
            ->assertJsonCount(1, 'data');

        $this->withToken($token)->patchJson('/api/v1/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('data.marked_as_read', 1);

        $this->withToken($token)->getJson('/api/v1/notifications/unread-count')
            ->assertJsonPath('data.unread_count', 0);
    }

    public function test_user_cannot_read_or_mark_someone_elses_notification(): void
    {
        $victim = User::factory()->create();
        $this->placeOrderAs($victim);
        $notificationId = $victim->notifications()->first()->id;

        $attacker = $this->tokenFor(User::factory()->create());

        $this->withToken($attacker)->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($attacker)->patchJson("/api/v1/notifications/{$notificationId}/read")
            ->assertNotFound();

        $this->assertNull($victim->notifications()->first()->read_at);
    }

    public function test_guest_cannot_read_notifications(): void
    {
        $this->getJson('/api/v1/notifications')->assertUnauthorized();
    }
}
