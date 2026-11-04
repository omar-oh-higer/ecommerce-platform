import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog/product_widgets.dart';
import 'cart_cubit.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>();
    final s = cart.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (!s.isEmpty)
            TextButton(onPressed: cart.clear, child: const Text('Clear')),
        ],
      ),
      body: s.isEmpty
          ? const Center(child: Text('Your cart is empty.'))
          : Column(children: [
              Expanded(
                child: ListView.separated(
                  itemCount: s.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = s.items[i];
                    return ListTile(
                      leading: SizedBox(
                          width: 56, height: 56, child: ProductImage(item.imageUrl)),
                      title: Text(item.name),
                      subtitle: Text('${item.unitPrice} each · ${item.lineTotal}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => cart.setQuantity(item.productId, item.quantity - 1),
                        ),
                        Text('${item.quantity}'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: item.quantity < item.maxQuantity
                              ? () => cart.setQuantity(item.productId, item.quantity + 1)
                              : null,
                        ),
                      ]),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total', style: Theme.of(context).textTheme.titleMedium),
                      Text(s.total.toString(), style: Theme.of(context).textTheme.titleLarge),
                    ]),
                    const SizedBox(height: 12),
                    // Checkout arrives with the orders step.
                    const FilledButton(onPressed: null, child: Text('Checkout (coming next)')),
                  ]),
                ),
              ),
            ]),
    );
  }
}
