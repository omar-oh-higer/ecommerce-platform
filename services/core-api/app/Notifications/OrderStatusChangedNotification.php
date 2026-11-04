<?php

namespace App\Notifications;

use App\Enums\OrderStatus;
use App\Models\Order;

/** To the customer: an administrator changed the status of their order. */
class OrderStatusChangedNotification extends OrderNotification
{
    public function __construct(Order $order, public readonly OrderStatus $from)
    {
        parent::__construct($order);
    }

    protected function type(): string
    {
        return 'order.status_changed';
    }

    protected function title(): string
    {
        return 'Order '.$this->status->value;
    }

    protected function message(): string
    {
        return match ($this->status) {
            OrderStatus::Confirmed => "Your order #{$this->order->id} has been confirmed.",
            OrderStatus::Shipped => "Your order #{$this->order->id} is on its way.",
            OrderStatus::Delivered => "Your order #{$this->order->id} has been delivered.",
            OrderStatus::Cancelled => "Your order #{$this->order->id} has been cancelled.",
            OrderStatus::Pending => "Your order #{$this->order->id} is pending.",
        };
    }

    protected function data(): array
    {
        return [...parent::data(), 'previous_status' => $this->from->value];
    }
}
