<?php

namespace App\Notifications;

/** To the customer: their order was received. */
class OrderPlacedNotification extends OrderNotification
{
    protected function type(): string
    {
        return 'order.placed';
    }

    protected function title(): string
    {
        return 'Order received';
    }

    protected function message(): string
    {
        return "Your order #{$this->order->id} has been received. Total: {$this->order->total}.";
    }

    protected function data(): array
    {
        return [...parent::data(), 'total' => $this->order->total];
    }
}
