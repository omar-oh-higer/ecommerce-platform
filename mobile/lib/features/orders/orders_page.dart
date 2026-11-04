import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../catalog/product_widgets.dart';
import 'order_widgets.dart';
import 'orders_cubit.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) context.read<OrdersCubit>().loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: Column(children: [
        BlocBuilder<OrdersCubit, OrdersState>(
          buildWhen: (a, b) => a.status != b.status,
          builder: (context, s) => SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('All', s.status == null, () => cubit.filter(null)),
                for (final st in OrderStatus.values)
                  _chip(st.label, s.status == st, () => cubit.filter(st)),
              ],
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<OrdersCubit, OrdersState>(builder: (context, s) {
            if (s.loading && s.orders.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.failure != null && s.orders.isEmpty) {
              return ErrorView(s.failure!, onRetry: cubit.load);
            }
            if (s.orders.isEmpty) {
              return const Center(child: Text('No orders yet.'));
            }
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView.separated(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: s.orders.length + (s.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == s.orders.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: s.failure != null
                            ? TextButton(onPressed: cubit.loadMore, child: const Text('Retry'))
                            : const CircularProgressIndicator(),
                      ),
                    );
                  }
                  final o = s.orders[i];
                  return ListTile(
                    onTap: () => context.push('/orders/${o.id}'),
                    title: Text('Order #${o.id}'),
                    subtitle: Text('${o.itemsCount} item(s) · ${formatDate(o.createdAt)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [Text(o.total.toString()), StatusChip(o.status)],
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}
