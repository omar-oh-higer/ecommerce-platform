<?php

use App\Http\Controllers\Api\V1\OrderController;
use Illuminate\Support\Facades\Route;

/*
| Logged-in users (customers and admins) — the whole file is wrapped in auth:api (see routes/api.php).
| What each user can see is decided by OrderPolicy: a customer only reaches their own orders.
| Names: customer.*
*/

Route::post('orders', [OrderController::class, 'store'])
    ->middleware('throttle:orders')
    ->name('orders.store');

Route::get('orders', [OrderController::class, 'index'])->name('orders.index');

Route::get('orders/{order}', [OrderController::class, 'show'])
    ->whereNumber('order')
    ->name('orders.show');
