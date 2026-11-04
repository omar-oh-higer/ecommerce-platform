<?php

namespace App\Notifications;

/** To administrators: a customer placed a new order that needs review. */
class NewOrderReceived extends OrderNotification
{
    protected function type(): string
    {
        return 'order.new';
    }

    protected function title(): string
    {
        return 'New order';
    }

    protected function message(): string
    {
        return "New order #{$this->order->id} from {$this->order->user->name}. Total: {$this->order->total}.";
    }

    protected function data(): array
    {
        return [...parent::data(), 'total' => $this->order->total, 'customer_id' => $this->order->user_id];
    }
}
