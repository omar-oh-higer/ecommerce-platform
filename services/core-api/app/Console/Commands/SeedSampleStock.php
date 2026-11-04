<?php

namespace App\Console\Commands;

use App\Models\Product;
use App\Services\Inventory\InventoryClient;
use Database\Seeders\CatalogSeeder;
use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;

/**
 * Sets the sample products back to their initial quantities in the inventory service.
 * Handy before a demo, e.g. to put "Smart Watch" back to its last unit for the race-condition proof.
 */
#[Signature('inventory:seed-sample')]
#[Description('Reset the stock of the sample products in the inventory service')]
class SeedSampleStock extends Command
{
    public function handle(InventoryClient $inventory): int
    {
        $rows = [];

        foreach (CatalogSeeder::CATALOG as $products) {
            foreach ($products as [$name, , , $quantity]) {
                $product = Product::where('name', $name)->first();

                if (! $product) {
                    $rows[] = [$name, '-', 'not in the catalogue (run db:seed)'];

                    continue;
                }

                $inventory->setStock($product->id, $quantity);
                $rows[] = [$name, $product->id, $quantity];
            }
        }

        $this->table(['Product', 'ID', 'Stock'], $rows);

        return self::SUCCESS;
    }
}
