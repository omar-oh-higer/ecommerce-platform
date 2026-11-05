import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../cart/cart_cubit.dart';
import 'checkout_cubit.dart';

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartCubit>().state;
    return BlocConsumer<CheckoutCubit, CheckoutState>(
      listener: (context, state) {
        if (state is CheckoutSuccess) {
          // The notification is created in the background: look again shortly.
          final unread = context.read<UnreadCountCubit>();
          Future<void>.delayed(const Duration(seconds: 3), unread.refresh);
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Order placed')));
          context.go('/orders/${state.order.id}');
        }
      },
      builder: (context, state) {
        final submitting = state is CheckoutSubmitting;
        return Scaffold(
          appBar: AppBar(title: const Text('Checkout')),
          body: cart.isEmpty && state is! CheckoutSuccess
              ? const Center(child: Text('Your cart is empty.'))
              : Column(children: [
                  Expanded(
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      if (state is CheckoutFailed) ...[
                        _FailurePanel(state.failure, submitting: submitting),
                        const SizedBox(height: 16),
                      ],
                      Text('Order summary', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final i in cart.items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(i.name),
                          subtitle: Text('${i.quantity} × ${i.unitPrice}'),
                          trailing: Text(i.lineTotal.toString()),
                        ),
                      const Divider(),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Total', style: Theme.of(context).textTheme.titleMedium),
                        Text(cart.total.toString(),
                            style: Theme.of(context).textTheme.titleLarge),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        'Final prices are confirmed by the store when the order is placed.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ]),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submitting || cart.isEmpty
                              ? null
                              : () => context.read<CheckoutCubit>().submit(),
                          child: submitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(state is CheckoutFailed ? 'Try again' : 'Place order'),
                        ),
                      ),
                    ),
                  ),
                ]),
        );
      },
    );
  }
}

/// Explains why the order was refused. In every case nothing was created and
/// the cart is unchanged.
class _FailurePanel extends StatelessWidget {
  const _FailurePanel(this.failure, {required this.submitting});
  final AppFailure failure;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = failure;
    final children = <Widget>[];

    if (f is InsufficientStockFailure) {
      children
        ..add(const Text('Not enough stock', style: TextStyle(fontWeight: FontWeight.bold)))
        ..add(const SizedBox(height: 4))
        ..add(const Text('Your order was not placed and nothing was reserved.'));
      for (final p in f.items) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(p.available == 0
              ? '• ${p.name}: sold out (you asked for ${p.requested})'
              : '• ${p.name}: only ${p.available} available (you asked for ${p.requested})'),
        ));
      }
      children
        ..add(const SizedBox(height: 12))
        ..add(FilledButton.tonal(
          onPressed: () {
            context.read<CheckoutCubit>().adjustCartToStock();
            context.pop();
          },
          child: const Text('Update my cart'),
        ));
    } else {
      final retryAfter = f is RateLimitedFailure && f.retryAfter != null
          ? ' Try again in ${f.retryAfter!.inSeconds} s.'
          : '';
      children
        ..add(Text(f is ServiceUnavailableFailure ? 'Cannot place the order right now' : 'Order not placed',
            style: const TextStyle(fontWeight: FontWeight.bold)))
        ..add(const SizedBox(height: 4))
        ..add(Text('${f.message}$retryAfter Your cart was kept.'));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onErrorContainer),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}
