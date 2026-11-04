<?php

use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\ProductController;
use Illuminate\Support\Facades\Route;

/*
| Public catalogue — anyone can browse, no token needed.
| Names: catalog.*
*/

Route::get('categories', [CategoryController::class, 'index'])->name('categories.index');

Route::get('products', [ProductController::class, 'index'])->name('products.index');

Route::get('products/{product}', [ProductController::class, 'show'])
    ->whereNumber('product')
    ->name('products.show');
