<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Orders\ListOrdersRequest;
use App\Http\Requests\Orders\PlaceOrderRequest;
use App\Http\Requests\Orders\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;

class OrderController extends Controller
{
    public function __construct(private readonly OrderService $orders) {}

    /** POST /api/v1/orders — place an order for the logged-in user. */
    public function store(PlaceOrderRequest $request): JsonResponse
    {
        $order = $this->orders->place($request->user(), $request->items());

        return (new OrderResource($order->load('items')))
            ->response()
            ->setStatusCode(201);
    }

    /** GET /api/v1/orders — customers get their own orders, admins get every order. */
    public function index(ListOrdersRequest $request): AnonymousResourceCollection
    {
        $orders = Order::query()
            ->visibleTo($request->user())
            ->when($request->validated('status'), fn ($q, $status) => $q->where('status', $status))
            ->with('user')
            ->withCount('items')
            ->latest('id')
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        return OrderResource::collection($orders);
    }

    /** GET /api/v1/orders/{order} — 403 when the order belongs to someone else. */
    public function show(Order $order): OrderResource
    {
        Gate::authorize('view', $order);

        return new OrderResource($order->load(['items', 'user']));
    }

    /** PATCH /api/v1/orders/{order}/status (admin) */
    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): OrderResource
    {
        Gate::authorize('updateStatus', $order);

        $order = $this->orders->changeStatus($order, $request->status());

        return new OrderResource($order->load(['items', 'user']));
    }
}
