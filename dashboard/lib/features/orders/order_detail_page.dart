import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';
import 'orders_cubit.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  AppFailure? _failure; // load failure
  AppFailure? _actionFailure;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failure = null);
    try {
      final o = await context.read<OrdersRepository>().get(widget.orderId);
      if (mounted) setState(() => _order = o);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  static String _actionLabel(OrderStatus s) => switch (s) {
        OrderStatus.confirmed => 'Confirm order',
        OrderStatus.shipped => 'Mark as shipped',
        OrderStatus.delivered => 'Mark as delivered',
        OrderStatus.cancelled => 'Cancel order',
        OrderStatus.pending => 'Set pending',
      };

  Future<void> _change(OrderStatus target) async {
    final repo = context.read<OrdersRepository>();
    final list = context.read<OrdersCubit>();
    if (target == OrderStatus.cancelled) {
      // Close the dialog with ITS OWN context. This page lives inside the shell's nested
      // navigator while dialogs open on the root navigator: popping with the page's context
      // closed the order page instead of the dialog, so the request was never sent.
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text('The reserved items will be returned to stock. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep order')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel order')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _actionFailure = null;
    });
    try {
      final updated = await repo.updateStatus(widget.orderId, target);
      if (!mounted) return;
      setState(() => _order = updated);
      showSnack(
        context,
        updated.stockReturnPending
            ? 'Order #${updated.id} is cancelled. The stock service is unavailable right now: '
                'the items will be returned to stock automatically as soon as it is back.'
            : 'Order #${updated.id} is now ${updated.status.label.toLowerCase()}',
      );
      list.refresh();
    } on InvalidTransitionFailure catch (f) {
      // Someone else changed it first: show the truth.
      if (mounted) setState(() => _actionFailure = f);
      await _load();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _actionFailure = f);
    } catch (_) {
      // Never fail silently: any unexpected error still shows a message.
      if (mounted) {
        setState(() => _actionFailure =
            const ServerFailure('Something went wrong. Please refresh and try again.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: switch ((o, _failure)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, final f?) => Column(children: [
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(
                onPressed: () => context.go('/orders'), icon: const Icon(Icons.arrow_back), label: const Text('Orders'))),
            Expanded(child: ErrorView(f, onRetry: _load)),
          ]),
        (final o?, _) => _content(context, o),
      },
    );
  }

  Widget _content(BuildContext context, Order o) => ListView(children: [
        Row(children: [
          IconButton(onPressed: () => context.go('/orders'), icon: const Icon(Icons.arrow_back)),
          Text('Order #${o.id}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 12),
          StatusChip(o.status),
          const Spacer(),
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 16),
        if (_actionFailure != null) ...[FailureBox(_actionFailure!), const SizedBox(height: 16)],
        Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.start, children: [
          SizedBox(
            width: 560,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Items', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final i in o.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(i.name),
                      subtitle: Text('${i.quantity} × ${i.unitPrice}'),
                      trailing: Text(i.lineTotal.toString()),
                    ),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total'),
                    Text(o.total.toString(), style: Theme.of(context).textTheme.titleLarge),
                  ]),
                ]),
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: Column(children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Customer', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(o.customer?.name ?? '–'),
                    Text(o.customer?.email ?? ''),
                    const SizedBox(height: 12),
                    Text('Placed: ${formatDate(o.createdAt)}'),
                    Text('Updated: ${formatDate(o.updatedAt)}'),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Change status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    // Only the moves the server allows right now.
                    if (o.stockReturnPending) ...[
                      Text(
                        'Stock return pending: the stock service was unavailable when this order was '
                        'cancelled. The items return to stock automatically as soon as it is back.',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (o.nextStatuses.isEmpty)
                      Text('This order is ${o.status.label.toLowerCase()} and cannot change any more.')
                    else
                      for (final next in o.nextStatuses)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: next == OrderStatus.cancelled
                              ? OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                                  onPressed: _busy ? null : () => _change(next),
                                  child: Text(_actionLabel(next)))
                              : FilledButton(
                                  onPressed: _busy ? null : () => _change(next), child: Text(_actionLabel(next))),
                        ),
                    if (_busy) const LinearProgressIndicator(),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ]);
}
