<?php

namespace Tests\Feature;

use App\Exceptions\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class ApiFoundationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Throw-away routes used only to trigger each kind of error.
        Route::middleware('api')->prefix('api/v1/_test')->group(function () {
            Route::post('/validate', fn (Request $r) => $r->validate(['email' => 'required|email']));
            Route::get('/auth', fn () => 'ok')->middleware('auth');
            Route::get('/forbidden', fn () => abort(403));
            Route::get('/business', fn () => throw new ApiException('INSUFFICIENT_STOCK', 'Not enough stock.', 409, ['product_id' => 7]));
            Route::get('/crash', fn () => throw new \RuntimeException('database password is 1234'));
        });
    }

    public function test_api_lives_under_v1(): void
    {
        $this->getJson('/api/v1')
            ->assertOk()
            ->assertJson(['version' => 'v1', 'status' => 'ok']);
    }

    public function test_responses_carry_security_headers(): void
    {
        $this->getJson('/api/v1')
            ->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'")
            ->assertHeader('Referrer-Policy', 'no-referrer')
            ->assertHeader('Strict-Transport-Security')
            ->assertHeaderMissing('X-Powered-By');
    }

    public function test_unknown_route_returns_404_in_unified_format(): void
    {
        $this->getJson('/api/v1/does-not-exist')
            ->assertNotFound()
            ->assertJsonPath('error.code', 'NOT_FOUND')
            ->assertJsonStructure(['error' => ['code', 'message', 'details']]);
    }

    public function test_wrong_method_returns_405(): void
    {
        $this->deleteJson('/api/v1')
            ->assertStatus(405)
            ->assertJsonPath('error.code', 'METHOD_NOT_ALLOWED');
    }

    public function test_validation_error_returns_422_with_field_details(): void
    {
        $this->postJson('/api/v1/_test/validate', ['email' => 'not-an-email'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['error' => ['details' => ['email']]]);
    }

    public function test_missing_login_returns_401(): void
    {
        $this->getJson('/api/v1/_test/auth')
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_forbidden_returns_403(): void
    {
        $this->getJson('/api/v1/_test/forbidden')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');
    }

    public function test_business_error_keeps_its_own_code_and_details(): void
    {
        $this->getJson('/api/v1/_test/business')
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'INSUFFICIENT_STOCK')
            ->assertJsonPath('error.details.product_id', 7);
    }

    public function test_unexpected_error_hides_internal_message_in_production(): void
    {
        config(['app.debug' => false]);

        $this->getJson('/api/v1/_test/crash')
            ->assertStatus(500)
            ->assertJsonPath('error.code', 'SERVER_ERROR')
            ->assertJsonMissing(['message' => 'database password is 1234']);
    }
}
