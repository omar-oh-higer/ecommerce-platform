<?php

namespace App\Providers;

use App\Services\Inventory\FakeInventoryClient;
use App\Services\Inventory\InventoryClient;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;
use InvalidArgumentException;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Which inventory implementation the app uses (config/services.php → inventory.driver).
        $this->app->singleton(InventoryClient::class, function ($app) {
            return match (config('services.inventory.driver')) {
                'fake' => new FakeInventoryClient($app['cache']->store(), (bool) config('services.inventory.fake_down')),
                default => throw new InvalidArgumentException('Unknown inventory driver: '.config('services.inventory.driver')),
            };
        });
    }

    public function boot(): void
    {
        $this->configureRateLimiting();
    }

    private function configureRateLimiting(): void
    {
        // General limit for the whole API: per user when logged in, otherwise per IP.
        RateLimiter::for('api', fn (Request $request) => Limit::perMinute(120)
            ->by($request->user()?->id ?: $request->ip()));

        // Login: 5 attempts per minute for the same email from the same IP (brute-force protection).
        RateLimiter::for('login', fn (Request $request) => Limit::perMinute(5)
            ->by(Str::lower((string) $request->input('email')).'|'.$request->ip()));

        // Placing orders: 10 per minute per user (each one hits the inventory service).
        RateLimiter::for('orders', fn (Request $request) => Limit::perMinute(10)
            ->by($request->user()?->id ?: $request->ip()));

        // Registration: 10 accounts per minute per IP.
        RateLimiter::for('register', fn (Request $request) => Limit::perMinute(10)
            ->by($request->ip()));
    }
}
