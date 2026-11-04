<?php

use App\Http\Controllers\Api\V1\AuthController;
use Illuminate\Support\Facades\Route;

/*
| Authentication — /api/v1/auth/*
| Names: auth.*
*/

// Public, rate limited (see AppServiceProvider).
Route::post('register', [AuthController::class, 'register'])
    ->middleware('throttle:register')
    ->name('register');

Route::post('login', [AuthController::class, 'login'])
    ->middleware('throttle:login')
    ->name('login');

// Requires a valid JWT.
Route::middleware('auth:api')->group(function () {
    Route::get('me', [AuthController::class, 'me'])->name('me');
    Route::post('refresh', [AuthController::class, 'refresh'])->name('refresh');
    Route::post('logout', [AuthController::class, 'logout'])->name('logout');
});
