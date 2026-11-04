<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API routes — served under /api/v1 (see bootstrap/app.php)
|--------------------------------------------------------------------------
|
| Each group lives in its own file under routes/api/v1:
|
|   auth.php     /auth/*           register, login, me, refresh, logout
|   catalog.php  public browsing   categories, products
|   customer.php logged-in users   place and follow orders
|   admin.php    administrators    catalogue, stock and order status management
|
| Every route has a name (e.g. "auth.login", "admin.products.store"),
| so `php artisan route:list` shows the whole API grouped and readable.
*/

Route::get('/', fn () => response()->json([
    'name' => config('app.name'),
    'version' => 'v1',
    'status' => 'ok',
]))->name('status');

Route::prefix('auth')
    ->name('auth.')
    ->group(base_path('routes/api/v1/auth.php'));

Route::name('catalog.')
    ->group(base_path('routes/api/v1/catalog.php'));

Route::middleware('auth:api')
    ->name('customer.')
    ->group(base_path('routes/api/v1/customer.php'));

Route::middleware(['auth:api', 'admin'])
    ->name('admin.')
    ->group(base_path('routes/api/v1/admin.php'));
