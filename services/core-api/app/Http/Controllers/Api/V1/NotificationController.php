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
    /** GET /api/v1/notifications?unread=1 */
    public function index(ListNotificationsRequest $request): AnonymousResourceCollection
    {
        $notifications = $request->user()->notifications()
            ->when($request->boolean('unread'), fn ($q) => $q->whereNull('read_at'))
            ->paginate($request->integer('per_page', 15))
            ->withQueryString();

        return NotificationResource::collection($notifications)
            ->additional(['meta' => ['unread_count' => $request->user()->unreadNotifications()->count()]]);
    }

    /** GET /api/v1/notifications/unread-count — cheap call for the badge on the bell icon. */
    public function unreadCount(Request $request): JsonResponse
    {
        return response()->json([
            'data' => ['unread_count' => $request->user()->unreadNotifications()->count()],
        ]);
    }

    /** PATCH /api/v1/notifications/{id}/read */
    public function markAsRead(Request $request, string $id): NotificationResource
    {
        $notification = $request->user()->notifications()->findOrFail($id);
        $notification->markAsRead();

        return new NotificationResource($notification);
    }

    /** PATCH /api/v1/notifications/read-all */
    public function markAllAsRead(Request $request): JsonResponse
    {
        $updated = $request->user()->unreadNotifications()->update(['read_at' => now()]);

        return response()->json(['data' => ['marked_as_read' => $updated]]);
    }
}
