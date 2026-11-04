<?php

namespace App\Http\Requests\Orders;

use App\Enums\OrderStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateOrderStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // the "admin" middleware and OrderPolicy guard this route
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'status' => ['required', Rule::enum(OrderStatus::class)->except([OrderStatus::Pending])],
        ];
    }

    public function status(): OrderStatus
    {
        return OrderStatus::from($this->validated('status'));
    }
}
