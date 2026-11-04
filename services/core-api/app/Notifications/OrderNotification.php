<?php

namespace App\Notifications;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Notifications\Notification;

/**
 * Base for every order notification.
 *
 * - Stored in the "notifications" table (database channel) and read through the API.
 * - Sent from the queue so the HTTP request is not slowed down.
 * - Every notification has the same shape: type, title, message, data.
 *   Flutter can show title/message as they are, or translate using "type".
 */
abstract class OrderNotification extends Notification implements ShouldQueue
{
    use Queueable;

    /** The status at the moment of the event (the order may change again before the queue sends this). */
    public readonly OrderStatus $status;

    public function __construct(public readonly Order $order)
    {
        $this->status = $order->status;
        $this->afterCommit();
    }

    /** Stable machine-readable type, e.g. "order.placed". */
    abstract protected function type(): string;

    abstract protected function title(): string;

    abstract protected function message(): string;

    /** @return array<string, mixed> */
    protected function data(): array
    {
        return [
            'order_id' => $this->order->id,
            'status' => $this->status->value,
        ];
    }

    /** @return string[] */
    public function via(object $notifiable): array
    {
        return ['database'];
    }

    public function databaseType(object $notifiable): string
    {
        return $this->type();
    }

    /** @return array<string, mixed> */
    public function toArray(object $notifiable): array
    {
        return [
            'title' => $this->title(),
            'message' => $this->message(),
            'data' => $this->data(),
        ];
    }
}
