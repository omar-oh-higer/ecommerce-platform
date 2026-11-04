<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Auth;

/**
 * @group Authentication
 *
 * JWT authentication. Send the token as `Authorization: Bearer {token}`.
 */
class AuthController extends Controller
{
    /**
     * Register
     *
     * Creates a **customer** account and logs it in. Sending `role` has no effect.
     * Limited to 10 registrations per minute per IP.
     *
     * @unauthenticated
     *
     * @bodyParam name string required Example: Omar
     * @bodyParam email string required Must be unique. Example: omar@example.com
     * @bodyParam password string required At least 8 characters with letters and numbers. Example: Secret123
     * @bodyParam password_confirmation string required Same as password. Example: Secret123
     *
     * @response 201 scenario="Registered" {"access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...", "token_type": "bearer", "expires_in": 3600, "user": {"id": 3, "name": "Omar", "email": "omar@example.com", "role": "customer", "created_at": "2026-11-04T10:15:00+00:00"}}
     * @response 422 scenario="Email taken / weak password" {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {"email": ["The email has already been taken."], "password": ["The password field must be at least 8 characters."]}}}
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        // Only name/email/password are fillable, so every new account is a customer.
        $user = User::create($request->validated());

        $token = Auth::guard('api')->login($user);

        return $this->tokenResponse($token, $user, 201);
    }

    /**
     * Login
     *
     * Limited to **5 attempts per minute** for the same email and IP (then 429 with `Retry-After`).
     * The error is the same whether the email exists or not.
     *
     * @unauthenticated
     *
     * @bodyParam email string required Example: customer@store.test
     * @bodyParam password string required Example: password
     *
     * @response 200 scenario="Logged in" {"access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...", "token_type": "bearer", "expires_in": 3600, "user": {"id": 2, "name": "Test Customer", "email": "customer@store.test", "role": "customer", "created_at": "2026-11-04T10:00:00+00:00"}}
     * @response 401 scenario="Wrong email or password" {"error": {"code": "INVALID_CREDENTIALS", "message": "The email or password is incorrect.", "details": {}}}
     * @response 429 scenario="Too many attempts" {"error": {"code": "TOO_MANY_REQUESTS", "message": "Too Many Attempts.", "details": {}}}
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $token = Auth::guard('api')->attempt($request->validated());

        if (! $token) {
            // Same message whether the email exists or not: do not reveal registered emails.
            throw new ApiException('INVALID_CREDENTIALS', 'The email or password is incorrect.', 401);
        }

        return $this->tokenResponse($token, Auth::guard('api')->user());
    }

    /**
     * Current user
     *
     * @authenticated
     *
     * @response 200 {"data": {"id": 2, "name": "Test Customer", "email": "customer@store.test", "role": "customer", "created_at": "2026-11-04T10:00:00+00:00"}}
     * @response 401 scenario="No or invalid token" {"error": {"code": "UNAUTHENTICATED", "message": "Authentication is required.", "details": {}}}
     */
    public function me(): UserResource
    {
        return new UserResource(Auth::guard('api')->user());
    }

    /**
     * Refresh token
     *
     * Returns a new token. **The old token stops working immediately.**
     *
     * @authenticated
     *
     * @response 200 {"access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...", "token_type": "bearer", "expires_in": 3600, "user": {"id": 2, "name": "Test Customer", "email": "customer@store.test", "role": "customer", "created_at": "2026-11-04T10:00:00+00:00"}}
     * @response 401 {"error": {"code": "UNAUTHENTICATED", "message": "Authentication is required.", "details": {}}}
     */
    public function refresh(): JsonResponse
    {
        $guard = Auth::guard('api');
        $token = $guard->refresh();

        return $this->tokenResponse($token, $guard->setToken($token)->user());
    }

    /**
     * Logout
     *
     * The current token is blacklisted: using it again returns 401.
     *
     * @authenticated
     *
     * @response 204 scenario="Logged out" {}
     */
    public function logout(): Response
    {
        Auth::guard('api')->logout();

        return response()->noContent();
    }

    private function tokenResponse(string $token, User $user, int $status = 200): JsonResponse
    {
        return response()->json([
            'access_token' => $token,
            'token_type' => 'bearer',
            'expires_in' => Auth::guard('api')->factory()->getTTL() * 60,
            'user' => new UserResource($user),
        ], $status);
    }
}
