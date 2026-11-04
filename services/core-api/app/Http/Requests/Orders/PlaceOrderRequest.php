<?php

namespace App\Http\Requests\Orders;

use Illuminate\Foundation\Http\FormRequest;

class PlaceOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Only product ids and quantities are accepted: prices always come from the database.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'min:1', 'max:20'],
            'items.*.product_id' => ['required', 'integer', 'distinct', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:100'],
        ];
    }

    /** @return array<int, int> product id => quantity */
    public function items(): array
    {
        return collect($this->validated('items'))
            ->mapWithKeys(fn (array $item) => [(int) $item['product_id'] => (int) $item['quantity']])
            ->all();
    }
}
