<?php

use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\OrderController;
use Illuminate\Support\Facades\Route;

/*
| Logged-in users (customers and admins) — the whole file is wrapped in auth:api (see routes/api.php).
| A customer only reaches their own orders (OrderPolicy) and their own notifications.
| Names: customer.*
*/

Route::post('orders', [OrderController::class, 'store'])
    ->middleware('throttle:orders')
    ->name('orders.store');

Route::get('orders', [OrderController::class, 'index'])->name('orders.index');

Route::get('orders/{order}', [OrderController::class, 'show'])
    ->whereNumber('order')
    ->name('orders.show');

// Notifications (each user only reaches their own)
Route::get('notifications', [NotificationController::class, 'index'])->name('notifications.index');

Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount'])
    ->name('notifications.unread-count');

Route::patch('notifications/read-all', [NotificationController::class, 'markAllAsRead'])
    ->name('notifications.read-all');

Route::patch('notifications/{id}/read', [NotificationController::class, 'markAsRead'])
    ->whereUuid('id')
    ->name('notifications.read');
