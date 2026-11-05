import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

/// Product image with a placeholder (seeded products have no image).
class ProductImage extends StatelessWidget {
  const ProductImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final resolved = context.read<ApiConfig>().resolveImageUrl(url);
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 40)),
    );
    if (resolved == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class StockBadge extends StatelessWidget {
  const StockBadge(this.stock, {super.key});
  final Stock stock;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (stock.status) {
      StockStatus.inStock => (
        stock.quantity != null && stock.quantity! <= 5
            ? 'Only ${stock.quantity} left'
            : 'In stock',
        Colors.green.shade700,
      ),
      StockStatus.outOfStock => ('Out of stock', Colors.red.shade700),
      StockStatus.unavailable => ('Stock unavailable', Colors.orange.shade800),
    };
    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
    );
  }
}

/// Error with a retry button, used by every list/screen that loads data.
class ErrorView extends StatelessWidget {
  const ErrorView(this.failure, {super.key, required this.onRetry});
  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failure is NetworkFailure || failure is ServiceUnavailableFailure
                ? Icons.cloud_off
                : Icons.error_outline,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(failure.message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
