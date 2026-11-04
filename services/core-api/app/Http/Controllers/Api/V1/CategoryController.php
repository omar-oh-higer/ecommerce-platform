<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Categories\StoreCategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    /**
     * List categories
     *
     * Use `id` as `category_id` to filter products.
     *
     * @group Catalogue
     *
     * @unauthenticated
     *
     * @response 200 {"data": [{"id": 2, "name": "Books", "slug": "books", "products_count": 2}, {"id": 3, "name": "Clothing", "slug": "clothing", "products_count": 2}, {"id": 1, "name": "Electronics", "slug": "electronics", "products_count": 3}]}
     */
    public function index(): AnonymousResourceCollection
    {
        return CategoryResource::collection(
            Category::query()->withCount('products')->orderBy('name')->get()
        );
    }

    /**
     * Create a category
     *
     * **Admin only.** The slug is generated from the name.
     *
     * @group Administration
     *
     * @authenticated
     *
     * @bodyParam name string required Unique, up to 100 characters. Example: Toys & Games
     *
     * @response 201 {"data": {"id": 4, "name": "Toys & Games", "slug": "toys-games"}}
     * @response 403 scenario="Customer token" {"error": {"code": "FORBIDDEN", "message": "This action is reserved for administrators.", "details": {}}}
     * @response 422 scenario="Name taken" {"error": {"code": "VALIDATION_FAILED", "message": "The given data was invalid.", "details": {"name": ["The name has already been taken."]}}}
     */
    public function store(StoreCategoryRequest $request): JsonResponse
    {
        $name = $request->validated('name');

        $category = Category::create([
            'name' => $name,
            'slug' => $this->uniqueSlug($name),
        ]);

        return (new CategoryResource($category))->response()->setStatusCode(201);
    }

    private function uniqueSlug(string $name): string
    {
        $base = Str::slug($name) ?: 'category';
        $slug = $base;

        for ($i = 2; Category::where('slug', $slug)->exists(); $i++) {
            $slug = "{$base}-{$i}";
        }

        return $slug;
    }
}
