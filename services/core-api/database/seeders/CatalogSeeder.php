<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Product;
use App\Services\Inventory\InventoryClient;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/**
 * Sample catalogue so the app has something to show right after setup.
 * Safe to run many times: existing rows and their stock are left untouched.
 */
class CatalogSeeder extends Seeder
{
    private const CATALOG = [
        'Electronics' => [
            ['Wireless Headphones', 'Over-ear Bluetooth headphones with noise cancelling.', '79.99', 25],
            ['USB-C Charger 65W', 'Fast charger for laptops and phones.', '29.50', 40],
            ['Smart Watch', 'Fitness tracking, heart rate and notifications.', '149.00', 1],
        ],
        'Books' => [
            ['Clean Code', 'A handbook of agile software craftsmanship.', '35.00', 12],
            ['Designing Data-Intensive Applications', 'The big ideas behind reliable, scalable systems.', '49.90', 0],
        ],
        'Clothing' => [
            ['Cotton T-Shirt', '100% cotton, regular fit.', '12.00', 100],
            ['Winter Jacket', 'Water-resistant jacket with hood.', '89.00', 8],
        ],
    ];

    public function run(InventoryClient $inventory): void
    {
        foreach (self::CATALOG as $categoryName => $products) {
            $category = Category::firstOrCreate(
                ['slug' => Str::slug($categoryName)],
                ['name' => $categoryName],
            );

            foreach ($products as [$name, $description, $price, $quantity]) {
                $product = Product::firstOrCreate(
                    ['name' => $name],
                    ['category_id' => $category->id, 'description' => $description, 'price' => $price],
                );

                if ($product->wasRecentlyCreated) {
                    $inventory->setStock($product->id, $quantity);
                }
            }
        }
    }
}
