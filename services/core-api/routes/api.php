<?php

use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ProductController;
use Illuminate\Support\Facades\Route;

/*
| Every route in this file is served under /api/v1 (see bootstrap/app.php).
*/

Route::get('/', fn () => response()->json([
    'name' => config('app.name'),
    'version' => 'v1',
    'status' => 'ok',
]));

Route::prefix('auth')->group(function () {
    Route::post('register', [AuthController::class, 'register'])->middleware('throttle:register');
    Route::post('login', [AuthController::class, 'login'])->middleware('throttle:login');

    Route::middleware('auth:api')->group(function () {
        Route::get('me', [AuthController::class, 'me']);
        Route::post('refresh', [AuthController::class, 'refresh']);
        Route::post('logout', [AuthController::class, 'logout']);
    });
});

// Catalogue: anyone can browse.
Route::get('categories', [CategoryController::class, 'index']);
Route::get('products', [ProductController::class, 'index']);
Route::get('products/{product}', [ProductController::class, 'show'])->whereNumber('product');

// Catalogue management: administrators only.
Route::middleware(['auth:api', 'admin'])->group(function () {
    Route::post('categories', [CategoryController::class, 'store']);
    Route::post('products', [ProductController::class, 'store']);
    Route::patch('products/{product}/stock', [ProductController::class, 'updateStock'])->whereNumber('product');
});
