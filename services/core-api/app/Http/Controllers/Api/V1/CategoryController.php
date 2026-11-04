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
    /** GET /api/v1/categories */
    public function index(): AnonymousResourceCollection
    {
        return CategoryResource::collection(
            Category::query()->withCount('products')->orderBy('name')->get()
        );
    }

    /** POST /api/v1/categories (admin) */
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
