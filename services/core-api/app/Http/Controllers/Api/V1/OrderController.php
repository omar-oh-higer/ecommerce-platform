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

    /**
     * Place an order
     *
     * One call to the inventory service reserves **every** item (all or nothing).
     * Prices always come from the database: any price sent by the client is ignored.
     * If saving the order fails after the reservation, the stock is given back.
     * Limited to 10 orders per minute per user.
     *
     * @group Orders
     *
     * @authenticated
     *
     * @bodyParam items object[] required From 1 to 20 items, each product only once.
     * @bodyParam items[].product_id integer required An existing product. Example: 6
     * @bodyParam items[].quantity integer required From 1 to 100. Example: 2
     *
     * @response 201 {"data": {"id": 1, "status": "pending", "total": "53.50", "items": [{"product_id": 6, "name": "Cotton T-Shirt", "unit_price": "12.00", "quantity": 2, "line_total": "24.00"}, {"product_id": 2, "name": "USB-C Charger 65W", "unit_price": "29.50", "quantity": 1, "line_total": "29.50"}], "created_at": "2026-11-04T20:24:14+00:00", "updated_at": "2026-11-04T20:24:14+00:00"}}
     * @response 409 scenario="Not enough stock (no order created)" {"error": {"code": "INSUFFICIENT_STOCK", "message": "Some products do not have enough stock.", "details": {"items": [{"product_id": 3, "name": "Smart Watch", "requested": 2, "available": 1}]}}}
     * @response 503 scenario="Inventory service down (no order created)" {"error": {"code": "INVENTORY_UNAVAILABLE", "message": "The inventory service is not available right now. Please try again later.", "details": {}}}
     * @response 422 {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {"items.0.quantity": ["The items.0.quantity field must be at least 1."]}}}
     */
    public function store(PlaceOrderRequest $request): JsonResponse
    {
        $order = $this->orders->place($request->user(), $request->items());

        return (new OrderResource($order->load('items')))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * List orders
     *
     * A customer gets **only their own** orders. An admin gets every order, plus `customer` and `next_statuses`.
     *
     * @group Orders
     *
     * @authenticated
     *
     * @queryParam status string One of pending, confirmed, shipped, delivered, cancelled. Example: pending
     * @queryParam per_page integer Between 1 and 50 (default 15). Example: 10
     * @queryParam page integer Example: 1
     *
     * @response 200 {"data": [{"id": 1, "status": "pending", "total": "53.50", "items_count": 2, "created_at": "2026-11-04T20:24:14+00:00", "updated_at": "2026-11-04T20:24:14+00:00"}], "links": {"first": "http://localhost:8000/api/v1/orders?page=1", "last": "http://localhost:8000/api/v1/orders?page=1", "prev": null, "next": null}, "meta": {"current_page": 1, "from": 1, "last_page": 1, "path": "http://localhost:8000/api/v1/orders", "per_page": 15, "to": 1, "total": 1}}
     */
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

    /**
     * Order details
     *
     * Only the owner or an admin. **Another customer's order returns 403.**
     *
     * @group Orders
     *
     * @authenticated
     *
     * @urlParam order integer required The order id. Example: 1
     *
     * @response 200 {"data": {"id": 1, "status": "pending", "total": "53.50", "items": [{"product_id": 6, "name": "Cotton T-Shirt", "unit_price": "12.00", "quantity": 2, "line_total": "24.00"}, {"product_id": 2, "name": "USB-C Charger 65W", "unit_price": "29.50", "quantity": 1, "line_total": "29.50"}], "created_at": "2026-11-04T20:24:14+00:00", "updated_at": "2026-11-04T20:24:14+00:00"}}
     * @response 403 scenario="Someone else's order" {"error": {"code": "FORBIDDEN", "message": "You are not allowed to view this order.", "details": {}}}
     * @response 404 {"error": {"code": "NOT_FOUND", "message": "Order not found.", "details": {}}}
     */
    public function show(Order $order): OrderResource
    {
        Gate::authorize('view', $order);

        return new OrderResource($order->load(['items', 'user']));
    }

    /**
     * Change order status
     *
     * **Admin only** (a customer gets 403, even on their own order).
     * Allowed: pending → confirmed | cancelled, confirmed → shipped | cancelled, shipped → delivered.
     * Cancelling gives the stock back to the inventory service. The customer is notified.
     * Cancelling **always succeeds**, even when the inventory service is down: the response then has
     * `stock_return: "pending"` and a background job returns the stock as soon as the service is back
     * (`stock_return` becomes `"done"`).
     *
     * @group Administration
     *
     * @authenticated
     *
     * @urlParam order integer required The order id. Example: 1
     *
     * @bodyParam status string required One of confirmed, shipped, delivered, cancelled. Example: confirmed
     *
     * @response 200 scenario="Confirmed" {"data": {"id": 1, "status": "confirmed", "total": "53.50", "items": [{"product_id": 6, "name": "Cotton T-Shirt", "unit_price": "12.00", "quantity": 2, "line_total": "24.00"}], "customer": {"id": 2, "name": "Test Customer", "email": "customer@store.test"}, "next_statuses": ["shipped", "cancelled"], "created_at": "2026-11-04T20:24:14+00:00", "updated_at": "2026-11-04T20:30:00+00:00"}}
     * @response 200 scenario="Cancelled while the inventory service is down" {"data": {"id": 13, "status": "cancelled", "total": "36.00", "items": [{"product_id": 6, "name": "Cotton T-Shirt", "unit_price": "12.00", "quantity": 3, "line_total": "36.00"}], "customer": {"id": 11, "name": "Test Customer", "email": "customer@store.test"}, "stock_return": "pending", "next_statuses": [], "created_at": "2026-11-05T10:27:12+00:00", "updated_at": "2026-11-05T10:27:15+00:00"}}
     * @response 403 scenario="Customer token" {"error": {"code": "FORBIDDEN", "message": "This action is reserved for administrators.", "details": {}}}
     * @response 409 scenario="Transition not allowed" {"error": {"code": "INVALID_STATUS_TRANSITION", "message": "An order cannot move from 'delivered' to 'cancelled'.", "details": {"current": "delivered", "allowed": []}}}
     */
    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): OrderResource
    {
        Gate::authorize('updateStatus', $order);

        $order = $this->orders->changeStatus($order, $request->status());

        return new OrderResource($order->load(['items', 'user']));
    }
}
