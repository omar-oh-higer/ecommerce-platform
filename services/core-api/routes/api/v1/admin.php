<?php

use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\OrderController;
use App\Http\Controllers\Api\V1\ProductController;
use Illuminate\Support\Facades\Route;

/*
| Administrators only — the whole file is wrapped in auth:api + admin (see routes/api.php).
| A customer token gets 403, no token gets 401.
| Names: admin.*
*/

// Catalogue management
Route::post('categories', [CategoryController::class, 'store'])->name('categories.store');

Route::post('products', [ProductController::class, 'store'])->name('products.store');

// Inventory management
Route::patch('products/{product}/stock', [ProductController::class, 'updateStock'])
    ->whereNumber('product')
    ->name('products.stock.update');

// Order management (only administrators change an order's status)
Route::patch('orders/{order}/status', [OrderController::class, 'updateStatus'])
    ->whereNumber('order')
    ->name('orders.status.update');
