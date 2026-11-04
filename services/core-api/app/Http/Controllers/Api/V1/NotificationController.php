<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Notifications\ListNotificationsRequest;
use App\Http\Resources\NotificationResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Every query starts from $request->user()->notifications(),
 * so a user can never read or change someone else's notifications (404).
 */
class NotificationController extends Controller
{
    /**
     * List notifications
     *
     * Newest first. `meta.unread_count` holds the number of unread notifications.
     * Types: `order.placed` (customer), `order.new` (admins), `order.status_changed` (order owner).
     *
     * @group Notifications
     *
     * @authenticated
     *
     * @queryParam unread boolean Only unread notifications. Example: 1
     * @queryParam per_page integer Between 1 and 50 (default 15). Example: 20
     * @queryParam page integer Example: 1
     *
     * @response 200 {"data": [{"id": "cc7922f8-ea17-4c01-be34-d5838f904b94", "type": "order.status_changed", "title": "Order confirmed", "message": "Your order #4 has been confirmed.", "payload": {"order_id": 4, "status": "confirmed", "previous_status": "pending"}, "read": false, "read_at": null, "created_at": "2026-11-04T20:40:53+00:00"}, {"id": "87701cfe-f4f0-4504-a9fe-fd3cd1398230", "type": "order.placed", "title": "Order received", "message": "Your order #4 has been received. Total: 35.00.", "payload": {"order_id": 4, "status": "pending", "total": "35.00"}, "read": false, "read_at": null, "created_at": "2026-11-04T20:40:47+00:00"}], "links": {"first": "http://localhost:8000/api/v1/notifications?page=1", "last": "http://localhost:8000/api/v1/notifications?page=1", "prev": null, "next": null}, "meta": {"current_page": 1, "from": 1, "last_page": 1, "path": "http://localhost:8000/api/v1/notifications", "per_page": 15, "to": 2, "total": 2, "unread_count": 2}}
     */
    public function index(ListNotificationsRequest $request): AnonymousResourceCollection
    {
        $notifications = $request->user()->notifications()
            ->when($request->boolean('unread'), fn ($q) => $q->whereNull('read_at'))
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        return NotificationResource::collection($notifications)
            ->additional(['meta' => ['unread_count' => $request->user()->unreadNotifications()->count()]]);
    }

    /**
     * Unread count
     *
     * A cheap call for the badge on the bell icon.
     *
     * @group Notifications
     *
     * @authenticated
     *
     * @response 200 {"data": {"unread_count": 2}}
     */
    public function unreadCount(Request $request): JsonResponse
    {
        return response()->json([
            'data' => ['unread_count' => $request->user()->unreadNotifications()->count()],
        ]);
    }

    /**
     * Mark as read
     *
     * Someone else's notification returns 404.
     *
     * @group Notifications
     *
     * @authenticated
     *
     * @urlParam id string required The notification id (UUID). Example: cc7922f8-ea17-4c01-be34-d5838f904b94
     *
     * @response 200 {"data": {"id": "cc7922f8-ea17-4c01-be34-d5838f904b94", "type": "order.status_changed", "title": "Order confirmed", "message": "Your order #4 has been confirmed.", "payload": {"order_id": 4, "status": "confirmed", "previous_status": "pending"}, "read": true, "read_at": "2026-11-04T20:45:00+00:00", "created_at": "2026-11-04T20:40:53+00:00"}}
     * @response 404 {"error": {"code": "NOT_FOUND", "message": "Notification not found.", "details": {}}}
     */
    public function markAsRead(Request $request, string $id): NotificationResource
    {
        $notification = $request->user()->notifications()->findOrFail($id);
        $notification->markAsRead();

        return new NotificationResource($notification);
    }

    /**
     * Mark all as read
     *
     * @group Notifications
     *
     * @authenticated
     *
     * @response 200 {"data": {"marked_as_read": 2}}
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        $updated = $request->user()->unreadNotifications()->update(['read_at' => now()]);

        return response()->json(['data' => ['marked_as_read' => $updated]]);
    }
}
