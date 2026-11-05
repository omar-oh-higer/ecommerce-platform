import '../../core/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../cart/cart_cubit.dart';
import 'product_widgets.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  AppFailure? _failure;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final p = await context.read<CatalogRepository>().product(
        widget.productId,
      );
      if (mounted) setState(() => _product = p);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(p?.name ?? 'Product'),
      ),
      body: switch ((p, _failure)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, final f?) => ErrorView(f, onRetry: _load),
        (final p?, _) => _content(context, p),
      },
    );
  }

  Widget _content(BuildContext context, Product p) {
    final max = ((p.stock.quantity ?? kMaxLineQuantity)).clamp(
      1,
      kMaxLineQuantity,
    );
    final q = _quantity.clamp(1, max);
    return ListView(
      children: [
        AspectRatio(aspectRatio: 1.4, child: ProductImage(p.imageUrl)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.category != null)
                Text(
                  p.category!.name,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                p.price.toString(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              StockBadge(p.stock),
              if (p.stock.status == StockStatus.unavailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'We cannot check stock right now. Please try again later.',
                  ),
                ),
              const SizedBox(height: 16),
              Text(p.description),
              const SizedBox(height: 24),
              if (p.canBuy) ...[
                Row(
                  children: [
                    IconButton.outlined(
                      onPressed: q > 1
                          ? () => setState(() => _quantity = q - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$q',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton.outlined(
                      onPressed: q < max
                          ? () => setState(() => _quantity = q + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: p.canBuy ? () => _add(context, p, q) : null,
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(p.canBuy ? 'Add to cart' : 'Not available'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _add(BuildContext context, Product p, int q) {
    final ok = context.read<CartCubit>().add(p, quantity: q);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Added to cart' : 'Your cart is full ($kMaxCartLines items max)',
        ),
        action: ok
            ? SnackBarAction(
                label: 'View cart',
                onPressed: () => context.push('/cart'),
              )
            : null,
      ),
    );
  }
}
