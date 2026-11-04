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

class AuthController extends Controller
{
    /** POST /api/v1/auth/register — create a customer account. */
    public function register(RegisterRequest $request): JsonResponse
    {
        // Only name/email/password are fillable, so every new account is a customer.
        $user = User::create($request->validated());

        $token = Auth::guard('api')->login($user);

        return $this->tokenResponse($token, $user, 201);
    }

    /** POST /api/v1/auth/login */
    public function login(LoginRequest $request): JsonResponse
    {
        $token = Auth::guard('api')->attempt($request->validated());

        if (! $token) {
            // Same message whether the email exists or not: do not reveal registered emails.
            throw new ApiException('INVALID_CREDENTIALS', 'The email or password is incorrect.', 401);
        }

        return $this->tokenResponse($token, Auth::guard('api')->user());
    }

    /** GET /api/v1/auth/me */
    public function me(): UserResource
    {
        return new UserResource(Auth::guard('api')->user());
    }

    /** POST /api/v1/auth/refresh — swap a valid token for a new one; the old one stops working. */
    public function refresh(): JsonResponse
    {
        $guard = Auth::guard('api');
        $token = $guard->refresh();

        return $this->tokenResponse($token, $guard->setToken($token)->user());
    }

    /** POST /api/v1/auth/logout — the current token is blacklisted. */
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
