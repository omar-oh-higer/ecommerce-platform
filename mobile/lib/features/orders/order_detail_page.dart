import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shop_core/shop_core.dart';

import '../catalog/product_widgets.dart';
import 'order_widgets.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({super.key, required this.orderId});
  final int orderId;
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Order? _order;
  AppFailure? _failure;

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

  @override
  Widget build(BuildContext context) {
    final o = _order;
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: switch ((o, _failure)) {
        (null, null) => const Center(child: CircularProgressIndicator()),
        (null, final f?) => ErrorView(f, onRetry: _load),
        (final o?, _) => RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  StatusChip(o.status),
                  Text(formatDate(o.createdAt)),
                ]),
                const SizedBox(height: 16),
                StatusTimeline(o.status),
                const Divider(height: 32),
                for (final i in o.items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i.name),
                    subtitle: Text('${i.quantity} × ${i.unitPrice}'),
                    trailing: Text(i.lineTotal.toString()),
                  ),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: Theme.of(context).textTheme.titleMedium),
                  Text(o.total.toString(), style: Theme.of(context).textTheme.titleLarge),
                ]),
              ],
            ),
          ),
      },
    );
  }
}
