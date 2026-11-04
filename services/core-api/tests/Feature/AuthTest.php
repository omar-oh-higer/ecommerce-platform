<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD = 'Secret123';

    private function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Omar',
            'email' => 'omar@example.com',
            'password' => self::PASSWORD,
            'password_confirmation' => self::PASSWORD,
        ], $overrides);
    }

    /**
     * Inside one test every call shares the same PHP process, so the JWT library
     * remembers the last token. Reset it so the next call behaves like a new HTTP request.
     */
    private function freshRequest(): void
    {
        $this->app['auth']->forgetGuards();
        $this->app->forgetInstance('tymon.jwt');
    }

    private function loginAs(User $user): string
    {
        return $this->postJson('/api/v1/auth/login', [
            'email' => $user->email,
            'password' => 'password', // factory default
        ])->json('access_token');
    }

    // ---- Register ---------------------------------------------------------

    public function test_customer_can_register_and_receives_a_token(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registerPayload())
            ->assertCreated()
            ->assertJsonStructure(['access_token', 'token_type', 'expires_in', 'user' => ['id', 'name', 'email', 'role']])
            ->assertJsonPath('user.role', 'customer')
            ->assertJsonMissingPath('user.password');
    }

    public function test_register_cannot_make_itself_admin(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registerPayload(['role' => 'admin']))
            ->assertCreated()
            ->assertJsonPath('user.role', 'customer');

        $this->assertDatabaseHas('users', ['email' => 'omar@example.com', 'role' => 'customer']);
    }

    public function test_register_rejects_duplicate_email_and_weak_password(): void
    {
        User::factory()->create(['email' => 'omar@example.com']);

        $this->postJson('/api/v1/auth/register', $this->registerPayload(['password' => '123', 'password_confirmation' => '123']))
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['error' => ['details' => ['email', 'password']]]);
    }

    public function test_password_is_stored_hashed(): void
    {
        $this->postJson('/api/v1/auth/register', $this->registerPayload())->assertCreated();

        $this->assertNotSame(self::PASSWORD, User::first()->password);
    }

    // ---- Login ------------------------------------------------------------

    public function test_user_can_login_with_correct_credentials(): void
    {
        $user = User::factory()->create();

        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password'])
            ->assertOk()
            ->assertJsonPath('token_type', 'bearer')
            ->assertJsonPath('user.id', $user->id);
    }

    public function test_wrong_password_returns_401_without_revealing_which_part_is_wrong(): void
    {
        $user = User::factory()->create();

        $wrongPassword = $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'nope']);
        $unknownEmail = $this->postJson('/api/v1/auth/login', ['email' => 'ghost@example.com', 'password' => 'nope']);

        $wrongPassword->assertUnauthorized()->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
        $unknownEmail->assertUnauthorized()->assertJsonPath('error.code', 'INVALID_CREDENTIALS');
        $this->assertSame($wrongPassword->json('error.message'), $unknownEmail->json('error.message'));
    }

    public function test_login_is_rate_limited_after_five_attempts(): void
    {
        $user = User::factory()->create();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'wrong'])
                ->assertUnauthorized();
        }

        // Even the correct password is refused now.
        $this->postJson('/api/v1/auth/login', ['email' => $user->email, 'password' => 'password'])
            ->assertStatus(429)
            ->assertJsonPath('error.code', 'TOO_MANY_REQUESTS')
            ->assertHeader('Retry-After');
    }

    // ---- Token usage ------------------------------------------------------

    public function test_me_returns_the_logged_in_user(): void
    {
        $user = User::factory()->create();
        $token = $this->loginAs($user);

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.email', $user->email);
    }

    public function test_me_without_token_returns_401(): void
    {
        $this->getJson('/api/v1/auth/me')
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'UNAUTHENTICATED');
    }

    public function test_forged_token_is_rejected(): void
    {
        $this->withToken('eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.forged-signature')
            ->getJson('/api/v1/auth/me')
            ->assertUnauthorized();
    }

    public function test_logout_invalidates_the_token(): void
    {
        $token = $this->loginAs(User::factory()->create());

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->freshRequest();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertUnauthorized();
    }

    public function test_refresh_returns_a_new_token_and_kills_the_old_one(): void
    {
        $oldToken = $this->loginAs(User::factory()->create());

        $newToken = $this->withToken($oldToken)->postJson('/api/v1/auth/refresh')
            ->assertOk()
            ->json('access_token');

        $this->assertNotSame($oldToken, $newToken);

        $this->freshRequest();
        $this->withToken($oldToken)->getJson('/api/v1/auth/me')->assertUnauthorized();

        $this->freshRequest();
        $this->withToken($newToken)->getJson('/api/v1/auth/me')->assertOk();
    }

    // ---- Roles ------------------------------------------------------------

    public function test_admin_only_route_rejects_customers_and_accepts_admins(): void
    {
        Route::middleware(['api', 'auth:api', 'admin'])->get('/api/v1/_test/admin-only', fn () => ['ok' => true]);

        $customerToken = $this->loginAs(User::factory()->create());
        $this->withToken($customerToken)->getJson('/api/v1/_test/admin-only')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'FORBIDDEN');

        $this->freshRequest();
        $adminToken = $this->loginAs(User::factory()->admin()->create());
        $this->withToken($adminToken)->getJson('/api/v1/_test/admin-only')
            ->assertOk();
    }
}
