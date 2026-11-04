<?php

namespace App\Listeners;

use App\Enums\Role;
use App\Events\OrderPlaced;
use App\Events\OrderStatusChanged;
use App\Models\User;
use App\Notifications\NewOrderReceived;
use App\Notifications\OrderPlacedNotification;
use App\Notifications\OrderStatusChangedNotification;
use Illuminate\Support\Facades\Notification;

/**
 * Decides who is told about what. Discovered automatically by Laravel (handle* methods).
 */
class SendOrderNotifications
{
    /** New order: confirm to the customer, alert the administrators. */
    public function handleOrderPlaced(OrderPlaced $event): void
    {
        $order = $event->order;

        $order->user->notify(new OrderPlacedNotification($order));

        Notification::send(
            User::where('role', Role::Admin)->get(),
            new NewOrderReceived($order),
        );
    }

    /** Status changed: tell the customer who owns the order. */
    public function handleOrderStatusChanged(OrderStatusChanged $event): void
    {
        $event->order->user->notify(new OrderStatusChangedNotification($event->order, $event->from));
    }
}
