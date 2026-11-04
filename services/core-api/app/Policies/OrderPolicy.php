<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * Who may do what with an order.
 *  - A customer sees only their own orders.
 *  - Only an administrator changes an order's status.
 */
class OrderPolicy
{
    public function view(User $user, Order $order): Response
    {
        return $user->isAdmin() || $order->user_id === $user->id
            ? Response::allow()
            : Response::deny('You are not allowed to view this order.');
    }

    public function updateStatus(User $user, Order $order): Response
    {
        return $user->isAdmin()
            ? Response::allow()
            : Response::deny('Only administrators can change the status of an order.');
    }
}
