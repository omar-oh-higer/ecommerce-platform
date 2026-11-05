import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shop_core/shop_core.dart';

import '../../core/widgets.dart';
import 'orders_cubit.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    return BlocBuilder<OrdersCubit, OrdersState>(builder: (context, s) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Orders', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            IconButton(tooltip: 'Refresh', onPressed: cubit.refresh, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          // Real totals per status from the API.
          Wrap(spacing: 12, runSpacing: 12, children: [
            _CountCard('All', s.countsByStatus.values.fold<int>(0, (a, b) => a + b), null, s.status == null,
                () => cubit.load()),
            for (final st in OrderStatus.values)
              _CountCard(st.label, s.countsByStatus[st], statusColor(st), s.status == st, () => cubit.load(status: st)),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _table(context, s, cubit)),
        ]),
      );
    });
  }

  Widget _table(BuildContext context, OrdersState s, OrdersCubit cubit) {
    if (s.loading && s.orders.isEmpty) return const Center(child: CircularProgressIndicator());
    if (s.failure != null && s.orders.isEmpty) return ErrorView(s.failure!, onRetry: cubit.refresh);
    if (s.orders.isEmpty) return const Center(child: Text('No orders.'));
    return Column(children: [
      if (s.failure != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: FailureBox(s.failure!)),
      Expanded(
        child: Card(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('Order')),
                  DataColumn(label: Text('Customer')),
                  DataColumn(label: Text('Items'), numeric: true),
                  DataColumn(label: Text('Total'), numeric: true),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Placed')),
                ],
                rows: [
                  for (final o in s.orders)
                    DataRow(
                      onSelectChanged: (_) => context.go('/orders/${o.id}'),
                      cells: [
                        DataCell(Text('#${o.id}')),
                        DataCell(Text(o.customer?.name ?? '')),
                        DataCell(Text('${o.itemsCount}')),
                        DataCell(Text(o.total.toString())),
                        DataCell(StatusChip(o.status)),
                        DataCell(Text(formatDate(o.createdAt))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('Page ${s.page} of ${s.lastPage} · ${s.total} orders'),
        IconButton(
          onPressed: s.page > 1 && !s.loading ? () => cubit.load(status: s.status, page: s.page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: s.page < s.lastPage && !s.loading ? () => cubit.load(status: s.status, page: s.page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
    ]);
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard(this.label, this.count, this.color, this.selected, this.onTap);
  final String label;
  final int? count;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: color)),
                const SizedBox(height: 4),
                Text(count?.toString() ?? '–', style: Theme.of(context).textTheme.headlineSmall),
              ]),
            ),
          ),
        ),
      );
}
